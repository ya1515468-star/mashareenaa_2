CREATE OR REPLACE FUNCTION public.get_producer_reel_owners(p_user_ids uuid[])
RETURNS TABLE(id uuid, username text, display_name text)
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  SELECT p.id,p.username,p.display_name
  FROM public.profiles p
  WHERE p.id = ANY(coalesce(p_user_ids,'{}'::uuid[]))
    AND p.is_active = true
    AND p.is_suspended = false;
$function$;

REVOKE ALL ON FUNCTION public.get_producer_reel_owners(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_producer_reel_owners(uuid[]) TO authenticated;