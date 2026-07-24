#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=${TMPDIR:-/tmp}/liftrank-backend-tests-$$
PORT=${LIFTRANK_TEST_POSTGRES_PORT:-55432}
SOCKET="$WORK/socket"
PGROOT=${LIFTRANK_POSTGRES_ROOT:-/Library/PostgreSQL/15}
PGBIN="$PGROOT/bin"

for command in initdb pg_ctl createdb dropdb psql pg_config; do
  [[ -x "$PGBIN/$command" ]] || { echo "Missing $PGBIN/$command. Set LIFTRANK_POSTGRES_ROOT." >&2; exit 1; }
done

mkdir -p "$WORK" "$SOCKET"
cleanup() {
  "$PGBIN/pg_ctl" -D "$WORK/data" stop -m fast >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

"$PGBIN/initdb" -D "$WORK/data" -A trust --no-locale --encoding=UTF8 >/dev/null
"$PGBIN/pg_ctl" -D "$WORK/data" -l "$WORK/postgresql.log" -o "-p $PORT -k $SOCKET" start >/dev/null

curl -fsSL https://github.com/theory/pgtap/archive/refs/tags/v1.3.4.tar.gz -o "$WORK/pgtap.tar.gz"
tar -xzf "$WORK/pgtap.tar.gz" -C "$WORK"
make -C "$WORK/pgtap-1.3.4" PG_CONFIG="$PGBIN/pg_config" PERL=/usr/bin/perl >/dev/null
sed 's/@extschema@/extensions/g' "$WORK/pgtap-1.3.4/sql/pgtap--1.3.4.sql" > "$WORK/pgtap-load.sql"

bootstrap() {
  cat <<'SQL'
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;
create schema auth;
create table auth.users (
  instance_id uuid, id uuid primary key, aud varchar(255), role varchar(255), email varchar(255),
  encrypted_password varchar(255), email_confirmed_at timestamptz, invited_at timestamptz,
  confirmation_token varchar(255), confirmation_sent_at timestamptz, recovery_token varchar(255),
  recovery_sent_at timestamptz, email_change_token_new varchar(255), email_change varchar(255),
  email_change_sent_at timestamptz, last_sign_in_at timestamptz, raw_app_meta_data jsonb,
  raw_user_meta_data jsonb, is_super_admin boolean, created_at timestamptz, updated_at timestamptz,
  phone text, phone_confirmed_at timestamptz, phone_change text default '',
  phone_change_token varchar(255) default '', phone_change_sent_at timestamptz,
  confirmed_at timestamptz generated always as (least(email_confirmed_at, phone_confirmed_at)) stored,
  email_change_token_current varchar(255) default '', email_change_confirm_status smallint default 0,
  banned_until timestamptz, reauthentication_token varchar(255) default '',
  reauthentication_sent_at timestamptz, is_sso_user boolean not null default false,
  deleted_at timestamptz, is_anonymous boolean not null default false
);
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid
$$;
grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
create schema extensions;
grant usage on schema extensions to anon, authenticated, service_role;
create schema storage;
create table storage.buckets (
  id text primary key, name text not null unique, public boolean not null default false,
  file_size_limit bigint, allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(), bucket_id text not null references storage.buckets(id),
  name text not null, owner_id text, created_at timestamptz not null default now(),
  unique(bucket_id, name)
);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language sql immutable as $$
  select case when position('/' in name) = 0 then array[]::text[]
              else string_to_array(regexp_replace(name, '/[^/]*$', ''), '/') end
$$;
grant usage on schema storage to anon, authenticated, service_role;
grant select, insert, update, delete on storage.objects to authenticated, service_role;
grant select on storage.buckets to authenticated, service_role;
grant execute on function storage.foldername(text) to anon, authenticated, service_role;
SQL
}

run_reset() {
  local db=$1
  "$PGBIN/dropdb" -h "$SOCKET" -p "$PORT" --if-exists "$db" >/dev/null
  "$PGBIN/createdb" -h "$SOCKET" -p "$PORT" "$db"
  psql_local() { "$PGBIN/psql" -h "$SOCKET" -p "$PORT" -v ON_ERROR_STOP=1 -d "$db" "$@"; }
  bootstrap | psql_local >/dev/null
  psql_local -f "$WORK/pgtap-load.sql" >/dev/null
  for migration in "$ROOT"/supabase/migrations/*.sql; do psql_local -f "$migration" >/dev/null; done
  for test_file in "$ROOT"/supabase/tests/*.test.sql; do
    [[ "$(basename "$test_file")" == "202607140002_gym_membership_concurrency.test.sql" ]] && continue
    local staged="$WORK/$(basename "$test_file")"
    sed '/create extension if not exists pgtap/d' "$test_file" > "$staged"
    psql_local -f "$staged" | tee "$staged.$db.log"
    if grep -Eq '^[[:space:]]*not ok' "$staged.$db.log"; then exit 1; fi
  done
  local concurrency="$WORK/concurrency.sql"
  sed -e '/create extension if not exists pgtap/d' \
      -e "s#'dbname=' || current_database()#'host=$SOCKET port=$PORT dbname=' || current_database()#g" \
      "$ROOT/supabase/tests/202607140002_gym_membership_concurrency.test.sql" > "$concurrency"
  psql_local -f "$concurrency" | tee "$concurrency.$db.log"
  if grep -Eq '^[[:space:]]*not ok' "$concurrency.$db.log"; then exit 1; fi
}

run_reset liftrank_foundation_1
run_reset liftrank_foundation_2
echo "Two clean resets passed. Expected database errors are limited to rejected competing fourth-gym joins."
grep -E 'WARNING|ERROR|FATAL' "$WORK/postgresql.log" || true
