begin;

-- Storage performs permission probes in rolled-back savepoints. Guard the actual
-- metadata write too, including the Storage service's privileged final insert.
create function public.guard_lift_evidence_storage_write()
returns trigger language plpgsql security definer set search_path=pg_catalog as $$
declare lift_uuid uuid; owner_uuid uuid;
begin
  if new.bucket_id <> 'lift-videos' and new.bucket_id not like 'lift-evidence%' then return new; end if;
  -- Legacy administrative paths are outside the native uid/lift/asset contract.
  if new.name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[^/]+$' then return new; end if;
  owner_uuid:=split_part(new.name,'/',1)::uuid;
  lift_uuid:=split_part(new.name,'/',2)::uuid;
  perform 1 from public.lift_submissions l where l.id=lift_uuid and l.user_id=owner_uuid for update;
  if not found or exists(select 1 from public.lift_removal_requests r where r.lift_id=lift_uuid) then
    raise exception using errcode='55000',message='Lift evidence is unavailable or removal has started';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_lift_evidence_storage_write() from public,anon,authenticated;
create trigger guard_lift_evidence_storage_write before insert or update of bucket_id,name on storage.objects
for each row execute function public.guard_lift_evidence_storage_write();

-- Existing permissive policies still decide bucket/owner access. The restrictive
-- policy closes alternate/malformed client paths that cannot identify a lift.
create policy "lift evidence requires canonical path" on storage.objects as restrictive
for insert to authenticated with check (
  (bucket_id <> 'lift-videos' and bucket_id not like 'lift-evidence%') or
  (name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[^/]+$'
    and split_part(name,'/',3) not in ('.','..'))
);

create function public.prevent_removed_lift_recreation()
returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
  perform 1 from public.lift_submissions l where l.id=new.id for update;
  if exists(select 1 from public.lift_removal_requests r where r.lift_id=new.id) then
    raise exception using errcode='55000',message='A removed lift identifier cannot be reused';
  end if;
  return new;
end;
$$;
revoke all on function public.prevent_removed_lift_recreation() from public,anon,authenticated;
create trigger prevent_removed_lift_recreation before insert on public.lift_submissions
for each row execute function public.prevent_removed_lift_recreation();

create function public.reserve_lift_removal(target_lift_id uuid,target_owner_id uuid)
returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare
  lift public.lift_submissions%rowtype;
  removal public.lift_removal_requests%rowtype;
  prefix text:=target_owner_id::text||'/'||target_lift_id::text||'/';
  legacy_paths text[];
  objects jsonb;
  protected boolean;
begin
  if target_lift_id is null or target_owner_id is null then raise exception 'Lift and owner required' using errcode='22023'; end if;
  select l.* into lift from public.lift_submissions l where l.id=target_lift_id and l.user_id=target_owner_id for update;
  if not found then
    select r.* into removal from public.lift_removal_requests r where r.lift_id=target_lift_id and r.owner_id=target_owner_id for update;
    if found and removal.status='completed' then
      return jsonb_build_object('id',removal.id,'status',removal.status,'protected_record',removal.protected_record,'storage_objects','[]'::jsonb);
    end if;
    raise exception 'Owned lift not found' using errcode='P0002';
  end if;
  select r.* into removal from public.lift_removal_requests r where r.lift_id=target_lift_id for update;
  if found and (removal.owner_id<>target_owner_id or removal.status='completed') then
    raise exception 'Removal request requires administrative repair' using errcode='22023';
  end if;
  legacy_paths:=array_remove(array[lift.approved_evidence_storage_path,lift.pending_evidence_storage_path,lift.evidence_storage_path],null);
  if exists(select 1 from unnest(legacy_paths) p where p<>'' and (left(p,length(prefix))<>prefix or p ~ '(^|/)\.\.?(/|$)'))
    or exists(select 1 from public.lift_media_assets a where a.lift_id=target_lift_id and (a.owner_id<>target_owner_id or left(a.storage_path,length(prefix))<>prefix or a.storage_path ~ '(^|/)\.\.?(/|$)')) then
    raise exception 'Evidence path requires administrative repair' using errcode='22023';
  end if;
  -- Reservation holds the same lift lock as actual Storage writes/finalization.
  -- Include uploaded but unattached objects, not just the current video pointer.
  select coalesce(jsonb_agg(jsonb_build_object('bucket_id',o.bucket_id,'name',o.name) order by o.bucket_id,o.name),'[]'::jsonb) into objects
  from storage.objects o
  where (o.bucket_id='lift-videos' or o.bucket_id like 'lift-evidence%')
    and (left(o.name,length(prefix))=prefix
      or (o.bucket_id like 'lift-evidence%' and o.name=any(legacy_paths)));
  protected:=lift.evidence_status<>'self_reported' or lift.video_asset_id is not null
    or exists(select 1 from unnest(legacy_paths) p where p<>'') or lift.review_status='approved' or lift.evidence_public or jsonb_array_length(objects)>0;
  insert into public.lift_removal_requests(lift_id,owner_id,status,protected_record,lift_snapshot,storage_objects,last_error)
  values(target_lift_id,target_owner_id,'processing',protected,to_jsonb(lift),objects,null)
  on conflict(lift_id) do update set status='processing',protected_record=excluded.protected_record,lift_snapshot=excluded.lift_snapshot,storage_objects=excluded.storage_objects,last_error=null,updated_at=statement_timestamp()
  returning * into removal;
  return jsonb_build_object('id',removal.id,'status',removal.status,'protected_record',removal.protected_record,'storage_objects',removal.storage_objects);
end;
$$;
revoke all on function public.reserve_lift_removal(uuid,uuid) from public,anon,authenticated;
grant execute on function public.reserve_lift_removal(uuid,uuid) to service_role;

create or replace function public.complete_lift_media_upload(
  target_asset_id uuid, target_lift_id uuid, uploaded_storage_path text,
  uploaded_content_type text, uploaded_byte_count bigint
)
returns table(id uuid, owner_id uuid, storage_path text, content_type text, byte_count bigint, created_at timestamptz)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare caller uuid := auth.uid(); prior public.lift_moderation_status;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  select l.moderation_status into prior
  from public.lift_submissions l
  where l.id = target_lift_id and l.user_id = caller
  for update;
  if prior is null then raise exception 'Lift not found'; end if;
  if exists(select 1 from public.lift_removal_requests r where r.lift_id=target_lift_id) then
    raise exception using errcode='55000',message='Lift removal has started';
  end if;
  if uploaded_storage_path !~ ('^' || caller::text || '/' || target_lift_id::text || '/')
     or not exists (
       select 1 from storage.objects o
       where o.bucket_id = 'lift-videos'
         and o.name = uploaded_storage_path
         and o.owner_id = caller::text
     )
  then raise exception 'Completed upload not found'; end if;

  insert into public.lift_media_assets(id, owner_id, lift_id, storage_path, content_type, byte_count)
  values(target_asset_id, caller, target_lift_id, uploaded_storage_path, uploaded_content_type, uploaded_byte_count);
  perform pg_catalog.set_config('liftrank.trusted_media_finalize', 'true', true);
  update public.lift_submissions l set
    video_asset_id = target_asset_id,
    evidence_status = 'video_backed',
    verification = 'Video Verified',
    moderation_status = case when prior = 'replacement_requested' then 'under_review' else prior end,
    updated_at = statement_timestamp()
  where l.id = target_lift_id;
  perform pg_catalog.set_config('liftrank.trusted_media_finalize', 'false', true);
  return query
    select a.id, a.owner_id, a.storage_path, a.content_type, a.byte_count, a.created_at
    from public.lift_media_assets a
    where a.id = target_asset_id;
end;
$$;

create or replace function public.finalize_lift_removal(target_request_id uuid)
returns boolean language plpgsql security definer set search_path=pg_catalog as $$
declare removal public.lift_removal_requests%rowtype; lift_uuid uuid; owner_uuid uuid;
begin
  select r.lift_id,r.owner_id into lift_uuid,owner_uuid from public.lift_removal_requests r where r.id=target_request_id;
  if not found then raise exception 'Removal request not found' using errcode='P0002'; end if;
  -- Every live-lift path locks lift then request, including retries.
  perform 1 from public.lift_submissions l where l.id=lift_uuid and l.user_id=owner_uuid for update;
  select r.* into removal from public.lift_removal_requests r where r.id=target_request_id for update;
  if removal.status='completed' then return true; end if;
  if removal.lift_id is distinct from lift_uuid or removal.owner_id is distinct from owner_uuid then
    raise exception 'Removal request changed' using errcode='40001';
  end if;
  if exists(select 1 from storage.objects o where
      (o.bucket_id='lift-videos' or o.bucket_id like 'lift-evidence%') and left(o.name,length(owner_uuid::text||'/'||lift_uuid::text||'/'))=owner_uuid::text||'/'||lift_uuid::text||'/')
    or exists(select 1 from jsonb_array_elements(removal.storage_objects) obj join storage.objects o on o.bucket_id=obj->>'bucket_id' and o.name=obj->>'name') then
    raise exception 'Evidence cleanup is incomplete' using errcode='55000';
  end if;
  perform pg_catalog.set_config('liftrank.trusted_lift_removal','true',true);
  delete from public.lift_moderation_audit where lift_id=lift_uuid;
  delete from public.lift_submissions where id=lift_uuid and user_id=owner_uuid;
  update public.lift_removal_requests set status='completed',completed_at=statement_timestamp(),updated_at=statement_timestamp(),last_error=null where id=target_request_id;
  perform pg_catalog.set_config('liftrank.trusted_lift_removal','false',true);
  return true;
end;
$$;
revoke all on function public.finalize_lift_removal(uuid) from public,anon,authenticated;
grant execute on function public.finalize_lift_removal(uuid) to service_role;
commit;
