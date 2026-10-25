begin;
select plan(1);

select ok(
  has_table_privilege('authenticated', 'public.lift_media_assets', 'select'),
  'authenticated playback can evaluate lift media storage policy'
);

select * from finish();
rollback;
