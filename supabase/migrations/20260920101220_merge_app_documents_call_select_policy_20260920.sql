drop policy if exists app_documents_calls_callee_select on public.app_documents;
drop policy if exists app_documents_select_secure on public.app_documents;
create policy app_documents_select_secure on public.app_documents
for select to authenticated
using (
  private.is_dragon()
  or owner_id = (select auth.uid())
  or collection_path = any(array['public_profiles','posts','listings','subscription_tiers','broadcasts'])
  or (
    collection_path = 'calls'
    and (data ->> 'calleeUid') = ((select auth.uid()))::text
  )
);
