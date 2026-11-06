-- Forum attachments reuse forum_posts.attachments. Apply only after environment review.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('forum-media', 'forum-media', false, 52428800, array['image/jpeg', 'video/mp4'])
on conflict (id) do update
set public = false, file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

grant select on storage.objects to anon;

create policy "forum media visible with post" on storage.objects
for select to authenticated, anon
using (
  bucket_id = 'forum-media'
  and exists (
    select 1 from public.forum_posts p
    where p.removed_at is null
      and p.attachments @> jsonb_build_array(jsonb_build_object('storage_path', name))
  )
);

create policy "forum media owner upload" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'forum-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|mp4)$'
);

-- An owner may retry or clean up an upload, but cannot replace a published file.
create or replace function public.forum_media_is_attached(target_path text)
returns boolean language sql stable security definer set search_path = pg_catalog
as $$
  select exists (
    select 1 from public.forum_posts p
    where p.attachments @> jsonb_build_array(jsonb_build_object('storage_path', target_path))
  );
$$;
revoke all on function public.forum_media_is_attached(text) from public, anon;
grant execute on function public.forum_media_is_attached(text) to authenticated;

create policy "forum media owner pending read" on storage.objects
for select to authenticated
using (
  bucket_id = 'forum-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and not public.forum_media_is_attached(name)
);

create policy "forum media owner retry" on storage.objects
for update to authenticated
using (
  bucket_id = 'forum-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and not public.forum_media_is_attached(name)
)
with check (
  bucket_id = 'forum-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|mp4)$'
  and not public.forum_media_is_attached(name)
);

create policy "forum media owner cleanup" on storage.objects
for delete to authenticated
using (
  bucket_id = 'forum-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and not public.forum_media_is_attached(name)
);

-- Validate the link against the uploaded object, never an arbitrary external URL.
create or replace function public.validate_forum_attachments()
returns trigger language plpgsql security definer set search_path = pg_catalog
as $$
declare
  attachment jsonb;
  expected_type text;
  object_size bigint;
begin
  if tg_op = 'UPDATE' and (
    new.attachments is distinct from old.attachments
    or new.author_id is distinct from old.author_id
    or new.id is distinct from old.id
  ) then
    raise exception using errcode = '42501', message = 'Published attachments cannot be replaced';
  end if;
  if jsonb_typeof(new.attachments) <> 'array' or jsonb_array_length(new.attachments) > 1 then
    raise exception 'Attach one photo or video per discussion';
  end if;
  for attachment in select value from jsonb_array_elements(new.attachments)
  loop
    if jsonb_typeof(attachment) <> 'object'
       or (attachment - 'kind' - 'storage_path') <> '{}'::jsonb
       or coalesce(attachment->>'kind', '') not in ('photo', 'video')
       or coalesce(attachment->>'storage_path', '') not like new.author_id::text || '/' || new.id::text || '/%' then
      raise exception 'Invalid discussion attachment';
    end if;
    expected_type := case attachment->>'kind' when 'photo' then 'image/jpeg' else 'video/mp4' end;
    select (o.metadata->>'size')::bigint into object_size
    from storage.objects o
    where o.bucket_id = 'forum-media'
      and o.name = attachment->>'storage_path'
      and o.metadata->>'mimetype' = expected_type;
    if object_size is null or object_size <= 0
       or object_size > (case attachment->>'kind' when 'photo' then 10485760 else 52428800 end) then
      raise exception 'Attachment upload is missing, invalid, or too large';
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function public.validate_forum_attachments() from public, anon, authenticated;
create trigger forum_attachments_guard
before insert or update of attachments, author_id, id on public.forum_posts
for each row execute function public.validate_forum_attachments();
