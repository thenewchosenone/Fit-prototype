-- Legal acceptance is append-only evidence. Authenticated members can read
-- their own history and insert the exact version they accepted, but cannot
-- rewrite or erase prior acceptance rows.
drop policy if exists "legal owner insert read" on public.legal_acceptances;

create policy "legal owner read"
on public.legal_acceptances
for select
to authenticated
using (user_id = auth.uid());

create policy "legal owner insert"
on public.legal_acceptances
for insert
to authenticated
with check (
  user_id = auth.uid()
  and document_kind in ('privacy', 'terms', 'community_rules', 'fitness_disclaimer')
  and length(document_version) between 1 and 64
);

revoke update, delete on public.legal_acceptances from authenticated;
