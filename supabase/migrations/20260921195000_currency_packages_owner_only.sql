begin;

create or replace function private_rpc.admin_upsert_currency_package(
  p_id text,p_package_type text,p_title text,p_description text,p_amount bigint,
  p_bonus_amount bigint,p_price_minor_units bigint,p_price_currency text,
  p_image_url text,p_icon_key text,p_enabled boolean,p_featured boolean,p_sort_order integer
)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid(); v_id text:=trim(coalesce(p_id,''));
begin
  if v_uid is null or not public._is_platform_owner(v_uid) then raise exception 'FORBIDDEN'; end if;
  if v_id='' or length(v_id)>100 then raise exception 'INVALID_PACKAGE_ID'; end if;
  if lower(trim(coalesce(p_package_type,''))) not in ('points','gems') then raise exception 'INVALID_PACKAGE_TYPE'; end if;
  if nullif(trim(coalesce(p_title,'')),'') is null or length(trim(p_title))>180 then raise exception 'INVALID_TITLE'; end if;
  if coalesce(p_amount,0)<0 or coalesce(p_bonus_amount,0)<0 or coalesce(p_price_minor_units,0)<0 then raise exception 'INVALID_PACKAGE_VALUES'; end if;
  if lower(trim(coalesce(p_price_currency,'sham_cash'))) not in ('sham_cash','shamcash') then raise exception 'INVALID_PRICE_CURRENCY'; end if;
  if p_image_url is not null and length(trim(p_image_url))>2048 then raise exception 'INVALID_IMAGE_URL'; end if;
  insert into public.currency_packages(id,package_type,title,description,amount,bonus_amount,price_minor_units,price_currency,image_url,icon_key,enabled,featured,sort_order,created_by,updated_by,updated_at)
  values(v_id,lower(trim(p_package_type)),trim(p_title),coalesce(trim(p_description),''),p_amount,p_bonus_amount,p_price_minor_units,'sham_cash',nullif(trim(coalesce(p_image_url,'')),''),nullif(trim(coalesce(p_icon_key,'')),''),coalesce(p_enabled,true),coalesce(p_featured,false),greatest(0,coalesce(p_sort_order,0)),v_uid,v_uid,now())
  on conflict(id) do update set
    package_type=excluded.package_type,title=excluded.title,description=excluded.description,amount=excluded.amount,bonus_amount=excluded.bonus_amount,
    price_minor_units=excluded.price_minor_units,price_currency=excluded.price_currency,image_url=excluded.image_url,icon_key=excluded.icon_key,
    enabled=excluded.enabled,featured=excluded.featured,sort_order=excluded.sort_order,updated_by=v_uid,updated_at=now();
  perform public.write_audit('admin_currency_package_upsert',v_id,gen_random_uuid(),'succeeded',jsonb_build_object('package_type',p_package_type));
  return jsonb_build_object('ok',true,'id',v_id);
end;
$function$;

create or replace function private_rpc.admin_set_currency_package_enabled(p_id text,p_enabled boolean)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null or not public._is_platform_owner(v_uid) then raise exception 'FORBIDDEN'; end if;
  update public.currency_packages set enabled=coalesce(p_enabled,false),updated_by=v_uid,updated_at=now() where id=trim(p_id);
  if not found then raise exception 'PACKAGE_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true,'id',trim(p_id),'enabled',coalesce(p_enabled,false));
end;
$function$;

delete from public.platform_service_access where service_key='currency_packages';

drop policy if exists currency_package_media_owner_insert on storage.objects;
create policy currency_package_media_owner_insert on storage.objects for insert to authenticated
with check (bucket_id='currency-package-media' and (storage.foldername(name))[1]='packages' and public._is_platform_owner((select auth.uid())) and lower(storage.extension(name))=any(array['png','jpg','jpeg','webp']::text[]));

drop policy if exists currency_package_media_owner_update on storage.objects;
create policy currency_package_media_owner_update on storage.objects for update to authenticated
using (bucket_id='currency-package-media' and (storage.foldername(name))[1]='packages' and public._is_platform_owner((select auth.uid())))
with check (bucket_id='currency-package-media' and (storage.foldername(name))[1]='packages' and public._is_platform_owner((select auth.uid())) and lower(storage.extension(name))=any(array['png','jpg','jpeg','webp']::text[]));

drop policy if exists currency_package_media_owner_delete on storage.objects;
create policy currency_package_media_owner_delete on storage.objects for delete to authenticated
using (bucket_id='currency-package-media' and (storage.foldername(name))[1]='packages' and public._is_platform_owner((select auth.uid())));

commit;
