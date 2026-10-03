begin;

-- Storage playback policies inspect these rows as the authenticated role.
grant select on public.lift_media_assets to authenticated;

commit;
