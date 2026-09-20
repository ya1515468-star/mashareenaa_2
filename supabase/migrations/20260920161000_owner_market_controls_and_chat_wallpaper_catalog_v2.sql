begin;

alter table public.producer_reels
  add column if not exists promotion_score integer not null default 0,
  add column if not exists is_featured boolean not null default false;

alter table public.producer_reels
  drop constraint if exists producer_reels_promotion_score_check;
alter table public.producer_reels
  add constraint producer_reels_promotion_score_check check (promotion_score between 0 and 100);

create index if not exists idx_producer_reels_feed_rank
  on public.producer_reels(is_published,is_blocked,is_pinned,is_featured,promotion_score desc,created_at desc);

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
  if p_duration_seconds is null or p_duration_seconds <= 0 then raise exception 'INVALID_DURATION'; end if;
  if p_promotion_score is null or p_promotion_score not between 0 and 100 then raise exception 'INVALID_PROMOTION_SCORE'; end if;
  if p_sector_key is not null and not exists(select 1 from public.garment_sectors s where s.sector_key=trim(p_sector_key) and s.is_active=true) then raise exception 'INVALID_SECTOR'; end if;
  update public.producer_reels set title=trim(p_title),description=nullif(trim(coalesce(p_description,'')),''),video_url=trim(coalesce(p_video_url,video_url)),duration_seconds=p_duration_seconds,thumbnail_url=nullif(trim(coalesce(p_thumbnail_url,'')),''),sector_key=nullif(trim(coalesce(p_sector_key,'')),''),price_minor_units=p_price_minor_units,city=nullif(trim(coalesce(p_city,'')),''),tags=coalesce(p_tags,tags),allow_download=coalesce(p_allow_download,allow_download),is_published=coalesce(p_is_published,is_published),is_blocked=coalesce(p_is_blocked,is_blocked),is_pinned=coalesce(p_is_pinned,is_pinned),is_featured=coalesce(p_is_featured,is_featured),promotion_score=p_promotion_score,updated_at=now() where id=p_reel_id returning * into v_row;
  if not found then raise exception 'REEL_NOT_FOUND'; end if;
  perform public.write_audit('owner_reel_control_update',p_reel_id::text,gen_random_uuid(),'succeeded',jsonb_build_object('is_published',v_row.is_published,'is_blocked',v_row.is_blocked,'is_pinned',v_row.is_pinned,'is_featured',v_row.is_featured,'promotion_score',v_row.promotion_score));
  return jsonb_build_object('ok',true,'reel_id',v_row.id,'promotion_score',v_row.promotion_score);
end;$fn$;

create or replace function public.admin_update_producer_reel_control(
  p_reel_id uuid,p_title text,p_description text,p_video_url text,p_duration_seconds integer,
  p_thumbnail_url text,p_sector_key text,p_price_minor_units bigint,p_city text,p_tags text[],
  p_allow_download boolean,p_is_published boolean,p_is_blocked boolean,p_is_pinned boolean,
  p_is_featured boolean,p_promotion_score integer
) returns jsonb language sql security invoker set search_path=public,private_rpc as $fn$
select private_rpc.admin_update_producer_reel_control($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16);$fn$;
revoke all on function public.admin_update_producer_reel_control(uuid,text,text,text,integer,text,text,bigint,text,text[],boolean,boolean,boolean,boolean,boolean,integer) from public,anon;
grant execute on function public.admin_update_producer_reel_control(uuid,text,text,text,integer,text,text,bigint,text,text[],boolean,boolean,boolean,boolean,boolean,integer) to authenticated;

create or replace function public.get_producer_reels_feed(p_limit integer default 100)
returns setof public.producer_reels language sql stable security invoker set search_path=public as $fn$
select * from public.producer_reels where is_published=true and is_blocked=false order by is_pinned desc,is_featured desc,promotion_score desc,created_at desc limit greatest(1,least(coalesce(p_limit,100),100));$fn$;
revoke all on function public.get_producer_reels_feed(integer) from public,anon;
grant execute on function public.get_producer_reels_feed(integer) to authenticated;

create or replace function private_rpc.admin_upsert_chat_wallpaper(
  p_wallpaper_key text,p_name_ar text,p_scope text,p_kind text,p_color1 text,p_color2 text,p_image_url text,p_is_premium boolean,p_price_points bigint,p_is_active boolean,p_sort_order integer
) returns jsonb language plpgsql security definer set search_path=public as $fn$
declare v_uid uuid:=auth.uid(); v_key text:=trim(coalesce(p_wallpaper_key,''));
begin
  if v_uid is null or not public._is_platform_owner(v_uid) then raise exception 'FORBIDDEN'; end if;
  if v_key='' then raise exception 'WALLPAPER_KEY_REQUIRED'; end if;
  if p_scope not in ('both','room','private') then raise exception 'INVALID_SCOPE'; end if;
  if p_kind not in ('solid','gradient','image') then raise exception 'INVALID_KIND'; end if;
  if p_price_points is null or p_price_points<0 then raise exception 'INVALID_PRICE'; end if;
  insert into public.chat_wallpaper_catalog(wallpaper_key,name_ar,scope,kind,color1,color2,image_url,is_premium,price_points,is_active,sort_order,updated_by,updated_at)
  values(v_key,left(trim(p_name_ar),120),p_scope,p_kind,nullif(trim(coalesce(p_color1,'')),''),nullif(trim(coalesce(p_color2,'')),''),nullif(trim(coalesce(p_image_url,'')),''),coalesce(p_is_premium,false),p_price_points,coalesce(p_is_active,true),greatest(0,coalesce(p_sort_order,0)),v_uid,now())
  on conflict(wallpaper_key) do update set name_ar=excluded.name_ar,scope=excluded.scope,kind=excluded.kind,color1=excluded.color1,color2=excluded.color2,image_url=excluded.image_url,is_premium=excluded.is_premium,price_points=excluded.price_points,is_active=excluded.is_active,sort_order=excluded.sort_order,updated_by=v_uid,updated_at=now();
  return jsonb_build_object('ok',true,'wallpaper_key',v_key);
end;$fn$;

create or replace function public.admin_upsert_chat_wallpaper(p_wallpaper_key text,p_name_ar text,p_scope text,p_kind text,p_color1 text,p_color2 text,p_image_url text,p_is_premium boolean,p_price_points bigint,p_is_active boolean,p_sort_order integer)
returns jsonb language sql security invoker set search_path=public,private_rpc as $fn$
select private_rpc.admin_upsert_chat_wallpaper($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11);$fn$;
revoke all on function public.admin_upsert_chat_wallpaper(text,text,text,text,text,text,text,boolean,bigint,boolean,integer) from public,anon;
grant execute on function public.admin_upsert_chat_wallpaper(text,text,text,text,text,text,text,boolean,bigint,boolean,integer) to authenticated;

create or replace function private_rpc.admin_delete_chat_wallpaper(p_wallpaper_key text)
returns jsonb language plpgsql security definer set search_path=public as $fn$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null or not public._is_platform_owner(v_uid) then raise exception 'FORBIDDEN'; end if;
  update public.chat_wallpaper_catalog set is_active=false,updated_by=v_uid,updated_at=now() where wallpaper_key=trim(p_wallpaper_key);
  if not found then raise exception 'WALLPAPER_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true,'wallpaper_key',trim(p_wallpaper_key));
end;$fn$;

create or replace function public.admin_delete_chat_wallpaper(p_wallpaper_key text)
returns jsonb language sql security invoker set search_path=public,private_rpc as $fn$ select private_rpc.admin_delete_chat_wallpaper($1);$fn$;
revoke all on function public.admin_delete_chat_wallpaper(text) from public,anon;
grant execute on function public.admin_delete_chat_wallpaper(text) to authenticated;

insert into public.chat_wallpaper_catalog(wallpaper_key,name_ar,scope,kind,color1,color2,is_premium,price_points,is_active,sort_order,updated_at) values
('wp_obsidian','أوبسيديان فاخر','both','gradient','#05070D','#1A2130',false,0,true,130,now()),
('wp_sapphire','ياقوت أزرق','both','gradient','#071A3A','#2563EB',false,0,true,140,now()),
('wp_amethyst','أميثست','both','gradient','#1E103D','#9333EA',false,0,true,150,now()),
('wp_coral','مرجان','both','gradient','#43111A','#FB7185',false,0,true,160,now()),
('wp_teal','فيروزي','both','gradient','#062C35','#14B8A6',false,0,true,170,now()),
('wp_forest','غابة ليلية','both','gradient','#071A12','#166534',false,0,true,180,now()),
('wp_cappuccino','قهوة وحرير','both','gradient','#24140A','#9A6B3A',true,3000,true,190,now()),
('wp_ice','جليد','both','gradient','#0B2032','#67E8F9',true,3500,true,200,now()),
('wp_lilac','ليلك ناعم','both','gradient','#241436','#C084FC',true,3500,true,210,now()),
('wp_champagne','شمبانيا','both','gradient','#30220D','#F5D58A',true,4500,true,220,now()),
('wp_mono','أبيض وأسود','both','gradient','#111111','#444444',false,0,true,230,now()),
('wp_plasma','بلازما','both','gradient','#1A0635','#7E22CE',true,6500,true,240,now())
on conflict(wallpaper_key) do update set name_ar=excluded.name_ar,color1=excluded.color1,color2=excluded.color2,is_premium=excluded.is_premium,price_points=excluded.price_points,is_active=true,sort_order=excluded.sort_order,updated_at=now();

commit;
