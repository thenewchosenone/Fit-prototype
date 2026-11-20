-- Public is the initial choice for the profile fields offered during onboarding.
-- Changing defaults does not alter any existing account's saved audiences.
alter table public.profile_privacy
  alter column profile_audience set default 'public',
  alter column bodyweight_audience set default 'public',
  alter column location_audience set default 'public',
  alter column gym_audience set default 'public',
  alter column show_lift_videos set default true;
