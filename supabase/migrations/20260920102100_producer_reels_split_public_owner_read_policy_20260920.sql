drop policy if exists producer_reels_read on public.producer_reels;
create policy producer_reels_anon_read
on public.producer_reels
for select to anon
using (is_published = true and is_blocked = false);

create policy producer_reels_authenticated_read
on public.producer_reels
for select to authenticated
using (
  (is_published = true and is_blocked = false)
  or owner_uid = (select auth.uid())
  or (select private.is_dragon())
);
