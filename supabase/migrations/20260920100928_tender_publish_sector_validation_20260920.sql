create or replace function public.publish_tender(
  p_title text,
  p_description text,
  p_scope text default 'domestic',
  p_sector_key text default null,
  p_quantity integer default null,
  p_unit text default null,
  p_budget_min bigint default null,
  p_budget_max bigint default null,
  p_city text default null,
  p_target_country text default null,
  p_incoterm text default null,
  p_shipping_method text default null,
  p_customs_handled_by text default null,
  p_payment_terms text default null,
  p_required_certificates text[] default '{}',
  p_packaging_requirements text default null,
  p_sample_required boolean default false,
  p_attachments jsonb default '[]',
  p_images jsonb default '[]',
  p_specs jsonb default '{}',
  p_deadline_at timestamptz default null,
  p_delivery_deadline_at timestamptz default null
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
  v_cost bigint := 0;
  v_pb bigint;
  v_scope text := lower(trim(coalesce(p_scope, 'domestic')));
  v_country text := nullif(trim(coalesce(p_target_country, '')), '');
  v_sector text := nullif(trim(coalesce(p_sector_key, '')), '');
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_scope not in ('domestic','external') then raise exception 'INVALID_SCOPE'; end if;
  if nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'TITLE_REQUIRED'; end if;
  if nullif(trim(coalesce(p_description,'')),'') is null then raise exception 'DESCRIPTION_REQUIRED'; end if;
  if v_sector is null then raise exception 'SECTOR_REQUIRED'; end if;
  if not exists(select 1 from public.garment_sectors s where s.sector_key=v_sector and s.is_active=true) then raise exception 'INVALID_SECTOR'; end if;
  if p_quantity is not null and p_quantity <= 0 then raise exception 'INVALID_QUANTITY'; end if;
  if p_budget_min is not null and p_budget_min < 0 then raise exception 'INVALID_BUDGET'; end if;
  if p_budget_max is not null and p_budget_max < 0 then raise exception 'INVALID_BUDGET'; end if;
  if p_budget_min is not null and p_budget_max is not null and p_budget_max < p_budget_min then raise exception 'BUDGET_RANGE_INVALID'; end if;
  if p_deadline_at is not null and p_deadline_at <= now() then raise exception 'INVALID_OFFER_DEADLINE'; end if;
  if p_delivery_deadline_at is not null and p_delivery_deadline_at <= now() then raise exception 'INVALID_DELIVERY_DEADLINE'; end if;
  if p_deadline_at is not null and p_delivery_deadline_at is not null and p_delivery_deadline_at < p_deadline_at then raise exception 'DELIVERY_BEFORE_OFFER_DEADLINE'; end if;
  if v_scope = 'external' then
    if v_country is null then raise exception 'TARGET_COUNTRY_REQUIRED'; end if;
    if lower(regexp_replace(v_country,'[\s\-_]+','','g')) in ('سوريا','الجمهوريةالعربيةالسورية','syria','syrianarabrepublic','sy') then raise exception 'EXTERNAL_COUNTRY_MUST_BE_OUTSIDE_SYRIA'; end if;
    if nullif(trim(coalesce(p_incoterm,'')),'') is null then raise exception 'INCOTERM_REQUIRED'; end if;
    if nullif(trim(coalesce(p_shipping_method,'')),'') is null then raise exception 'SHIPPING_METHOD_REQUIRED'; end if;
    if nullif(trim(coalesce(p_customs_handled_by,'')),'') is null then raise exception 'CUSTOMS_RESPONSIBLE_REQUIRED'; end if;
    if nullif(trim(coalesce(p_payment_terms,'')),'') is null then raise exception 'PAYMENT_TERMS_REQUIRED'; end if;
  end if;
  q := public.get_my_tender_quota();
  if not coalesce((q->>'unlimited')::boolean,false) then
    if v_scope='external' then
      if not coalesce((q->>'can_publish_external')::boolean,false) then raise exception 'EXTERNAL_NOT_ALLOWED'; end if;
      if coalesce((q->>'external_remaining')::int,0) <= 0 then raise exception 'EXTERNAL_QUOTA_EXCEEDED'; end if;
    else
      if coalesce((q->>'domestic_remaining')::int,0) <= 0 then raise exception 'TENDER_QUOTA_EXCEEDED'; end if;
    end if;
    v_cost := coalesce((q->>'publish_cost_points')::bigint,0);
    if v_cost > 0 then
      select balance into v_pb from public.points_wallets where user_id=v_uid for update;
      if coalesce(v_pb,0) < v_cost then raise exception 'INSUFFICIENT_POINTS'; end if;
      update public.points_wallets set balance=balance-v_cost,lifetime_spent=lifetime_spent+v_cost,version=version+1,updated_at=now() where user_id=v_uid;
    end if;
  end if;
  insert into public.tenders(owner_uid,scope,title,description,sector_key,quantity,unit,budget_min_minor_units,budget_max_minor_units,city,target_country,incoterm,shipping_method,customs_handled_by,payment_terms,required_certificates,packaging_requirements,sample_required,attachments,images,specs,deadline_at,delivery_deadline_at,status)
  values(v_uid,v_scope,trim(p_title),trim(p_description),v_sector,p_quantity,p_unit,p_budget_min,p_budget_max,p_city,case when v_scope='external' then v_country else null end,p_incoterm,p_shipping_method,p_customs_handled_by,p_payment_terms,coalesce(p_required_certificates,'{}'),p_packaging_requirements,coalesce(p_sample_required,false),coalesce(p_attachments,'[]'),coalesce(p_images,'[]'),coalesce(p_specs,'{}'),p_deadline_at,p_delivery_deadline_at,'open')
  returning id into v_id;
  return jsonb_build_object('ok',true,'id',v_id,'scope',v_scope,'charged_points',v_cost);
end;
$function$;

revoke execute on function public.publish_tender(text,text,text,text,integer,text,bigint,bigint,text,text,text,text,text,text,text[],text,boolean,jsonb,jsonb,jsonb,timestamptz,timestamptz) from public, anon;
grant execute on function public.publish_tender(text,text,text,text,integer,text,bigint,bigint,text,text,text,text,text,text,text[],text,boolean,jsonb,jsonb,jsonb,timestamptz,timestamptz) to authenticated;
