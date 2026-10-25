begin;

do $$
declare
  target_user_id constant uuid := 'da42a9e6-8898-45f4-8dbb-a14e2d3f8100';
  target_lift_ids constant uuid[] := array[
    'aaaaaaaa-0002-4002-8002-aaaaaaaaaaaa'::uuid,
    'bbbbbbbb-0001-4001-8001-bbbbbbbbbbbb'::uuid,
    'aaaaaaaa-0001-4001-8001-aaaaaaaaaaaa'::uuid,
    'cccccccc-0001-4001-8001-cccccccccccc'::uuid,
    'cccccccc-0002-4002-8002-cccccccccccc'::uuid,
    'bbbbbbbb-0002-4002-8002-bbbbbbbbbbbb'::uuid
  ];
  matched_lifts integer;
begin
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'Target Lift Rivals profile does not exist';
  end if;

  select count(*) into matched_lifts
  from public.lift_submissions
  where id = any(target_lift_ids);

  if matched_lifts <> cardinality(target_lift_ids) then
    raise exception 'Expected % seeded lifts, found %', cardinality(target_lift_ids), matched_lifts;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_trigger
    where tgrelid = 'public.lift_submissions'::regclass
      and tgname = 'competitive_lift_authority'
      and not tgisinternal
  ) then
    raise exception 'Competitive lift ownership trigger is missing';
  end if;
end;
$$;

alter table public.lift_submissions disable trigger competitive_lift_authority;

update public.lift_submissions
set user_id = 'da42a9e6-8898-45f4-8dbb-a14e2d3f8100',
    updated_at = statement_timestamp()
where id = any(array[
  'aaaaaaaa-0002-4002-8002-aaaaaaaaaaaa'::uuid,
  'bbbbbbbb-0001-4001-8001-bbbbbbbbbbbb'::uuid,
  'aaaaaaaa-0001-4001-8001-aaaaaaaaaaaa'::uuid,
  'cccccccc-0001-4001-8001-cccccccccccc'::uuid,
  'cccccccc-0002-4002-8002-cccccccccccc'::uuid,
  'bbbbbbbb-0002-4002-8002-bbbbbbbbbbbb'::uuid
]);

update public.lift_media_assets
set owner_id = 'da42a9e6-8898-45f4-8dbb-a14e2d3f8100'
where lift_id = any(array[
  'aaaaaaaa-0002-4002-8002-aaaaaaaaaaaa'::uuid,
  'bbbbbbbb-0001-4001-8001-bbbbbbbbbbbb'::uuid,
  'aaaaaaaa-0001-4001-8001-aaaaaaaaaaaa'::uuid,
  'cccccccc-0001-4001-8001-cccccccccccc'::uuid,
  'cccccccc-0002-4002-8002-cccccccccccc'::uuid,
  'bbbbbbbb-0002-4002-8002-bbbbbbbbbbbb'::uuid
]);

update public.lift_removal_requests
set owner_id = 'da42a9e6-8898-45f4-8dbb-a14e2d3f8100',
    updated_at = statement_timestamp()
where lift_id = any(array[
  'aaaaaaaa-0002-4002-8002-aaaaaaaaaaaa'::uuid,
  'bbbbbbbb-0001-4001-8001-bbbbbbbbbbbb'::uuid,
  'aaaaaaaa-0001-4001-8001-aaaaaaaaaaaa'::uuid,
  'cccccccc-0001-4001-8001-cccccccccccc'::uuid,
  'cccccccc-0002-4002-8002-cccccccccccc'::uuid,
  'bbbbbbbb-0002-4002-8002-bbbbbbbbbbbb'::uuid
]);

alter table public.lift_submissions enable trigger competitive_lift_authority;

do $$
declare
  transferred_lifts integer;
begin
  select count(*) into transferred_lifts
  from public.lift_submissions
  where id = any(array[
    'aaaaaaaa-0002-4002-8002-aaaaaaaaaaaa'::uuid,
    'bbbbbbbb-0001-4001-8001-bbbbbbbbbbbb'::uuid,
    'aaaaaaaa-0001-4001-8001-aaaaaaaaaaaa'::uuid,
    'cccccccc-0001-4001-8001-cccccccccccc'::uuid,
    'cccccccc-0002-4002-8002-cccccccccccc'::uuid,
    'bbbbbbbb-0002-4002-8002-bbbbbbbbbbbb'::uuid
  ]) and user_id = 'da42a9e6-8898-45f4-8dbb-a14e2d3f8100';

  if transferred_lifts <> 6 then
    raise exception 'Seeded lift ownership transfer did not complete';
  end if;
end;
$$;

commit;
