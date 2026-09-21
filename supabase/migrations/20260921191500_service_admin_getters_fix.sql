begin;

drop function if exists public.admin_list_platform_service_access();
create function public.admin_list_platform_service_access()
returns table(service_key text,user_id uuid,username text,display_name text,is_active boolean,granted_by uuid,created_at timestamptz)
language sql security invoker set search_path='public','private_rpc'
as $function$ select * from private_rpc.admin_list_platform_service_access(); $function$;
revoke all on function public.admin_list_platform_service_access() from public,anon;
grant execute on function public.admin_list_platform_service_access() to authenticated;

create or replace function private_rpc.service_admin_get_garment_service_catalog()
returns setof public.garment_service_catalog language sql stable security definer set search_path=''
as $function$
select * from public.garment_service_catalog
where private.has_platform_service_access((select auth.uid()),'garment_market')
order by sort_order,service_key;
$function$;
revoke all on function private_rpc.service_admin_get_garment_service_catalog() from public;
grant execute on function private_rpc.service_admin_get_garment_service_catalog() to authenticated;

create or replace function public.service_admin_get_garment_service_catalog()
returns setof public.garment_service_catalog language sql security invoker set search_path='public','private_rpc'
as $function$ select * from private_rpc.service_admin_get_garment_service_catalog(); $function$;
revoke all on function public.service_admin_get_garment_service_catalog() from public,anon;
grant execute on function public.service_admin_get_garment_service_catalog() to authenticated;

create or replace function private_rpc.service_admin_get_garment_publication_fees()
returns setof public.garment_publication_fee_rules language sql stable security definer set search_path=''
as $function$
select * from public.garment_publication_fee_rules
where private.has_platform_service_access((select auth.uid()),'garment_market')
order by content_type;
$function$;
revoke all on function private_rpc.service_admin_get_garment_publication_fees() from public;
grant execute on function private_rpc.service_admin_get_garment_publication_fees() to authenticated;

create or replace function public.service_admin_get_garment_publication_fees()
returns setof public.garment_publication_fee_rules language sql security invoker set search_path='public','private_rpc'
as $function$ select * from private_rpc.service_admin_get_garment_publication_fees(); $function$;
revoke all on function public.service_admin_get_garment_publication_fees() from public,anon;
grant execute on function public.service_admin_get_garment_publication_fees() to authenticated;

commit;
