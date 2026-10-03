begin;

create or replace function public.protect_lift_review_fields()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if auth.uid() = old.user_id
    and not public.is_admin()
    and coalesce(pg_catalog.current_setting('liftrank.trusted_media_finalize', true), 'false') <> 'true'
    and not exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role in ('Moderator'::public.app_role, 'Admin'::public.app_role)
    )
  then
    new.review_status := old.review_status;
    new.verification := old.verification;
    new.evidence_public := old.evidence_public;
    new.disputed_at := old.disputed_at;
    new.reviewed_at := old.reviewed_at;
    new.reviewed_by := old.reviewed_by;
    new.review_note := old.review_note;
  end if;
  return new;
end;
$$;

commit;
