ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS address text;

CREATE OR REPLACE FUNCTION private_rpc.sync_my_public_profile(
  p_display_name text DEFAULT NULL,p_avatar_url text DEFAULT NULL,p_status_text text DEFAULT NULL,p_bio text DEFAULT NULL,
  p_cover_url text DEFAULT NULL,p_profile_music_url text DEFAULT NULL,p_country text DEFAULT NULL,p_city text DEFAULT NULL,
  p_profession text DEFAULT NULL,p_experiences jsonb DEFAULT NULL,p_social_links jsonb DEFAULT NULL,p_visibility text DEFAULT NULL,
  p_account_type text DEFAULT NULL,p_username_color numeric DEFAULT NULL,p_status_bold boolean DEFAULT NULL,p_status_italic boolean DEFAULT NULL,
  p_status_color numeric DEFAULT NULL,p_animated_avatar_url text DEFAULT NULL,p_profile_music_duration_ms integer DEFAULT NULL,
  p_profile_music_size_bytes numeric DEFAULT NULL,p_username_font_size double precision DEFAULT NULL,p_status_font_size double precision DEFAULT NULL,
  p_address text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_current public.profiles;
  v_music text := nullif(trim(coalesce(p_profile_music_url,'')),'');
  v_social text := coalesce(p_social_links::text,'');
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO v_current FROM public.profiles WHERE id=v_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'PROFILE_NOT_FOUND'; END IF;
  IF p_visibility='private' AND NOT public.is_my_profile_service('hide_profile') THEN RAISE EXCEPTION 'FEATURE_REQUIRED_HIDE_PROFILE'; END IF;
  IF p_profile_music_url IS NOT NULL AND coalesce(v_music,'')<>coalesce(v_current.profile_music_url,'') AND NOT public.is_my_profile_service('profile_music') THEN RAISE EXCEPTION 'FEATURE_REQUIRED_PROFILE_MUSIC'; END IF;
  IF (lower(v_social) like '%facebook%' OR lower(v_social) like '%tiktok%') AND NOT public.is_my_profile_service('social_links') THEN RAISE EXCEPTION 'FEATURE_REQUIRED_SOCIAL_LINKS'; END IF;
  IF p_username_font_size IS NOT NULL AND (p_username_font_size<14 OR p_username_font_size>34) THEN RAISE EXCEPTION 'INVALID_USERNAME_FONT_SIZE'; END IF;
  IF p_status_font_size IS NOT NULL AND (p_status_font_size<10 OR p_status_font_size>22) THEN RAISE EXCEPTION 'INVALID_STATUS_FONT_SIZE'; END IF;
  IF v_music IS NOT NULL AND (p_profile_music_duration_ms IS NULL OR p_profile_music_duration_ms<1 OR p_profile_music_duration_ms>15000) THEN RAISE EXCEPTION 'PROFILE_MUSIC_TOO_LONG'; END IF;
  IF v_music IS NOT NULL AND (p_profile_music_size_bytes IS NULL OR p_profile_music_size_bytes<1 OR p_profile_music_size_bytes>5242880) THEN RAISE EXCEPTION 'PROFILE_MUSIC_TOO_LARGE'; END IF;
  UPDATE public.profiles SET
    display_name=CASE WHEN p_display_name IS NULL OR length(trim(p_display_name)) NOT BETWEEN 1 AND 120 THEN display_name ELSE trim(p_display_name) END,
    avatar_url=CASE WHEN p_avatar_url IS NULL THEN avatar_url ELSE p_avatar_url END,
    cover_url=CASE WHEN p_cover_url IS NULL THEN cover_url ELSE p_cover_url END,
    status_text=CASE WHEN p_status_text IS NULL THEN status_text ELSE nullif(trim(p_status_text),'') END,
    bio=CASE WHEN p_bio IS NULL THEN bio ELSE left(p_bio,4000) END,
    profile_music_url=CASE WHEN p_profile_music_url IS NULL THEN profile_music_url ELSE v_music END,
    profile_music_duration_ms=CASE WHEN p_profile_music_url IS NULL THEN profile_music_duration_ms WHEN v_music IS NULL THEN NULL ELSE p_profile_music_duration_ms END,
    profile_music_size_bytes=CASE WHEN p_profile_music_url IS NULL THEN profile_music_size_bytes WHEN v_music IS NULL THEN NULL ELSE round(p_profile_music_size_bytes)::bigint END,
    country=CASE WHEN p_country IS NULL THEN country ELSE nullif(trim(p_country),'') END,
    city=CASE WHEN p_city IS NULL THEN city ELSE nullif(trim(p_city),'') END,
    profession=CASE WHEN p_profession IS NULL THEN profession ELSE nullif(trim(p_profession),'') END,
    address=CASE WHEN p_address IS NULL THEN address ELSE left(nullif(trim(p_address),''),500) END,
    experiences=coalesce(p_experiences,experiences),social_links=coalesce(p_social_links,social_links),
    visibility=coalesce(p_visibility,visibility),account_type=coalesce(p_account_type,account_type),
    username_color=CASE WHEN p_username_color IS NULL THEN username_color ELSE round(p_username_color)::bigint END,
    status_bold=coalesce(p_status_bold,status_bold),status_italic=coalesce(p_status_italic,status_italic),
    status_color=CASE WHEN p_status_color IS NULL THEN status_color ELSE round(p_status_color)::bigint END,
    animated_avatar_url=CASE WHEN p_animated_avatar_url IS NULL THEN animated_avatar_url ELSE nullif(trim(p_animated_avatar_url),'') END,
    username_font_size=coalesce(p_username_font_size,username_font_size),status_font_size=coalesce(p_status_font_size,status_font_size),
    updated_at=now()
  WHERE id=v_uid;
END;
$function$;

DROP FUNCTION IF EXISTS public.sync_my_public_profile(text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,numeric,boolean,boolean,numeric,text,integer,numeric,double precision,double precision);
CREATE FUNCTION public.sync_my_public_profile(
  p_display_name text DEFAULT NULL,p_avatar_url text DEFAULT NULL,p_status_text text DEFAULT NULL,p_bio text DEFAULT NULL,
  p_cover_url text DEFAULT NULL,p_profile_music_url text DEFAULT NULL,p_country text DEFAULT NULL,p_city text DEFAULT NULL,
  p_profession text DEFAULT NULL,p_experiences jsonb DEFAULT NULL,p_social_links jsonb DEFAULT NULL,p_visibility text DEFAULT NULL,
  p_account_type text DEFAULT NULL,p_username_color numeric DEFAULT NULL,p_status_bold boolean DEFAULT NULL,p_status_italic boolean DEFAULT NULL,
  p_status_color numeric DEFAULT NULL,p_animated_avatar_url text DEFAULT NULL,p_profile_music_duration_ms integer DEFAULT NULL,
  p_profile_music_size_bytes numeric DEFAULT NULL,p_username_font_size double precision DEFAULT NULL,p_status_font_size double precision DEFAULT NULL,
  p_address text DEFAULT NULL
)
RETURNS void LANGUAGE sql SET search_path TO 'public','private_rpc'
AS $function$ SELECT private_rpc.sync_my_public_profile($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23); $function$;

DROP FUNCTION IF EXISTS public.get_public_profile_cosmetics(uuid);
DROP FUNCTION IF EXISTS private_rpc.get_public_profile_cosmetics(uuid);

CREATE FUNCTION private_rpc.get_public_profile_cosmetics(p_user_id uuid)
RETURNS TABLE(
 id uuid,username text,display_name text,email text,bio text,avatar_url text,cover_url text,status_text text,profile_music_url text,
 profile_music_duration_ms integer,profile_music_size_bytes bigint,country text,city text,profession text,address text,experiences jsonb,
 social_links jsonb,verified boolean,visibility text,account_type text,username_color bigint,username_font_size double precision,
 status_font_size double precision,status_bold boolean,status_italic boolean,status_color bigint,animated_avatar_url text,
 chat_badge_url text,avatar_frame_key text,username_effect text,username_background_key text,username_background_mode text,
 username_background_color1 text,username_background_color2 text,username_background_opacity double precision,
 username_background_external_effect text,role_code text,created_at timestamp with time zone,updated_at timestamp with time zone,
 username_template_key text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT p.id,p.username,p.display_name,
    CASE WHEN auth.uid()=p.id OR public.has_absolute_view(auth.uid()) THEN coalesce(au.email,p.email,'') ELSE '' END,
    p.bio,p.avatar_url,p.cover_url,p.status_text,p.profile_music_url,p.profile_music_duration_ms,p.profile_music_size_bytes,
    p.country,p.city,p.profession,
    CASE WHEN auth.uid()=p.id OR public.has_absolute_view(auth.uid()) OR private.has_permission('users.read') THEN p.address ELSE null END,
    coalesce(p.experiences,'[]'::jsonb),coalesce(p.social_links,'[]'::jsonb),coalesce(p.verified,false),
    coalesce(p.visibility,'public'),coalesce(p.account_type,'individual'),p.username_color,p.username_font_size,p.status_font_size,
    coalesce(p.status_bold,false),coalesce(p.status_italic,false),p.status_color,p.animated_avatar_url,p.chat_badge_url,p.avatar_frame_key,
    coalesce(gs.username_effect,'none'),p.username_background_key,p.username_background_mode,p.username_background_color1,p.username_background_color2,
    coalesce(p.username_background_opacity,.82),p.username_background_external_effect,
    coalesce((SELECT r.code FROM public.user_roles ur JOIN public.roles r ON r.id=ur.role_id WHERE ur.user_id=p.id ORDER BY r.priority DESC,r.code ASC LIMIT 1),'user'),
    p.created_at,p.updated_at,p.username_template_key
  FROM public.profiles p
  LEFT JOIN public.gamification_stats gs ON gs.user_id=p.id
  LEFT JOIN auth.users au ON au.id=p.id
  WHERE p.id=p_user_id AND p.is_active=true AND p.is_suspended=false
    AND (p.id=auth.uid() OR private.has_permission('users.read') OR public.is_platform_owner(auth.uid()) OR
      (coalesce(p.visibility,'public')='public' AND NOT public.has_profile_service_for_user(p.id,'hide_profile')));
$function$;

CREATE FUNCTION public.get_public_profile_cosmetics(p_user_id uuid)
RETURNS TABLE(
 id uuid,username text,display_name text,email text,bio text,avatar_url text,cover_url text,status_text text,profile_music_url text,
 profile_music_duration_ms integer,profile_music_size_bytes bigint,country text,city text,profession text,address text,experiences jsonb,
 social_links jsonb,verified boolean,visibility text,account_type text,username_color bigint,username_font_size double precision,
 status_font_size double precision,status_bold boolean,status_italic boolean,status_color bigint,animated_avatar_url text,
 chat_badge_url text,avatar_frame_key text,username_effect text,username_background_key text,username_background_mode text,
 username_background_color1 text,username_background_color2 text,username_background_opacity double precision,
 username_background_external_effect text,role_code text,created_at timestamp with time zone,updated_at timestamp with time zone,
 username_template_key text
)
LANGUAGE sql STABLE SET search_path TO 'public','private_rpc'
AS $function$ SELECT * FROM private_rpc.get_public_profile_cosmetics($1); $function$;

CREATE OR REPLACE FUNCTION private_rpc.admin_get_user_details(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE r record; v_title text; v_effect text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT (public.is_my_platform_owner() OR private.has_permission('users.read')) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  SELECT p.* INTO r FROM public.profiles p WHERE p.id=p_user_id LIMIT 1;
  IF NOT FOUND THEN RETURN '{}'::jsonb; END IF;
  SELECT c.name_ar INTO v_title FROM public.user_titles ut JOIN public.user_title_catalog c ON c.title_key=ut.title_key WHERE ut.user_id=r.id AND ut.is_active=true AND c.is_active=true LIMIT 1;
  SELECT gs.username_effect INTO v_effect FROM public.gamification_stats gs WHERE gs.user_id=r.id;
  RETURN jsonb_build_object(
    'id',r.id::text,'uid',r.id::text,'username',r.username,'display_name',r.display_name,'email',r.email,'avatar_url',r.avatar_url,
    'country',r.country,'city',r.city,'address',r.address,'latitude',r.location_latitude,'longitude',r.location_longitude,
    'location_updated_at',r.location_updated_at,'last_ip',r.last_ip::text,'last_ip_at',r.last_ip_at,'username_font_size',r.username_font_size,
    'username_color',r.username_color,'username_effect',coalesce(v_effect,'none'),'username_background_mode',r.username_background_mode,
    'username_background_color1',r.username_background_color1,'username_background_color2',r.username_background_color2,
    'username_background_opacity',r.username_background_opacity,'username_background_external_effect',r.username_background_external_effect,
    'username_template_key',r.username_template_key,'verified',r.verified,'title',coalesce(v_title,''),'is_active',r.is_active,'is_suspended',r.is_suspended
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_user_details(p_user_id uuid)
RETURNS jsonb LANGUAGE sql SET search_path TO 'public','private_rpc'
AS $function$ SELECT private_rpc.admin_get_user_details($1); $function$;
