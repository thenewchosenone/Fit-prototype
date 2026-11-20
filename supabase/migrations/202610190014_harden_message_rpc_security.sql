begin;

alter function public.get_message_threads()
  set search_path = pg_catalog;
alter function public.create_or_get_message_thread(uuid)
  set search_path = pg_catalog;
alter function public.get_thread_messages(uuid)
  set search_path = pg_catalog;
alter function public.send_message(uuid, text)
  set search_path = pg_catalog;
alter function public.delete_message(uuid)
  set search_path = pg_catalog;
alter function public.hide_message_thread(uuid)
  set search_path = pg_catalog;
alter function public.report_message(uuid, text, text)
  set search_path = pg_catalog;

revoke all on function public.get_message_threads() from public, anon, service_role;
revoke all on function public.create_or_get_message_thread(uuid) from public, anon, service_role;
revoke all on function public.get_thread_messages(uuid) from public, anon, service_role;
revoke all on function public.send_message(uuid, text) from public, anon, service_role;
revoke all on function public.delete_message(uuid) from public, anon, service_role;
revoke all on function public.hide_message_thread(uuid) from public, anon, service_role;
revoke all on function public.report_message(uuid, text, text) from public, anon, service_role;

grant execute on function public.get_message_threads() to authenticated;
grant execute on function public.create_or_get_message_thread(uuid) to authenticated;
grant execute on function public.get_thread_messages(uuid) to authenticated;
grant execute on function public.send_message(uuid, text) to authenticated;
grant execute on function public.delete_message(uuid) to authenticated;
grant execute on function public.hide_message_thread(uuid) to authenticated;
grant execute on function public.report_message(uuid, text, text) to authenticated;

commit;
