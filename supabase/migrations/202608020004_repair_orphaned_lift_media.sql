begin;

-- Repair uploads recorded before the authoritative finalizer was deployed.
-- Only a media row with matching ownership, lift path, and storage object may be linked.
select pg_catalog.set_config('liftrank.trusted_media_finalize', 'true', true);

update public.lift_submissions l
set
  video_asset_id = ma.id,
  evidence_status = 'video_backed',
  verification = 'Video Verified',
  updated_at = statement_timestamp()
from public.lift_media_assets ma
join storage.objects so
  on so.bucket_id = 'lift-videos'
 and so.name = ma.storage_path
where ma.lift_id = l.id
  and l.video_asset_id is null
  and l.user_id = ma.owner_id
  and so.owner_id = ma.owner_id::text
  and ma.storage_path like ma.owner_id::text || '/' || ma.lift_id::text || '/%';

select pg_catalog.set_config('liftrank.trusted_media_finalize', 'false', true);

commit;
