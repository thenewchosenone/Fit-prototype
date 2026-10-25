-- Public lift rows must be evaluated with the querying user's privileges and
-- row-level security policies, not the view owner's privileges.
alter view public.public_lifts set (security_invoker = true);
