-- Global production server-authority hardening.
-- Client roles keep only the explicitly required read surface.
-- Server-side RPCs / Edge Functions perform authoritative writes.

revoke truncate on all tables in schema public from anon, authenticated;

revoke insert, update, delete, truncate
  on table public.garment_businesses,
             public.garment_products,
             public.platform_broadcast_requests
  from anon, authenticated;

grant select
  on table public.garment_businesses,
             public.garment_products
  to anon, authenticated;

grant select
  on table public.platform_broadcast_requests
  to authenticated;
