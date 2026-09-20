-- Final server-side guard for reel publication.
-- Prevents the invalid legacy sector value `garment` from reaching the FK,
-- and validates the uploaded Storage objects before the row is inserted.

create or replace function public.publish_producer_reel(
  p_title text,
  p_video_url text,
  p_duration_seconds integer,
  p_description text default null,
  p_thumbnail_url text default null,
  p_business_id uuid default null,
  p_product_id uuid default null,
  p_sector_key text default null,
  p_price_minor_units bigint default null,
  p_city text default null,
  p_tags text[] default '{}',
  p_allow_download boolean default true,
  p_request_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  q jsonb;
  v_id uuid;
  v_period date := date_trunc('month', now())::date;
  v_pts bigint := 0;
  v_gems bigint := 0;
  v_pb bigint := 0;
  v_gb bigint := 0;
  v_existing jsonb;
  v_path text;
  v_sector text := nullif(trim(coalesce(p_sector_key, '')), '');
  v_video_mime text;
  v_cover_mime text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if nullif(trim(coalesce(p_title, '')), '') is null then raise exception 'TITLE_REQUIRED'; end if;
  if nullif(trim(coalesce(p_video_url, '')), '') is null then raise exception 'VIDEO_REQUIRED'; end if;
  if v_sector is null then raise exception 'SECTOR_REQUIRED'; end if;
  if not exists (
    select 1 from public.garment_sectors s
    where s.sector_key = v_sector and s.is_active = true
  ) then
    raise exception 'INVALID_SECTOR';
  end if;

  select metadata->'result' into v_existing
  from public.wallet_transactions
  where idempotency_key = p_request_id and reference_type = 'reel'
  limit 1;
  if v_existing is not null then return v_existing; end if;

  q := public.get_my_reel_quota();
  if coalesce((q->>'unlimited')::boolean, false) then
    if coalesce(p_duration_seconds, 0) < 1 or p_duration_seconds > 600 then raise exception 'INVALID_DURATION'; end if;
  else
    if coalesce((q->>'remaining')::int, 0) <= 0 then raise exception 'REEL_QUOTA_EXCEEDED'; end if;
    if coalesce(p_duration_seconds, 0) < 1 or p_duration_seconds > (q->>'max_duration_seconds')::int then raise exception 'DURATION_EXCEEDED'; end if;
    v_pts := (q->>'publish_cost_points')::bigint;
    v_gems := (q->>'publish_cost_gems')::bigint;
    if v_pts > 0 then
      select balance into v_pb from public.points_wallets where user_id = v_uid for update;
      if coalesce(v_pb, 0) < v_pts then raise exception 'INSUFFICIENT_POINTS'; end if;
      update public.points_wallets
      set balance = balance - v_pts,
          lifetime_spent = lifetime_spent + v_pts,
          version = version + 1,
          updated_at = now()
      where user_id = v_uid;
    end if;
    if v_gems > 0 then
      select balance into v_gb from public.gems_wallets where user_id = v_uid for update;
      if coalesce(v_gb, 0) < v_gems then raise exception 'INSUFFICIENT_GEMS'; end if;
      update public.gems_wallets
      set balance = balance - v_gems,
          lifetime_spent = lifetime_spent + v_gems,
          version = version + 1,
          updated_at = now()
      where user_id = v_uid;
    end if;
  end if;

  if left(p_video_url, 10) = 'storage://' then
    if p_video_url not like 'storage://producer-market-media/reels/' || v_uid::text || '/%' then
      raise exception 'INVALID_VIDEO_PATH';
    end if;
    v_path := substr(p_video_url, length('storage://producer-market-media/') + 1);
    select (metadata->>'mimetype')::text into v_video_mime
    from storage.objects
    where bucket_id = 'producer-market-media' and name = v_path
    limit 1;
    if v_video_mime is null then raise exception 'VIDEO_OBJECT_NOT_FOUND'; end if;
    if v_video_mime not in ('video/mp4','video/webm','video/quicktime') then raise exception 'INVALID_VIDEO_MIME'; end if;
  end if;

  if left(coalesce(p_thumbnail_url, ''), 10) = 'storage://' then
    if p_thumbnail_url not like 'storage://producer-market-media/reels/' || v_uid::text || '/%' then
      raise exception 'INVALID_THUMBNAIL_PATH';
    end if;
    v_path := substr(p_thumbnail_url, length('storage://producer-market-media/') + 1);
    select (metadata->>'mimetype')::text into v_cover_mime
    from storage.objects
    where bucket_id = 'producer-market-media' and name = v_path
    limit 1;
    if v_cover_mime is null then raise exception 'THUMBNAIL_OBJECT_NOT_FOUND'; end if;
    if v_cover_mime not in ('image/png','image/jpeg','image/webp','image/gif') then raise exception 'INVALID_THUMBNAIL_MIME'; end if;
  end if;

  insert into public.producer_reels(
    owner_uid,business_id,product_id,sector_key,title,description,video_url,thumbnail_url,
    duration_seconds,price_minor_units,city,tags,allow_download
  )
  values(
    v_uid,p_business_id,p_product_id,v_sector,trim(p_title),p_description,trim(p_video_url),
    nullif(trim(coalesce(p_thumbnail_url, '')),''),p_duration_seconds,p_price_minor_units,
    p_city,coalesce(p_tags,'{}'),coalesce(p_allow_download,true)
  )
  returning id into v_id;

  insert into public.reel_quota_usage(user_id,period_start,reels_published)
  values(v_uid,v_period,1)
  on conflict(user_id,period_start) do update
    set reels_published = public.reel_quota_usage.reels_published + 1,
        updated_at = now();

  v_existing := jsonb_build_object('ok',true,'id',v_id,'charged_points',v_pts,'charged_gems',v_gems);

  if v_pts > 0 then
    insert into public.wallet_transactions(
      user_id,currency,transaction_type,amount,balance_before,balance_after,reference_type,
      reference_id,idempotency_key,metadata,created_by
    )
    values(
      v_uid,'points','reel_publish',-v_pts,v_pb,v_pb-v_pts,'reel',v_id::text,p_request_id,
      jsonb_build_object('result',v_existing),v_uid
    );
  end if;

  if v_gems > 0 then
    insert into public.wallet_transactions(
      user_id,currency,transaction_type,amount,balance_before,balance_after,reference_type,
      reference_id,idempotency_key,metadata,created_by
    )
    values(
      v_uid,'gems','reel_publish',-v_gems,v_gb,v_gb-v_gems,'reel',v_id::text,p_request_id,
      jsonb_build_object('result',v_existing),v_uid
    );
  end if;

  return v_existing;
end;
$function$;

revoke execute on function public.publish_producer_reel(text,text,integer,text,text,uuid,uuid,text,bigint,text,text[],boolean,uuid) from public, anon;
grant execute on function public.publish_producer_reel(text,text,integer,text,text,uuid,uuid,text,bigint,text,text[],boolean,uuid) to authenticated;
