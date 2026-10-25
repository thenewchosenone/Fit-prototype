begin;

grant select, insert, update on table public.lift_removal_requests to service_role;

commit;
