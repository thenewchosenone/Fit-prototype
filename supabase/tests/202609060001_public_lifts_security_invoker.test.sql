begin;
select plan(2);

select has_view('public', 'public_lifts', 'public lift view remains available');

select ok(
  exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'public_lifts'
      and c.reloptions @> array['security_invoker=true']
  ),
  'public lift view evaluates with invoker privileges'
);

select * from finish();
rollback;
