begin;
create or replace function public.has_platform_service_access(p_service_key text)
returns boolean language sql stable security invoker set search_path='public','private_rpc'
as $function$ select private.has_platform_service_access((select auth.uid()), $1); $function$;
revoke all on function public.has_platform_service_access(text) from public,anon;
grant execute on function public.has_platform_service_access(text) to authenticated;
commit;
