begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

create function pg_temp.plan_payload(id uuid, flag jsonb)
returns jsonb language sql as $$
  select to_jsonb(translate(encode(convert_to(
    (jsonb_build_object('plan', jsonb_build_object('id', id, 'name', 'Program', 'createdAt', 0) ||
      case when flag is null then '{}'::jsonb else jsonb_build_object('isActive', flag) end,
      'weeks', '[]'::jsonb, 'sessions', '[]'::jsonb, 'phases', '[]'::jsonb, 'prescriptions', '[]'::jsonb,
      'futureField', jsonb_build_object('notes', 'Lifts 💪', 'value', 2.5)))::text, 'UTF8'),
    'base64'), E'\r\n', ''));
$$;

insert into auth.users(id,email) values
 ('e7100000-0000-4000-8000-000000000001','activation-owner@example.test'),
 ('e7100000-0000-4000-8000-000000000002','activation-other@example.test');

select ok(not has_function_privilege('anon','public.set_active_workout_plan(uuid,integer,uuid,integer)','execute'),'anonymous cannot activate');
select ok(has_function_privilege('authenticated','public.set_active_workout_plan(uuid,integer,uuid,integer)','execute'),'authenticated can call activation');
select ok(not has_function_privilege('authenticated','public.decode_workout_plan_document(jsonb,uuid)','execute'),'payload helper is internal');
select ok(not has_function_privilege('authenticated','public.workout_plan_document_is_active(jsonb,uuid)','execute'),'active helper is internal');
select ok(not has_function_privilege('authenticated','public.lock_workout_plan_owner(uuid)','execute'),'owners cannot lock foreign profiles with helper');
select ok(not has_function_privilege('authenticated','public.lock_workout_plan_write()','execute'),'statement lock is internal');
select ok(not has_function_privilege('authenticated','public.reconcile_workout_plan_activation()','execute'),'statement coordinator is internal');
select is((select proconfig::text from pg_proc where oid='public.set_active_workout_plan(uuid,integer,uuid,integer)'::regprocedure),'{search_path=pg_catalog}','activation pins its search path');

select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000002',true);
insert into public.workout_plan_documents(id,owner_id,name,payload)
select id,auth.uid(),'Foreign plan',pg_temp.plan_payload(id,'true') from (values ('e7200000-0000-4000-8000-000000000003'::uuid)) t(id);

set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.set_active_workout_plan(null,null,null,null)$$,'42501','Authentication required','missing owner cannot use activation');
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000001',true);
insert into public.workout_plan_documents(id,owner_id,name,payload)
select id,auth.uid(),name,pg_temp.plan_payload(id,flag)
from (values ('e7200000-0000-4000-8000-000000000001'::uuid,'First',null::jsonb),
             ('e7200000-0000-4000-8000-000000000002'::uuid,'Second','false'::jsonb)) t(id,name,flag);

select throws_ok($$select public.set_active_workout_plan('e7200000-0000-4000-8000-000000000003',1,'e7200000-0000-4000-8000-000000000001',1)$$,
 'P0002','Program is no longer available','foreign target is unavailable');
select throws_ok($$select public.set_active_workout_plan('e7200000-0000-4000-8000-000000000002',1,null,null)$$,
 '40001','Active program changed. Reload your programs.','missing flag is active and stale active snapshot fails');
select throws_ok($$select public.set_active_workout_plan('e7200000-0000-4000-8000-000000000002',2,'e7200000-0000-4000-8000-000000000001',1)$$,
 '40001','Program changed. Reload your programs.','stale target revision fails');

create temp table activation_result as select public.set_active_workout_plan(
 'e7200000-0000-4000-8000-000000000002',1,'e7200000-0000-4000-8000-000000000001',1) as documents;
select is(jsonb_array_length(documents),2,'RPC returns both final rows') from activation_result;
select is((documents#>>'{0,revision}')::integer,2,'RPC returns displaced final revision') from activation_result;
select is((documents#>>'{1,revision}')::integer,2,'RPC returns target final revision') from activation_result;
reset role;
select is((select count(*)::integer from public.workout_plan_documents where owner_id=auth.uid() and public.workout_plan_document_is_active(payload,id)),1,'exactly one owner program is active');
select is((select public.decode_workout_plan_document(payload,id)->'futureField' from public.workout_plan_documents where id='e7200000-0000-4000-8000-000000000001'),
 '{"notes":"Lifts 💪","value":2.5}'::jsonb,'displacement preserves unknown data and Unicode');
select ok(not exists(select 1 from public.workout_plan_documents where (payload#>>'{}') ~ E'[\r\n]'),'native base64 has no line wrapping');
select ok((select public.workout_plan_document_is_active(payload,id) from public.workout_plan_documents where id='e7200000-0000-4000-8000-000000000003'),'foreign active selection preserved');

set local role authenticated;
select lives_ok($$select public.set_active_workout_plan(null,null,'e7200000-0000-4000-8000-000000000002',2)$$,'owner can deactivate the current program');
select throws_ok($$update public.workout_plan_documents set payload=pg_temp.plan_payload(id,'true'),revision=revision+1$$,
 '23514','Select one active program per change','ambiguous activation of two rows rolls back');
select throws_ok($$update public.workout_plan_documents set payload='"e30="' where name='First'$$,
 '22023','Invalid synced workout plan identity or active state','missing plan fails closed');
select throws_ok($$update public.workout_plan_documents set payload=pg_temp.plan_payload(id,'"false"') where name='First'$$,
 '22023','Invalid synced workout plan identity or active state','string active flag fails closed');
select throws_ok($$update public.workout_plan_documents set payload=pg_temp.plan_payload('e7200000-0000-4000-8000-000000000002','true') where name='First'$$,
 '22023','Invalid synced workout plan identity or active state','payload ID must match the document ID');
select throws_ok($$update public.workout_plan_documents set payload=to_jsonb((payload#>>'{}') || E'\n') where name='First'$$,
 '22023','Invalid synced workout plan encoding','wrapped payload does not reach frozen Swift');
select throws_ok($$
 update public.workout_plan_documents
 set payload=to_jsonb(translate(encode(convert_to(
  '{"plan":{"id":"e7200000-0000-4000-8000-000000000001","isActive":true,"isActive":false}}','UTF8'),
  'base64'), E'\r\n', '')) where name='First'
 $$,'22023','Duplicate synced workout plan identity or active state','duplicate active flags cannot disagree with the native decoder');
select throws_ok($$
 update public.workout_plan_documents
 set payload=to_jsonb(translate(encode(convert_to(
  '{"plan":{"id":"e7200000-0000-4000-8000-000000000001","isActive":true},"plan":{"id":"e7200000-0000-4000-8000-000000000001","isActive":false}}','UTF8'),
  'base64'), E'\r\n', '')) where name='First'
 $$,'22023','Duplicate synced workout plan identity or active state','duplicate plan keys fail before jsonb conversion');
select throws_ok($$
 update public.workout_plan_documents
 set payload=to_jsonb(translate(encode(convert_to(
  '{"plan":{"id":"e7200000-0000-4000-8000-000000000002","id":"e7200000-0000-4000-8000-000000000001","isActive":false}}','UTF8'),
  'base64'), E'\r\n', '')) where name='First'
 $$,'22023','Duplicate synced workout plan identity or active state','duplicate identity keys fail before jsonb conversion');
select lives_ok($$update public.workout_plan_documents set payload=pg_temp.plan_payload(id,'null'),revision=revision+1 where name='First' and revision=2$$,'native null flag activates with its original revision');
select lives_ok($$update public.workout_plan_documents set payload=pg_temp.plan_payload(id,'true'),revision=revision+1 where name='Second' and revision=3$$,'native CAS activates the second program and displaces the first');
select lives_ok($$update public.workout_plan_documents set payload=pg_temp.plan_payload(id,to_jsonb(name='First')),revision=revision+1$$,'bulk native-style switch avoids modifying a row mid-statement');
select lives_ok($$update public.workout_plan_documents set payload=pg_temp.plan_payload(id,'true'),revision=revision+1$$,'after-statement coordination safely displaces an active row also visited by a bulk write');

reset role;
select is((select count(*)::integer from public.workout_plan_documents where owner_id=auth.uid() and public.workout_plan_document_is_active(payload,id)),1,'native writes keep exactly one active after a switch');
select is((select name from public.workout_plan_documents where owner_id=auth.uid() and public.workout_plan_document_is_active(payload,id)),'Second','sole false-to-true transition wins');
select set_config('request.jwt.claim.sub','',true);
select lives_ok($$delete from auth.users where id='e7100000-0000-4000-8000-000000000001'$$,'trusted account deletion without JWT can cascade');
select is((select count(*)::integer from public.workout_plan_documents where owner_id='e7100000-0000-4000-8000-000000000001'),0,'cascade removes owner plans');

select * from finish();
rollback;
