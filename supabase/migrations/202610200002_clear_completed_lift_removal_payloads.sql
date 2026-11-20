begin;

-- Keep the minimal completion marker for idempotent retries; discard the
-- deleted lift snapshot and storage paths once cleanup has completed.
update public.lift_removal_requests
set lift_snapshot = '{}'::jsonb,
    storage_objects = '[]'::jsonb
where status = 'completed'
  and (lift_snapshot is distinct from '{}'::jsonb
    or storage_objects is distinct from '[]'::jsonb);

commit;
