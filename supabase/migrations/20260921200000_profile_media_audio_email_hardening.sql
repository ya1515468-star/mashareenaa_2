-- Production hardening for profile media, voice recording handoff, and email visibility.
-- Auth remains the source of truth for identity email; profiles.email is a synchronized cache.

create or replace function private.sync_auth_user_profile_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set email = nullif(trim(new.email), ''),
      updated_at = case
        when email is distinct from nullif(trim(new.email), '')
          then now()
        else updated_at
      end
  where id = new.id;

  return new;
end;
$$;

revoke all on function private.sync_auth_user_profile_email() from public, anon, authenticated;

drop trigger if exists trg_sync_auth_user_profile_email on auth.users;
create trigger trg_sync_auth_user_profile_email
after insert or update of email, email_confirmed_at on auth.users
for each row execute function private.sync_auth_user_profile_email();

update public.profiles p
set email = nullif(trim(au.email), ''),
    updated_at = case
      when p.email is distinct from nullif(trim(au.email), '') then now()
      else p.updated_at
    end
from auth.users au
where au.id = p.id
  and p.email is distinct from nullif(trim(au.email), '');

create or replace function private_rpc.ensure_my_profile(
  p_display_name text default null,
  p_email text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
  v_auth_email text;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select u.email
  into v_auth_email
  from auth.users u
  where u.id = v_uid;

  insert into public.profiles (
    id,
    display_name,
    email,
    is_active,
    is_suspended,
    bio,
    experiences,
    social_links,
    verified,
    visibility,
    account_type,
    status_bold,
    status_italic,
    username_font_size,
    status_font_size,
    username_background_opacity,
    created_at,
    updated_at
  )
  values (
    v_uid,
    nullif(left(trim(coalesce(p_display_name,'')),120),''),
    nullif(trim(coalesce(v_auth_email, p_email, '')),''),
    true,
    false,
    '',
    '[]'::jsonb,
    '[]'::jsonb,
    false,
    'public',
    'individual',
    false,
    false,
    22,
    12.5,
    0.82,
    now(),
    now()
  )
  on conflict (id) do nothing;

  select * into v_profile from public.profiles where id=v_uid;
  if v_profile.id is null then
    raise exception 'PROFILE_CREATE_FAILED';
  end if;

  return v_profile;
end;
$$;

revoke all on function private_rpc.ensure_my_profile(text,text) from public, anon, authenticated;
grant execute on function private_rpc.ensure_my_profile(text,text) to authenticated;

create or replace function private_rpc.get_public_profile_cosmetics(p_user_id uuid)
returns table(
  id uuid,
  username text,
  display_name text,
  email text,
  bio text,
  avatar_url text,
  cover_url text,
  status_text text,
  profile_music_url text,
  profile_music_duration_ms integer,
  profile_music_size_bytes bigint,
  country text,
  city text,
  profession text,
  experiences jsonb,
  social_links jsonb,
  verified boolean,
  visibility text,
  account_type text,
  username_color bigint,
  username_font_size double precision,
  status_font_size double precision,
  status_bold boolean,
  status_italic boolean,
  status_color bigint,
  animated_avatar_url text,
  chat_badge_url text,
  avatar_frame_key text,
  username_effect text,
  username_background_key text,
  username_background_mode text,
  username_background_color1 text,
  username_background_color2 text,
  username_background_opacity double precision,
  username_background_external_effect text,
  role_code text,
  created_at timestamptz,
  updated_at timestamptz,
  username_template_key text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.username,
    p.display_name,
    case
      when auth.uid() = p.id
        or public.has_absolute_view(auth.uid())
      then coalesce(au.email, p.email, '')
      else ''
    end,
    p.bio,
    p.avatar_url,
    p.cover_url,
    p.status_text,
    p.profile_music_url,
    p.profile_music_duration_ms,
    p.profile_music_size_bytes,
    p.country,
    p.city,
    p.profession,
    coalesce(p.experiences,'[]'::jsonb),
    coalesce(p.social_links,'[]'::jsonb),
    coalesce(p.verified,false),
    coalesce(p.visibility,'public'),
    coalesce(p.account_type,'individual'),
    p.username_color,
    p.username_font_size,
    p.status_font_size,
    coalesce(p.status_bold,false),
    coalesce(p.status_italic,false),
    p.status_color,
    p.animated_avatar_url,
    p.chat_badge_url,
    p.avatar_frame_key,
    coalesce(gs.username_effect,'none'),
    p.username_background_key,
    p.username_background_mode,
    p.username_background_color1,
    p.username_background_color2,
    coalesce(p.username_background_opacity,.82),
    p.username_background_external_effect,
    coalesce((
      select r.code
      from public.user_roles ur
      join public.roles r on r.id=ur.role_id
      where ur.user_id=p.id
      order by r.priority desc,r.code asc
      limit 1
    ),'user'),
    p.created_at,
    p.updated_at,
    p.username_template_key
  from public.profiles p
  left join public.gamification_stats gs on gs.user_id=p.id
  left join auth.users au on au.id=p.id
  where p.id=p_user_id
    and p.is_active=true
    and p.is_suspended=false
    and (
      p.id=auth.uid()
      or private.has_permission('users.read')
      or public.is_platform_owner(auth.uid())
      or (
        coalesce(p.visibility,'public')='public'
        and not public.has_profile_service_for_user(p.id,'hide_profile')
      )
    );
$$;

revoke all on function private_rpc.get_public_profile_cosmetics(uuid) from public, anon, authenticated;
grant execute on function private_rpc.get_public_profile_cosmetics(uuid) to anon, authenticated;

create or replace function private_rpc.get_profile_for_viewer(p_target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_viewer uuid := auth.uid();
  v_target public.profiles;
  v_privileged boolean;
  v_is_self boolean;
  v_visibility text;
  v_is_friend boolean := false;
  v_show_extra boolean;
  v_presence record;
  v_points bigint;
  v_gems bigint;
  v_security record;
  v_hidden boolean := false;
  v_effect text;
  v_auth_email text;
  v_result jsonb;
begin
  if v_viewer is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_target_user_id is null then raise exception 'TARGET_REQUIRED'; end if;

  select * into v_target from public.profiles where id = p_target_user_id;
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;

  select u.email
  into v_auth_email
  from auth.users u
  where u.id = p_target_user_id;

  v_is_self := (v_viewer = p_target_user_id);
  v_privileged := (not v_is_self) and public.has_absolute_view(v_viewer);
  v_visibility := coalesce(v_target.visibility, 'public');

  if not v_is_self and not v_privileged then
    select exists(
      select 1 from public.friend_requests
      where status = 'accepted'
        and ((from_uid = v_viewer and to_uid = p_target_user_id)
          or (from_uid = p_target_user_id and to_uid = v_viewer))
    ) into v_is_friend;
  end if;

  v_show_extra := v_is_self
    or v_privileged
    or (v_visibility = 'public')
    or (v_visibility = 'friends' and v_is_friend);

  select is_online, last_seen
  into v_presence
  from public.user_presence
  where user_id = p_target_user_id;

  select gs.username_effect
  into v_effect
  from public.gamification_stats gs
  where gs.user_id = p_target_user_id;

  select coalesce((d.data->>'appearOffline')::boolean,false)
  into v_hidden
  from public.app_documents d
  where d.collection_path='accounts'
    and d.doc_id = p_target_user_id::text;
  v_hidden := coalesce(v_hidden,false);

  v_result := jsonb_build_object(
    'id', v_target.id,
    'username', v_target.username,
    'display_name', v_target.display_name,
    'avatar_url', v_target.avatar_url,
    'animated_avatar_url', v_target.animated_avatar_url,
    'avatar_frame_key', v_target.avatar_frame_key,
    'cover_url', v_target.cover_url,
    'bio', v_target.bio,
    'verified', v_target.verified,
    'account_type', v_target.account_type,
    'profession', v_target.profession,
    'social_links', v_target.social_links,
    'username_color', v_target.username_color,
    'username_font_size', v_target.username_font_size,
    'username_font_family', v_target.username_font_family,
    'username_effect', coalesce(nullif(trim(v_effect),''),'none'),
    'username_template_key', v_target.username_template_key,
    'username_background_key', v_target.username_background_key,
    'username_background_mode', v_target.username_background_mode,
    'username_background_color1', v_target.username_background_color1,
    'username_background_color2', v_target.username_background_color2,
    'username_background_opacity', v_target.username_background_opacity,
    'username_background_external_effect', v_target.username_background_external_effect,
    'visibility', v_visibility,
    'is_friend', v_is_friend,
    'is_self', v_is_self,
    'privileged', v_privileged
  );

  if v_show_extra then
    v_result := v_result || jsonb_build_object(
      'country', v_target.country,
      'city', v_target.city,
      'is_online', case when v_hidden and not v_is_self and not v_privileged
                        then false else coalesce(v_presence.is_online,false) end,
      'last_seen', case when v_hidden and not v_is_self and not v_privileged
                        then null else v_presence.last_seen end
    );
  end if;

  if v_is_self or v_privileged then
    v_result := v_result || jsonb_build_object(
      'email', coalesce(v_auth_email, v_target.email, ''),
      'email_confirmed', exists(
        select 1 from auth.users au
        where au.id = p_target_user_id
          and au.email_confirmed_at is not null
      )
    );
  end if;

  if v_privileged then
    select balance into v_points from public.points_wallets where user_id = p_target_user_id;
    select balance into v_gems from public.gems_wallets where user_id = p_target_user_id;
    select risk_score, risk_state, last_seen_at
    into v_security
    from public.user_security_identity
    where user_id = p_target_user_id;

    v_result := v_result || jsonb_build_object(
      'is_active', v_target.is_active,
      'is_suspended', v_target.is_suspended,
      'location_latitude', v_target.location_latitude,
      'location_longitude', v_target.location_longitude,
      'location_updated_at', v_target.location_updated_at,
      'last_ip', host(v_target.last_ip),
      'last_ip_at', v_target.last_ip_at,
      'last_seen_at', v_target.last_seen_at,
      'appear_offline_enabled', v_hidden,
      'true_is_online', coalesce(v_presence.is_online,false),
      'points_balance', coalesce(v_points, 0),
      'gems_balance', coalesce(v_gems, 0),
      'security_risk_score', v_security.risk_score,
      'security_risk_state', v_security.risk_state,
      'security_last_seen_at', v_security.last_seen_at,
      'created_at', v_target.created_at
    );

    insert into public.audit_logs(
      actor_user_id, actor_id, action, resource_type, resource_id, target_id,
      result, metadata
    )
    values (
      v_viewer,
      v_viewer,
      'ADMIN_VIEWED_PRIVILEGED_PROFILE',
      'profiles',
      p_target_user_id::text,
      p_target_user_id::text,
      'success',
      jsonb_build_object('viewer_is_owner', coalesce(public.is_my_platform_owner(), false))
    );
  end if;

  return v_result;
end;
$$;

revoke all on function private_rpc.get_profile_for_viewer(uuid) from public, anon, authenticated;
grant execute on function private_rpc.get_profile_for_viewer(uuid) to authenticated;

create or replace function public.get_profile_for_viewer(p_target_user_id uuid)
returns jsonb
language sql
security invoker
set search_path = public, private_rpc
as $$
  select private_rpc.get_profile_for_viewer($1);
$$;

revoke all on function public.get_profile_for_viewer(uuid) from public, anon, authenticated;
grant execute on function public.get_profile_for_viewer(uuid) to authenticated;

update storage.buckets
set file_size_limit = least(coalesce(file_size_limit, 8 * 1024 * 1024), 8 * 1024 * 1024),
    allowed_mime_types = array[
      'image/png','image/jpeg','image/webp','image/gif'
    ]
where id='profile-avatars';
