begin;

alter table public.profile_private_details
  add column training_focus text
  check (training_focus in ('bodybuilding', 'powerlifting', 'generalFitness', 'mixed'));

-- The existing owner-only policies also protect this account preference.
grant update (training_focus) on public.profile_private_details to authenticated;

commit;
