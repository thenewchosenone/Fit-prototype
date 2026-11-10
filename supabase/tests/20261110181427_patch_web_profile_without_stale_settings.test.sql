begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into auth.users(id,email) values
 ('c2100000-0000-4000-8000-000000000001','web-patch-owner@example.test'),
 ('c2100000-0000-4000-8000-000000000002','web-patch-other@example.test');
update public.profiles set display_name='Patch Owner',bio='original',avatar_path='preserved-avatar'
where id='c2100000-0000-4000-8000-000000000001';
update public.profile_private_details set preferred_unit='kg',years_experience=7,bodyweight_lb=180,training_focus='mixed'
where user_id='c2100000-0000-4000-8000-000000000001';
update public.profile_privacy set profile_audience='public',show_lift_videos=true,friend_list_audience='friends'
where user_id='c2100000-0000-4000-8000-000000000001';

select is_definer('public','save_own_profile_web_patch',array['jsonb','jsonb'],'limited owner profile patch has explicit definer boundary');
select is((select proconfig::text from pg_proc where oid='public.save_own_profile_web_patch(jsonb,jsonb)'::regprocedure),'{search_path=pg_catalog}','profile patch has fixed search path');
select ok(not has_function_privilege('anon','public.save_own_profile_web_patch(jsonb,jsonb)','execute'),'anonymous callers cannot patch profiles');
select ok(has_function_privilege('authenticated','public.save_own_profile_web_patch(jsonb,jsonb)','execute'),'signed-in callers can patch their profile');

set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.save_own_profile_web_patch('{}','{}')$$,'42501','Authentication required','role without identity cannot write');
select set_config('request.jwt.claim.sub','c2100000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.save_own_profile_web_patch('[]','{}')$$,'22023','Profile changes must be objects','non-object input rejected');
select throws_ok($$select public.save_own_profile_web_patch('{"role":"admin"}','{"role":null}')$$,'22023','Invalid profile fields','authority fields rejected');
select throws_ok($$select public.save_own_profile_web_patch('{"user_id":"c2100000-0000-4000-8000-000000000002"}','{"user_id":null}')$$,'22023','Invalid profile fields','target account injection rejected');
select throws_ok($$select public.save_own_profile_web_patch('{"bio":"new"}','{}')$$,'22023','Invalid profile fields','every dirty field needs baseline');
select throws_ok($$select public.save_own_profile_web_patch('{"bio":"new"}','{"bio":"original","city":null}')$$,'22023','Invalid profile fields','extraneous baseline field rejected');
select lives_ok($$select public.save_own_profile_web_patch('{"bio":"new"}','{"bio":"original"}')$$,'bio patch works without submitting stale settings');
select is((select bio from public.profiles where id=auth.uid()),'new','bio changed');
select is((select preferred_unit from public.profile_private_details where user_id=auth.uid()),'kg','unchanged units preserved');
select is((select years_experience::integer from public.profile_private_details where user_id=auth.uid()),7,'unchanged experience preserved');
select is((select profile_audience from public.profile_privacy where user_id=auth.uid()),'public','unchanged privacy preserved');
select ok((select show_lift_videos from public.profile_privacy where user_id=auth.uid()),'unchanged video preference preserved');
select is((select friend_list_audience from public.profile_privacy where user_id=auth.uid()),'friends','unrelated friend setting preserved');
select is((select training_focus from public.profile_private_details where user_id=auth.uid()),'mixed','focus preserved');
select is((select bodyweight_lb::numeric from public.profile_private_details where user_id=auth.uid()),180::numeric,'bodyweight preserved');
select is((select avatar_path from public.profiles where id=auth.uid()),'preserved-avatar','avatar preserved');
select ok(not (select onboarding_completed from public.profiles where id=auth.uid()),'ordinary edit does not complete setup');
select lives_ok($$select public.save_own_profile_web_patch('{"bio":"new"}','{"bio":"original"}')$$,'same desired value retry is idempotent');
select throws_ok($$select public.save_own_profile_web_patch('{"profile_audience":"private"}','{"profile_audience":"friends"}')$$,'40001','Profile settings changed on another device','stale dirty privacy conflicts');
select is((select profile_audience from public.profile_privacy where user_id=auth.uid()),'public','conflict preserves current privacy');
select lives_ok($$select public.save_own_profile_web_patch('{"profile_audience":"friends","show_lift_videos":false}','{"profile_audience":"public","show_lift_videos":true}')$$,'intentional privacy change uses original baseline');
select is((select profile_audience from public.profile_privacy where user_id=auth.uid()),'friends','desired privacy saved');
select throws_ok($$select public.save_own_profile_web_patch('{"preferred_unit":"lb"}','{"preferred_unit":"lb"}')$$,'40001','Profile settings changed on another device','stale unit conflict detected');
select throws_ok($$select public.save_own_profile_web_patch('{"show_lift_videos":"true"}','{"show_lift_videos":false}')$$,'22023','Invalid profile boolean','string boolean rejected');
select throws_ok($$select public.save_own_profile_web_patch('{"years_experience":999}','{"years_experience":7}')$$,'22023','Years training must be between 0 and 100','invalid experience rejected');
select throws_ok($$select public.save_own_profile_web_patch('{"years_experience":1.5}','{"years_experience":7}')$$,'22023','Years training must be between 0 and 100','fractional years rejected');
select lives_ok($$select public.save_own_profile_web_patch('{"onboarding_completed":true}','{"onboarding_completed":false}')$$,'explicit guided completion supported');
select throws_ok($$select public.save_own_profile_web_patch('{"onboarding_completed":false}','{"onboarding_completed":true}')$$,'22023','Onboarding completion cannot be cleared here','setup cannot be cleared');

-- A later validation error must roll back identity changes and their audit row.
reset role;
create temporary table old_patch_username as select username from public.profiles where id='c2100000-0000-4000-8000-000000000001';
grant select on old_patch_username to authenticated;
set local role authenticated;
select throws_ok(format('select public.save_own_profile_web_patch(%L::jsonb,%L::jsonb)',
 jsonb_build_object('username','web_patch_changed','preferred_unit','invalid'),
 jsonb_build_object('username',(select username from old_patch_username),'preferred_unit','kg')),'23514',null,'later failure rolls back username mutation');
select is((select username from public.profiles where id=auth.uid()),(select username from old_patch_username),'username unchanged after failed transaction');
reset role;
select is((select count(*)::integer from public.profile_username_changes where user_id='c2100000-0000-4000-8000-000000000001'),0,'failed transaction leaves no username audit row');
select is((select bio from public.profiles where id='c2100000-0000-4000-8000-000000000002'),'','other account unchanged');

select * from finish();
rollback;
