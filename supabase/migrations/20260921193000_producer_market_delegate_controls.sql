begin;

drop policy if exists producer_reels_authenticated_read on public.producer_reels;
create policy producer_reels_authenticated_read
on public.producer_reels for select to authenticated
using (
  ((is_published = true) and (is_blocked = false))
  or owner_uid = (select auth.uid())
  or (select private.has_platform_service_access((select auth.uid()), 'producer_market'))
);

create or replace function private_rpc.update_reel_membership_quota(
  p_tier_id text,p_reels_per_month integer,p_max_duration_seconds integer,
  p_publish_cost_points bigint,p_publish_cost_gems bigint,p_can_pin boolean,
  p_allow_download boolean,p_is_enabled boolean
)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null or not private.has_platform_service_access(v_uid,'producer_market') then
    raise exception 'FORBIDDEN';
  end if;
  if p_reels_per_month<0 or p_max_duration_seconds not between 1 and 1800 or p_publish_cost_points<0 or p_publish_cost_gems<0 then
    raise exception 'INVALID_QUOTA_VALUES';
  end if;
  update public.reel_membership_quotas
  set reels_per_month=p_reels_per_month,max_duration_seconds=p_max_duration_seconds,
      publish_cost_points=p_publish_cost_points,publish_cost_gems=p_publish_cost_gems,
      can_pin=coalesce(p_can_pin,false),allow_download=coalesce(p_allow_download,false),
      is_enabled=coalesce(p_is_enabled,true),updated_by=v_uid,updated_at=now()
  where tier_id=p_tier_id;
  if not found then raise exception 'TIER_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true,'tier_id',p_tier_id);
end;
$function$;

create or replace function private_rpc.admin_update_producer_reel_control(
  p_reel_id uuid,p_title text,p_description text,p_video_url text,p_duration_seconds integer,
  p_thumbnail_url text,p_sector_key text,p_price_minor_units bigint,p_city text,
  p_tags text[],p_allow_download boolean,p_is_published boolean,p_is_blocked boolean,
  p_is_pinned boolean,p_is_featured boolean,p_promotion_score integer
)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid(); v_row public.producer_reels%rowtype;
begin
  if v_uid is null or not private.has_platform_service_access(v_uid,'producer_market') then raise exception 'FORBIDDEN'; end if;
  if p_reel_id is null then raise exception 'REEL_REQUIRED'; end if;
  if nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'TITLE_REQUIRED'; end if;
  if p_duration_seconds is null or p_duration_seconds<=0 then raise exception 'INVALID_DURATION'; end if;
  if p_promotion_score is null or p_promotion_score not between 0 and 100 then raise exception 'INVALID_PROMOTION_SCORE'; end if;
  if p_sector_key is not null and not exists(select 1 from public.garment_sectors s where s.sector_key=trim(p_sector_key) and s.is_active=true) then raise exception 'INVALID_SECTOR'; end if;
  update public.producer_reels
  set title=trim(p_title),description=nullif(trim(coalesce(p_description,'')),''),
      video_url=trim(coalesce(p_video_url,video_url)),duration_seconds=p_duration_seconds,
      thumbnail_url=nullif(trim(coalesce(p_thumbnail_url,'')),''),
      sector_key=nullif(trim(coalesce(p_sector_key,'')),''),
      price_minor_units=p_price_minor_units,city=nullif(trim(coalesce(p_city,'')),''),
      tags=coalesce(p_tags,tags),allow_download=coalesce(p_allow_download,allow_download),
      is_published=coalesce(p_is_published,is_published),is_blocked=coalesce(p_is_blocked,is_blocked),
      is_pinned=coalesce(p_is_pinned,is_pinned),is_featured=coalesce(p_is_featured,is_featured),
      promotion_score=p_promotion_score,updated_at=now()
  where id=p_reel_id returning * into v_row;
  if not found then raise exception 'REEL_NOT_FOUND'; end if;
  perform public.write_audit('owner_reel_control_update',p_reel_id::text,gen_random_uuid(),'succeeded',
    jsonb_build_object('is_published',v_row.is_published,'is_blocked',v_row.is_blocked,'is_pinned',v_row.is_pinned,'is_featured',v_row.is_featured,'promotion_score',v_row.promotion_score));
  return jsonb_build_object('ok',true,'reel_id',v_row.id,'promotion_score',v_row.promotion_score);
end;
$function$;

create or replace function private_rpc.set_producer_reel_blocked(p_reel_id uuid,p_blocked boolean)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null or not private.has_platform_service_access(v_uid,'producer_market') then raise exception 'FORBIDDEN'; end if;
  update public.producer_reels set is_blocked=coalesce(p_blocked,false),updated_at=now() where id=p_reel_id;
  if not found then raise exception 'REEL_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true,'blocked',coalesce(p_blocked,false));
end;
$function$;

create or replace function private_rpc.set_producer_reel_pinned(p_reel_id uuid,p_pinned boolean)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid(); v_owner uuid; q jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select owner_uid into v_owner from public.producer_reels where id=p_reel_id for update;
  if v_owner is null then raise exception 'REEL_NOT_FOUND'; end if;
  if not private.has_platform_service_access(v_uid,'producer_market') then
    if v_owner<>v_uid then raise exception 'FORBIDDEN'; end if;
    q:=public.get_my_reel_quota();
    if p_pinned and not coalesce((q->>'can_pin')::boolean,false) then raise exception 'PIN_NOT_ALLOWED'; end if;
  end if;
  update public.producer_reels set is_pinned=coalesce(p_pinned,false),updated_at=now() where id=p_reel_id;
  return jsonb_build_object('ok',true,'pinned',coalesce(p_pinned,false));
end;
$function$;

create or replace function private_rpc.set_producer_reel_published(p_reel_id uuid,p_is_published boolean)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid(); v_owner uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select owner_uid into v_owner from public.producer_reels where id=p_reel_id for update;
  if v_owner is null then raise exception 'REEL_NOT_FOUND'; end if;
  if v_owner<>v_uid and not private.has_platform_service_access(v_uid,'producer_market') then raise exception 'FORBIDDEN'; end if;
  update public.producer_reels set is_published=coalesce(p_is_published,is_published),updated_at=now() where id=p_reel_id;
  perform public.write_audit('producer_reel_publish_state',p_reel_id::text,gen_random_uuid(),'succeeded',
    jsonb_build_object('is_published',coalesce(p_is_published,false),'actor_uid',v_uid));
  return jsonb_build_object('ok',true,'id',p_reel_id,'is_published',coalesce(p_is_published,false));
end;
$function$;

create or replace function private_rpc.delete_producer_reel(p_reel_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid(); v_owner uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select owner_uid into v_owner from public.producer_reels where id=p_reel_id;
  if v_owner is null then raise exception 'REEL_NOT_FOUND'; end if;
  if v_owner<>v_uid and not private.has_platform_service_access(v_uid,'producer_market') then raise exception 'FORBIDDEN'; end if;
  delete from public.producer_reels where id=p_reel_id;
  perform public.write_audit('producer_reel_delete',p_reel_id::text,gen_random_uuid(),'succeeded',jsonb_build_object('actor_uid',v_uid));
  return jsonb_build_object('ok',true,'id',p_reel_id);
end;
$function$;

create or replace function private_rpc.set_producers_market_season(
  p_title text default null,p_show_date boolean default null,p_date_text text default null,
  p_title_effect text default null,p_title_color1 text default null,p_title_color2 text default null,
  p_title_font_family text default null,p_title_font_size double precision default null,
  p_overlay_gif_url text default null,p_overlay_opacity double precision default null,
  p_overlay_height double precision default null,p_background_url text default null,
  p_background_color1 text default null,p_background_color2 text default null,p_is_active boolean default null
)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid(); v_url text;
begin
  if v_uid is null or not private.has_platform_service_access(v_uid,'producer_market') then raise exception 'FORBIDDEN'; end if;
  if p_title_font_size is not null and (p_title_font_size<12 or p_title_font_size>60) then raise exception 'INVALID_TITLE_FONT_SIZE'; end if;
  if p_overlay_opacity is not null and (p_overlay_opacity<0 or p_overlay_opacity>1) then raise exception 'INVALID_OVERLAY_OPACITY'; end if;
  if p_overlay_height is not null and (p_overlay_height<40 or p_overlay_height>600) then raise exception 'INVALID_OVERLAY_HEIGHT'; end if;
  if p_overlay_gif_url is not null and p_overlay_gif_url<>'' then
    if p_overlay_gif_url not like 'storage://producer-market-media/season/%' then raise exception 'INVALID_SEASON_OVERLAY_PATH'; end if;
    v_url:=substr(p_overlay_gif_url,length('storage://producer-market-media/')+1);
    if not exists(select 1 from storage.objects where bucket_id='producer-market-media' and name=v_url) then raise exception 'SEASON_OVERLAY_NOT_FOUND'; end if;
  end if;
  if p_background_url is not null and p_background_url<>'' then
    if p_background_url not like 'storage://producer-market-media/season/%' then raise exception 'INVALID_SEASON_BACKGROUND_PATH'; end if;
    v_url:=substr(p_background_url,length('storage://producer-market-media/')+1);
    if not exists(select 1 from storage.objects where bucket_id='producer-market-media' and name=v_url) then raise exception 'SEASON_BACKGROUND_NOT_FOUND'; end if;
  end if;
  update public.producers_market_season set
    title=coalesce(p_title,title),show_date=coalesce(p_show_date,show_date),date_text=coalesce(p_date_text,date_text),
    title_effect=coalesce(p_title_effect,title_effect),title_color1=coalesce(p_title_color1,title_color1),title_color2=coalesce(p_title_color2,title_color2),
    title_font_family=coalesce(p_title_font_family,title_font_family),title_font_size=coalesce(p_title_font_size,title_font_size),
    overlay_gif_url=coalesce(p_overlay_gif_url,overlay_gif_url),overlay_opacity=coalesce(p_overlay_opacity,overlay_opacity),
    overlay_height=coalesce(p_overlay_height,overlay_height),background_url=coalesce(p_background_url,background_url),
    background_color1=coalesce(p_background_color1,background_color1),background_color2=coalesce(p_background_color2,background_color2),
    is_active=coalesce(p_is_active,is_active),updated_by=v_uid,updated_at=now() where id=true;
  return jsonb_build_object('ok',true);
end;
$function$;

commit;
