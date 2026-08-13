create or replace function public.register_device_token(id uuid,target_device_id text,token text,environment text)
returns void language plpgsql security definer set search_path=public as $$begin
if environment not in('sandbox','production') or char_length(token)<32 or char_length(target_device_id)>200 then raise exception 'Invalid device registration';end if;
insert into public.device_tokens(id,user_id,device_id,token,environment,revoked_at,updated_at)
values(id,auth.uid(),target_device_id,token,environment,null,now())
on conflict(user_id,device_id) do update set token=excluded.token,environment=excluded.environment,revoked_at=null,updated_at=now();end;$$;
create or replace function public.revoke_device_token(target_device_id text)
returns void language sql security definer set search_path=public as $$update public.device_tokens set revoked_at=now(),updated_at=now() where user_id=auth.uid() and device_id=target_device_id$$;
revoke all on function public.register_device_token(uuid,text,text,text) from public;revoke all on function public.revoke_device_token(text) from public;
grant execute on function public.register_device_token(uuid,text,text,text) to authenticated;grant execute on function public.revoke_device_token(text) to authenticated;
