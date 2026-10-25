create table public.web_push_subscriptions (
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text primary key,
  subscription jsonb not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (subscription ->> 'endpoint' = endpoint),
  check (endpoint ~ '^https://(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|push\.services\.mozilla\.com|web\.push\.apple\.com)/')
);

create index web_push_subscriptions_active_user_idx
  on public.web_push_subscriptions(user_id)
  where revoked_at is null;

alter table public.web_push_subscriptions enable row level security;
revoke all on table public.web_push_subscriptions from anon, authenticated;
grant all on table public.web_push_subscriptions to service_role;

create function public.register_own_web_push_subscription(target_subscription jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_user_id uuid := auth.uid();
  endpoint_value text := target_subscription ->> 'endpoint';
  keys_value jsonb := target_subscription -> 'keys';
  affected integer;
begin
  if owner_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if pg_catalog.jsonb_typeof(target_subscription) is distinct from 'object'
     or endpoint_value is null
     or pg_catalog.length(endpoint_value) > 2048
     or endpoint_value !~ '^https://(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|push\.services\.mozilla\.com|web\.push\.apple\.com)/'
     or pg_catalog.jsonb_typeof(keys_value) is distinct from 'object'
     or keys_value ->> 'auth' is null
     or pg_catalog.length(keys_value ->> 'auth') not between 16 and 512
     or keys_value ->> 'p256dh' is null
     or pg_catalog.length(keys_value ->> 'p256dh') not between 40 and 512 then
    raise exception using errcode = '22023', message = 'Invalid web push subscription';
  end if;

  insert into public.web_push_subscriptions(user_id, endpoint, subscription, revoked_at, updated_at)
  values(owner_user_id, endpoint_value, target_subscription, null, pg_catalog.now())
  on conflict(endpoint) do update
    set user_id = excluded.user_id,
        subscription = excluded.subscription,
        revoked_at = null,
        updated_at = pg_catalog.now()
    where public.web_push_subscriptions.user_id = owner_user_id;
  get diagnostics affected = row_count;
  if affected = 0 then
    raise exception using errcode = '42501', message = 'Subscription belongs to another account';
  end if;
end;
$$;

create function public.revoke_own_web_push_subscription(target_endpoint text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_user_id uuid := auth.uid();
  affected integer;
begin
  if owner_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  update public.web_push_subscriptions
  set revoked_at = coalesce(revoked_at, pg_catalog.now()), updated_at = pg_catalog.now()
  where user_id = owner_user_id and endpoint = target_endpoint;
  get diagnostics affected = row_count;
  return affected > 0;
end;
$$;

revoke all on function public.register_own_web_push_subscription(jsonb) from public, anon;
revoke all on function public.revoke_own_web_push_subscription(text) from public, anon;
grant execute on function public.register_own_web_push_subscription(jsonb) to authenticated;
grant execute on function public.revoke_own_web_push_subscription(text) to authenticated;

alter table public.notifications add column web_push_sent_at timestamptz;
-- Do not generate a browser-push backlog from notifications that predate this channel.
update public.notifications
set web_push_sent_at = created_at
where web_push_sent_at is null;
