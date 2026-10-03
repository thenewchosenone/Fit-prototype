begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);
select has_table('public','message_reads','message read receipts exist');
select has_table('public','message_reports','message reporting exists');
select has_table('public','hidden_message_threads','per-user thread hiding exists');
select has_function('public','get_message_threads',array[]::text[],'thread list is server authorized');
select has_function('public','create_or_get_message_thread',array['uuid'],'friend-only thread creation exists');
select has_function('public','get_thread_messages',array['uuid'],'message reads are server authorized');
select has_function('public','send_message',array['uuid','text'],'message sending is server authorized');
select has_function('public','delete_message',array['uuid'],'sender deletion exists');
select has_function('public','hide_message_thread',array['uuid'],'local thread hiding exists');
select has_function('public','report_message',array['uuid','text','text'],'message reporting exists');
select policies_are('public','message_reads',array['message reads owner'],'read receipts remain owner scoped');
select policies_are(
  'public','message_reports',
  array['message reports owner insert','message reports owner read'],
  'message reports remain reporter or moderator scoped'
);

select * from finish();
rollback;
