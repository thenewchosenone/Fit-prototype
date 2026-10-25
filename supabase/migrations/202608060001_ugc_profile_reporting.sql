alter type public.lift_report_reason add value if not exists 'Harassment or bullying';
alter type public.lift_report_reason add value if not exists 'Hate speech';
alter type public.lift_report_reason add value if not exists 'Nudity or sexual content';
alter type public.lift_report_reason add value if not exists 'Violence or dangerous behavior';
alter type public.lift_report_reason add value if not exists 'Spam or scam';

create table public.profile_reports (
  id uuid primary key default gen_random_uuid(),
  reported_user_id uuid not null references public.profiles(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 80),
  note text not null default '' check (char_length(note) <= 1000),
  status text not null default 'Open' check (status in ('Open', 'Resolved')),
  created_at timestamptz not null default statement_timestamp(),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id),
  check (reported_user_id <> reporter_id)
);

create unique index profile_reports_one_open_per_user
  on public.profile_reports(reported_user_id, reporter_id)
  where status = 'Open';

alter table public.profile_reports enable row level security;

create policy "profile reports reporter or admin read"
  on public.profile_reports
  for select
  to authenticated
  using (reporter_id = auth.uid() or public.is_admin());

create or replace function public.report_profile(
  target_user_id uuid,
  report_reason text,
  report_note text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  clean_reason text := btrim(coalesce(report_reason, ''));
  clean_note text := left(btrim(coalesce(report_note, '')), 1000);
begin
  if caller_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if target_user_id = caller_id then
    raise exception 'You cannot report yourself' using errcode = '23514';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'Profile not found' using errcode = 'P0002';
  end if;
  if public.is_blocked_pair(caller_id, target_user_id) then
    raise exception 'Permission denied' using errcode = '42501';
  end if;
  if char_length(clean_reason) not between 1 and 80 then
    raise exception 'Choose a valid report reason' using errcode = '22023';
  end if;

  update public.profile_reports
  set reason = clean_reason,
      note = clean_note,
      created_at = statement_timestamp()
  where reported_user_id = target_user_id
    and reporter_id = caller_id
    and status = 'Open';

  if not found then
    insert into public.profile_reports(reported_user_id, reporter_id, reason, note)
    values (target_user_id, caller_id, clean_reason, clean_note);
  end if;
end;
$$;

revoke all on table public.profile_reports from public, anon, authenticated;
grant select on table public.profile_reports to authenticated;
revoke all on function public.report_profile(uuid, text, text) from public, anon;
grant execute on function public.report_profile(uuid, text, text) to authenticated;
