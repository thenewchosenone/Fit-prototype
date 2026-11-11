begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

select ok(has_column_privilege('authenticated','public.user_blocks',column_name,'SELECT'),
          'authenticated may read own block column '||column_name)
from unnest(array['blocker_id','blocked_id','created_at']) as column_name;
select ok(not has_column_privilege('anon','public.user_blocks',column_name,'SELECT'),
          'anonymous has no block read grant for '||column_name)
from unnest(array['blocker_id','blocked_id','created_at']) as column_name;
select ok(not has_table_privilege('authenticated','public.user_blocks',privilege),
          'raw block mutation remains denied for '||privilege)
from unnest(array['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) as privilege;
select ok((select relrowsecurity from pg_class where oid='public.user_blocks'::regclass),
          'block row security stays enabled');

insert into auth.users(id,email) values
('ef100000-0000-4000-8000-000000000001','block-read-a@example.test'),
('ef100000-0000-4000-8000-000000000002','block-read-b@example.test'),
('ef100000-0000-4000-8000-000000000003','block-read-c@example.test');
insert into public.user_blocks(blocker_id,blocked_id) values
('ef100000-0000-4000-8000-000000000001','ef100000-0000-4000-8000-000000000003'),
('ef100000-0000-4000-8000-000000000002','ef100000-0000-4000-8000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.sub','ef100000-0000-4000-8000-000000000001',true);
select results_eq(
  $$select blocked_id from public.user_blocks order by blocked_id$$,
  $$values ('ef100000-0000-4000-8000-000000000003'::uuid)$$,
  'owner reads only their own block row'
);
select is((select count(*)::integer from public.user_blocks where blocker_id='ef100000-0000-4000-8000-000000000002'),0,
          'another blocker remains invisible even with an explicit filter');
select lives_ok(
  $$select blocker_id,blocked_id,created_at from public.user_blocks where blocker_id=auth.uid() order by blocked_id limit 500$$,
  'website query works through the narrow column grants'
);
select set_config('request.jwt.claim.sub','',true);
select is((select count(*)::integer from public.user_blocks),0,'a missing JWT sees no block rows');

reset role;
set local role anon;
select throws_ok($$select blocked_id from public.user_blocks$$,'42501',null,'anonymous runtime read is rejected');
reset role;
select * from finish();
rollback;
