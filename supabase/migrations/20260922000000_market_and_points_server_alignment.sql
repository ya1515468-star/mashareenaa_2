-- 20260922000000_market_and_points_server_alignment.sql

create or replace function private.get_garment_service_catalog()
returns setof public.garment_service_catalog
language sql
stable
security definer
set search_path = ''
as $$
  select g.*
  from public.garment_service_catalog g
  where g.is_active = true
  order by g.sort_order, g.service_key
$$;

create or replace function public.get_garment_service_catalog()
returns setof public.garment_service_catalog
language sql
stable
security invoker
set search_path = public, private
as $$ select * from private.get_garment_service_catalog() $$;

revoke all on function private.get_garment_service_catalog() from public, anon, authenticated;
grant execute on function private.get_garment_service_catalog() to authenticated;
revoke all on function public.get_garment_service_catalog() from anon;
grant execute on function public.get_garment_service_catalog() to authenticated;

create or replace function private.get_producer_reel_owners(p_user_ids uuid[])
returns table(id uuid, username text, display_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.username, p.display_name
  from public.profiles p
  where p.id = any(coalesce(p_user_ids, '{}'::uuid[]))
    and p.is_active = true
    and p.is_suspended = false
$$;

create or replace function public.get_producer_reel_owners(p_user_ids uuid[])
returns table(id uuid, username text, display_name text)
language sql
stable
security invoker
set search_path = public, private
as $$ select * from private.get_producer_reel_owners($1) $$;

revoke all on function private.get_producer_reel_owners(uuid[]) from public, anon, authenticated;
grant execute on function private.get_producer_reel_owners(uuid[]) to authenticated;
revoke all on function public.get_producer_reel_owners(uuid[]) from anon;
grant execute on function public.get_producer_reel_owners(uuid[]) to authenticated;

create or replace function private.admin_set_platform_service_access(
  p_user_id uuid,
  p_service_key text,
  p_is_active boolean
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_key text := lower(trim(coalesce(p_service_key,'')));
begin
  if v_uid is null or not public._is_platform_owner(v_uid) then
    raise exception 'FORBIDDEN';
  end if;
  if p_user_id is null or v_key = '' then
    raise exception 'INVALID_ARGUMENTS';
  end if;
  insert into public.platform_service_access(
    user_id,service_key,granted_by,is_active,created_at,updated_at
  )
  values(p_user_id,v_key,v_uid,coalesce(p_is_active,true),now(),now())
  on conflict(user_id,service_key)
  do update set
    granted_by=excluded.granted_by,
    is_active=excluded.is_active,
    updated_at=now();
  return true;
end;
$$;

create or replace function public.admin_set_platform_service_access(
  p_user_id uuid,
  p_service_key text,
  p_is_active boolean
) returns boolean
language sql
security invoker
set search_path = public, private
as $$ select private.admin_set_platform_service_access($1,$2,$3) $$;

revoke all on function private.admin_set_platform_service_access(uuid,text,boolean) from public, anon, authenticated;
grant execute on function private.admin_set_platform_service_access(uuid,text,boolean) to authenticated;
revoke all on function public.admin_set_platform_service_access(uuid,text,boolean) from anon;
grant execute on function public.admin_set_platform_service_access(uuid,text,boolean) to authenticated;

create or replace function private.admin_get_platform_service_access(
  p_user_id uuid,
  p_service_key text
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public._is_platform_owner(auth.uid())
    and exists(
      select 1
      from public.platform_service_access a
      where a.user_id=p_user_id
        and a.service_key=lower(trim(coalesce(p_service_key,'')))
        and a.is_active=true
    )
$$;

create or replace function public.admin_get_platform_service_access(
  p_user_id uuid,
  p_service_key text
) returns boolean
language sql
stable
security invoker
set search_path = public, private
as $$ select private.admin_get_platform_service_access($1,$2) $$;

revoke all on function private.admin_get_platform_service_access(uuid,text) from public, anon, authenticated;
grant execute on function private.admin_get_platform_service_access(uuid,text) to authenticated;
revoke all on function public.admin_get_platform_service_access(uuid,text) from anon;
grant execute on function public.admin_get_platform_service_access(uuid,text) to authenticated;

create or replace function private_rpc.publish_garment_service_ad(
  p_service_key text,
  p_sector_key text,
  p_title text,
  p_description text default '',
  p_price_minor_units bigint default null,
  p_currency text default 'sham_cash',
  p_unit text default null,
  p_min_qty integer default null,
  p_city text default null,
  p_address text default null,
  p_phone text default null,
  p_whatsapp text default null,
  p_images jsonb default '[]'::jsonb,
  p_specs jsonb default '{}'::jsonb,
  p_publication_currency text default 'points',
  p_request_id uuid default gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_service text := lower(trim(coalesce(p_service_key,'')));
  v_sector text := lower(trim(coalesce(p_sector_key,'')));
  v_currency text := lower(trim(coalesce(p_publication_currency,'points')));
  v_fee record;
  v_cost bigint := 0;
  v_before bigint := 0;
  v_after bigint := 0;
  v_id uuid;
  v_existing record;
  v_path text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'PUBLICATION_REQUEST_REQUIRED'; end if;
  if not (private.is_my_platform_owner() or private.has_platform_service_access(v_uid,'garment_service_ads')) then
    raise exception 'GARMENT_SERVICE_ACCESS_REQUIRED';
  end if;
  if v_service='' or v_sector='' then raise exception 'SERVICE_REQUIRED'; end if;
  if length(trim(coalesce(p_title,'')))=0 or length(trim(p_title))>180 then raise exception 'INVALID_TITLE'; end if;
  if length(coalesce(p_description,''))>5000 then raise exception 'INVALID_DESCRIPTION'; end if;
  if p_price_minor_units is not null and p_price_minor_units < 0 then raise exception 'INVALID_PRICE'; end if;
  if v_currency not in ('points','gems') then raise exception 'INVALID_PUBLICATION_CURRENCY'; end if;
  if lower(trim(coalesce(p_currency,'sham_cash'))) not in ('sham_cash','shamcash') then raise exception 'INVALID_PRICE_CURRENCY'; end if;
  if p_min_qty is not null and p_min_qty < 1 then raise exception 'INVALID_MIN_QTY'; end if;
  if jsonb_typeof(coalesce(p_images,'[]'::jsonb)) <> 'array' then raise exception 'INVALID_IMAGES'; end if;
  if jsonb_array_length(coalesce(p_images,'[]'::jsonb)) > 8 then raise exception 'TOO_MANY_IMAGES'; end if;

  if not exists (
    select 1 from public.garment_service_catalog
    where service_key=v_service and sector_key=v_sector and is_active=true
  ) then raise exception 'INVALID_SERVICE'; end if;

  if not exists (
    select 1 from public.garment_sectors
    where sector_key=v_sector and is_active=true
  ) then raise exception 'INVALID_SECTOR'; end if;

  select id into v_existing
  from public.garment_service_ads
  where publication_request_id=p_request_id
  limit 1;

  if found then
    return jsonb_build_object('ok',true,'id',v_existing.id,'replayed',true);
  end if;

  select * into v_fee
  from public.garment_publication_fee_rules
  where content_type='garment_service' and is_enabled=true
  limit 1;

  if private.is_my_platform_owner() then
    v_cost := 0;
  else
    v_cost := case
      when v_currency='points' then coalesce(v_fee.points_cost,0)
      else coalesce(v_fee.gems_cost,0)
    end;

    if v_cost <= 0 then
      raise exception 'PUBLICATION_FEE_NOT_CONFIGURED';
    end if;

    if v_currency='points' then
      select balance into v_before
      from public.points_wallets
      where user_id=v_uid
      for update;

      if coalesce(v_before,0)<v_cost then
        raise exception 'INSUFFICIENT_POINTS';
      end if;

      update public.points_wallets
      set balance=balance-v_cost,
          lifetime_spent=lifetime_spent+v_cost,
          version=version+1,
          updated_at=now()
      where user_id=v_uid;
    else
      select balance into v_before
      from public.gems_wallets
      where user_id=v_uid
      for update;

      if coalesce(v_before,0)<v_cost then
        raise exception 'INSUFFICIENT_GEMS';
      end if;

      update public.gems_wallets
      set balance=balance-v_cost,
          lifetime_spent=lifetime_spent+v_cost,
          version=version+1,
          updated_at=now()
      where user_id=v_uid;
    end if;

    v_after := v_before-v_cost;
  end if;

  if jsonb_array_length(coalesce(p_images,'[]'::jsonb))>0 then
    for v_path in
      select value::text
      from jsonb_array_elements_text(coalesce(p_images,'[]'::jsonb))
    loop
      if not (
        v_path like 'storage://garment-service-media/'||v_uid::text||'/%'
        or v_path like '%/storage/v1/object/public/garment-service-media/'||v_uid::text||'/%'
      ) then
        raise exception 'INVALID_IMAGE_PATH';
      end if;
    end loop;
  end if;

  insert into public.garment_service_ads(
    owner_uid,service_key,sector_key,title,description,
    price_minor_units,currency,unit,min_qty,city,address,phone,whatsapp,
    images,specs,status,publication_request_id
  ) values(
    v_uid,v_service,v_sector,trim(p_title),trim(coalesce(p_description,'')),
    p_price_minor_units,'sham_cash',
    nullif(trim(coalesce(p_unit,'')),''),
    p_min_qty,
    nullif(trim(coalesce(p_city,'')),''),
    nullif(trim(coalesce(p_address,'')),''),
    nullif(trim(coalesce(p_phone,'')),''),
    nullif(trim(coalesce(p_whatsapp,'')),''),
    coalesce(p_images,'[]'::jsonb),
    coalesce(p_specs,'{}'::jsonb),
    'published',p_request_id
  )
  returning id into v_id;

  if v_cost>0 then
    insert into public.wallet_transactions(
      user_id,currency,transaction_type,amount,
      balance_before,balance_after,reference_type,reference_id,
      idempotency_key,metadata,created_by
    ) values(
      v_uid,v_currency,'garment_service_publication_fee',-v_cost,
      v_before,v_after,'garment_service_ad',v_id::text,
      p_request_id,
      jsonb_build_object('service_key',v_service,'title',trim(p_title)),
      v_uid
    );
  end if;

  perform public.write_audit(
    'garment_service_ad_publish',
    v_id::text,
    p_request_id,
    'succeeded',
    jsonb_build_object(
      'service_key',v_service,
      'currency',v_currency,
      'amount',v_cost
    )
  );

  return jsonb_build_object(
    'ok',true,
    'id',v_id,
    'charged',v_cost>0,
    'amount',v_cost,
    'currency',v_currency,
    'replayed',false
  );
end;
$function$;
