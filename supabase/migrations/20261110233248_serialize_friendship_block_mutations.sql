begin;
-- Pair-wide transaction locks coordinate missing relationships as well as existing
-- rows. Each blocked-state check is a separate statement after the lock wait.
-- Reject snapshot isolation: it cannot refresh that check after a concurrent block.
CREATE OR REPLACE FUNCTION public.request_friendship(target_user_id uuid)
 RETURNS public.friend_relationships
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  caller uuid := auth.uid();
  low_id uuid;
  high_id uuid;
  existing public.friend_relationships;
begin
  if caller is null then raise exception using errcode = '28000', message = 'Authentication required'; end if;
  if caller = target_user_id then raise exception using errcode = '23514', message = 'Users cannot friend themselves'; end if;
  if not exists (select 1 from public.profiles p where p.id = target_user_id) then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;
  low_id := case when caller::text < target_user_id::text then caller else target_user_id end;
  high_id := case when caller::text < target_user_id::text then target_user_id else caller end;

  if pg_catalog.current_setting('transaction_isolation') not in ('read committed','read uncommitted') then
    raise exception using errcode='25000',message='Friendship mutations require Read Committed isolation';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('liftrivals.friendship_pair:'||low_id::text||':'||high_id::text,0));
  if public.is_blocked_pair(caller,target_user_id) then
    raise exception using errcode='42501',message='Friendship is unavailable for blocked users';
  end if;

  select fr.* into existing from public.friend_relationships fr
  where fr.user_low_id = low_id and fr.user_high_id = high_id
  for update;

  if found and existing.status in ('pending', 'accepted') then
    raise exception using errcode = '23505', message = 'A friendship or pending request already exists';
  elsif found then
    update public.friend_relationships fr
    set requested_by = caller,
        status = 'pending',
        responded_at = null,
        updated_at = statement_timestamp()
    where fr.id = existing.id
    returning fr.* into existing;
    return existing;
  end if;

  insert into public.friend_relationships (user_low_id, user_high_id, requested_by)
  values (low_id, high_id, caller)
  returning * into existing;
  return existing;
end;
$function$;

CREATE OR REPLACE FUNCTION public.respond_to_friendship(relationship_id uuid, accept_request boolean)
 RETURNS public.friend_relationships
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare caller uuid := auth.uid(); result public.friend_relationships;
begin
  if caller is null then raise exception using errcode = '28000', message = 'Authentication required'; end if;
  select fr.* into result from public.friend_relationships fr where fr.id=relationship_id;
  if not found then raise exception using errcode='P0002',message='Friend request not found'; end if;
  if pg_catalog.current_setting('transaction_isolation') not in ('read committed','read uncommitted') then
    raise exception using errcode='25000',message='Friendship mutations require Read Committed isolation';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('liftrivals.friendship_pair:'||result.user_low_id::text||':'||result.user_high_id::text,0));
  select fr.* into result from public.friend_relationships fr where fr.id = relationship_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'Friend request not found'; end if;
  if result.status <> 'pending' then raise exception using errcode = '23514', message = 'Friend request is no longer pending'; end if;
  if caller = result.requested_by or caller not in (result.user_low_id, result.user_high_id) then
    raise exception using errcode = '42501', message = 'Only the recipient may respond to a friend request';
  end if;
  if public.is_blocked_pair(result.user_low_id,result.user_high_id) then
    raise exception using errcode='42501',message='Friendship is unavailable for blocked users';
  end if;
  update public.friend_relationships fr
  set status = case when accept_request then 'accepted' else 'declined' end,
      responded_at = statement_timestamp(),
      updated_at = statement_timestamp()
  where fr.id = relationship_id returning fr.* into result;
  return result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.block_user(target_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if target_user_id = caller_id then
    raise exception 'cannot block yourself';
  end if;
  if pg_catalog.current_setting('transaction_isolation') not in ('read committed','read uncommitted') then
    raise exception using errcode='25000',message='Friendship mutations require Read Committed isolation';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('liftrivals.friendship_pair:'||least(caller_id,target_user_id)::text||':'||greatest(caller_id,target_user_id)::text,0));
  insert into public.user_blocks(blocker_id, blocked_id)
  values(caller_id, target_user_id) on conflict do nothing;
  delete from public.friend_relationships
  where user_low_id in (caller_id, target_user_id)
    and user_high_id in (caller_id, target_user_id);
end $function$;

create or replace function public.unblock_user(target_user_id uuid)
returns void language plpgsql security definer set search_path=pg_catalog as $$
declare caller_id uuid:=auth.uid();
begin
  if caller_id is null then raise exception 'authentication required' using errcode='42501'; end if;
  if pg_catalog.current_setting('transaction_isolation') not in ('read committed','read uncommitted') then
    raise exception using errcode='25000',message='Friendship mutations require Read Committed isolation';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('liftrivals.friendship_pair:'||least(caller_id,target_user_id)::text||':'||greatest(caller_id,target_user_id)::text,0));
  delete from public.user_blocks where blocker_id=caller_id and blocked_id=target_user_id;
  -- Clean historical latent relationships only when this caller actually had a
  -- block. A repeated unblock must not remove an ordinary accepted friendship.
  if found then
    delete from public.friend_relationships
    where user_low_id=least(caller_id,target_user_id) and user_high_id=greatest(caller_id,target_user_id);
  end if;
end;
$$;


create or replace function public.are_friends(left_id uuid,right_id uuid)
returns boolean language sql stable security definer set search_path=pg_catalog as $$
  select coalesce(exists(
    select 1 from public.friend_relationships fr
    where auth.uid() in (left_id,right_id)
      and fr.status='accepted'
      and fr.user_low_id=least(left_id,right_id) and fr.user_high_id=greatest(left_id,right_id)
      and not public.is_blocked_pair(left_id,right_id)
  ),false)
$$;

revoke all on function public.request_friendship(uuid),public.respond_to_friendship(uuid,boolean),public.block_user(uuid),public.unblock_user(uuid) from public,anon;
grant execute on function public.request_friendship(uuid),public.respond_to_friendship(uuid,boolean),public.block_user(uuid),public.unblock_user(uuid) to authenticated;
-- RLS does not cover TRUNCATE; these unused raw SQL privileges bypass the RPC owner.
revoke truncate,references,trigger on public.user_blocks from public,anon,authenticated;
commit;
