begin;

create function public.complete_lift_media_upload_if_current(
  target_asset_id uuid,
  target_lift_id uuid,
  expected_asset_id uuid,
  uploaded_storage_path text,
  uploaded_content_type text,
  uploaded_byte_count bigint
)
returns table(id uuid, owner_id uuid, storage_path text, content_type text, byte_count bigint, created_at timestamptz)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  current_asset uuid;
  asset public.lift_media_assets%rowtype;
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  select l.video_asset_id into current_asset
  from public.lift_submissions l
  where l.id = target_lift_id and l.user_id = caller
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Owned lift not found';
  end if;

  if current_asset = target_asset_id then
    select a.* into asset from public.lift_media_assets a
    where a.id = target_asset_id and a.owner_id = caller and a.lift_id = target_lift_id;
    if not found or asset.storage_path is distinct from uploaded_storage_path
      or asset.content_type is distinct from uploaded_content_type
      or asset.byte_count is distinct from uploaded_byte_count then
      raise exception using errcode = '22023', message = 'Attached upload does not match this attempt';
    end if;
    return query select asset.id, asset.owner_id, asset.storage_path, asset.content_type, asset.byte_count, asset.created_at;
    return;
  end if;

  if current_asset is distinct from expected_asset_id then
    raise exception using errcode = '40001', message = 'Lift video changed. Reload before replacing evidence';
  end if;
  return query select * from public.complete_lift_media_upload(
    target_asset_id, target_lift_id, uploaded_storage_path, uploaded_content_type, uploaded_byte_count
  );
end;
$$;

revoke all on function public.complete_lift_media_upload_if_current(uuid,uuid,uuid,text,text,bigint) from public, anon;
grant execute on function public.complete_lift_media_upload_if_current(uuid,uuid,uuid,text,text,bigint) to authenticated;

commit;
