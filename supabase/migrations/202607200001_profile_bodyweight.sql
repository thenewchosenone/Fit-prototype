-- Keep the athlete's current bodyweight available across devices without
-- exposing it through the public profile table. Ranking visibility remains
-- controlled by profile_privacy.bodyweight_audience.
alter table public.profile_private_details
  add column if not exists bodyweight_lb numeric(7,2)
  check (bodyweight_lb is null or bodyweight_lb between 40 and 1500);

revoke update (bodyweight_lb) on public.profile_private_details from authenticated;
grant update (bodyweight_lb) on public.profile_private_details to authenticated;

comment on column public.profile_private_details.bodyweight_lb is
  'Owner-only current bodyweight in pounds; public ranking disclosure is governed separately.';
