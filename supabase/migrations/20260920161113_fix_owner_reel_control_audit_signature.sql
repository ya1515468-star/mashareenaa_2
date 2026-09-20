create or replace function private_rpc.admin_update_producer_reel_control(
  p_reel_id uuid,p_title text,p_description text,p_video_url text,p_duration_seconds integer,
  p_thumbnail_url text,p_sector_key text,p_price_minor_units bigint,p_city text,p_tags text[],
  p_allow_download boolean,p_is_published boolean,p_is_blocked boolean,p_is_pinned boolean,
  p_is_featured boolean,p_promotion_score integer
) returns jsonb language plpgsql security definer set search_path=public as $fn$
declare v_uid uuid:=auth.uid(); v_row public.producer_reels%rowtype;
begin
  if v_uid is null or not public._is_platform_owner(v_uid) then raise exception 'FORBIDDEN'; end if;
  if p_reel_id is null then raise exception 'REEL_REQUIRED'; end if;
  if nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'TITLE_REQUIRED'; end if;
  if p_duration_seconds is null or p_duration_seconds<=0 then raise exception 'INVALID_DURATION'; end if;
  if p_promotion_score is null or p_promotion_score not between 0 and 100 then raise exception 'INVALID_PROMOTION_SCORE'; end if;
  if p_sector_key is not null and not exists(select 1 from public.garment_sectors s where s.sector_key=trim(p_sector_key) and s.is_active=true) then raise exception 'INVALID_SECTOR'; end if;
  update public.producer_reels set title=trim(p_title),description=nullif(trim(coalesce(p_description,'')),''),video_url=trim(coalesce(p_video_url,video_url)),duration_seconds=p_duration_seconds,thumbnail_url=nullif(trim(coalesce(p_thumbnail_url,'')),''),sector_key=nullif(trim(coalesce(p_sector_key,'')),''),price_minor_units=p_price_minor_units,city=nullif(trim(coalesce(p_city,'')),''),tags=coalesce(p_tags,tags),allow_download=coalesce(p_allow_download,allow_download),is_published=coalesce(p_is_published,is_published),is_blocked=coalesce(p_is_blocked,is_blocked),is_pinned=coalesce(p_is_pinned,is_pinned),is_featured=coalesce(p_is_featured,is_featured),promotion_score=p_promotion_score,updated_at=now() where id=p_reel_id returning * into v_row;
  if not found then raise exception 'REEL_NOT_FOUND'; end if;
  perform public.write_audit('owner_reel_control_update',p_reel_id::text,gen_random_uuid(),'succeeded',jsonb_build_object('promotion_score',v_row.promotion_score,'is_featured',v_row.is_featured));
  return jsonb_build_object('ok',true,'reel_id',v_row.id,'promotion_score',v_row.promotion_score);
end;$fn$;
