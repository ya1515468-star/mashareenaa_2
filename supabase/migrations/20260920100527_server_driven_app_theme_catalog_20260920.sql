-- Server-driven application style catalog + per-user server persistence.
-- Direct client writes to preferences are intentionally unavailable.

create schema if not exists private;

create table if not exists public.platform_ui_theme_catalog (
  theme_id text primary key,
  name_ar text not null,
  icon_key text not null default 'palette',
  palette jsonb not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.platform_ui_theme_catalog enable row level security;

drop policy if exists platform_ui_theme_catalog_read on public.platform_ui_theme_catalog;
create policy platform_ui_theme_catalog_read
on public.platform_ui_theme_catalog
for select
to anon, authenticated
using (is_active = true);

grant select on public.platform_ui_theme_catalog to anon, authenticated;

create table if not exists private.user_ui_theme_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  theme_id text not null references public.platform_ui_theme_catalog(theme_id),
  updated_at timestamptz not null default now()
);

alter table private.user_ui_theme_preferences enable row level security;

-- No direct Data API access is granted on the private table.
revoke all on private.user_ui_theme_preferences from public, anon, authenticated;

insert into public.platform_ui_theme_catalog(theme_id,name_ar,icon_key,palette,is_active,sort_order,version,updated_at)
values
('gold_luxury','الذهبي الفاخر','diamond',jsonb_build_object(
  'accent','#D4AF37','accent_muted','#B8944A','accent_bright','#F1D07A',
  'secondary','#7A1F3D','secondary_bright','#A23A5C',
  'background','#0A0A0C','surface','#15141A','surface_elevated','#1E1C24','surface_highlight','#28242E',
  'text_primary','#F5F1E8','text_secondary','#AFA79A','text_muted','#6E6A63','divider','#2A2830',
  'error','#CF6679','success','#3FA377','warning','#E0A96D'
),true,10,1,now()),
('emerald_noir','الزمردي الليلي','eco',jsonb_build_object(
  'accent','#2FBF8E','accent_muted','#279E76','accent_bright','#7FE3BC',
  'secondary','#14483C','secondary_bright','#1F6E5A',
  'background','#08100D','surface','#10201A','surface_elevated','#162B23','surface_highlight','#1D372D',
  'text_primary','#EFF7F2','text_secondary','#A4BDB2','text_muted','#63776E','divider','#223A30',
  'error','#E0716A','success','#52D19A','warning','#E0C36D'
),true,20,1,now()),
('sapphire_midnight','الياقوتي الليلي','nightlight',jsonb_build_object(
  'accent','#3E7BFA','accent_muted','#3560C4','accent_bright','#8FB2FF',
  'secondary','#241B57','secondary_bright','#3B2C86',
  'background','#07080F','surface','#10131F','surface_elevated','#161B2B','surface_highlight','#1E2438',
  'text_primary','#EEF1FB','text_secondary','#A6ACC4','text_muted','#636B87','divider','#232B44',
  'error','#E07A87','success','#4FBE8F','warning','#E0A96D'
),true,30,1,now()),
('rose_gold','الذهبي الوردي','local_florist',jsonb_build_object(
  'accent','#E0A0A8','accent_muted','#C7818C','accent_bright','#F3C7CD',
  'secondary','#4A2530','secondary_bright','#6E3B49',
  'background','#0C0808','surface','#171112','surface_elevated','#211819','surface_highlight','#2C2021',
  'text_primary','#F8EFEE','text_secondary','#C0A6A5','text_muted','#7A6362','divider','#332525',
  'error','#E0716A','success','#54B98C','warning','#E0B06D'
),true,40,1,now()),
('plum_noir','البرقوقي الليلي','auto_awesome',jsonb_build_object(
  'accent','#B68CFF','accent_muted','#8063BA','accent_bright','#DCCBFF',
  'secondary','#43245F','secondary_bright','#6D3B91',
  'background','#0B0710','surface','#170F1D','surface_elevated','#21152A','surface_highlight','#2D1D39',
  'text_primary','#F7F1FF','text_secondary','#BEB0CB','text_muted','#74677F','divider','#382641',
  'error','#E47C91','success','#5FCF9C','warning','#E1BA72'
),true,50,1,now()),
('desert_onyx','العقيق الرملي','palette',jsonb_build_object(
  'accent','#D9A66A','accent_muted','#A97749','accent_bright','#F2C994',
  'secondary','#5A3523','secondary_bright','#805238',
  'background','#100B08','surface','#1C1410','surface_elevated','#261C16','surface_highlight','#35261C',
  'text_primary','#FFF7EE','text_secondary','#C8B7A5','text_muted','#817164','divider','#3E2F25',
  'error','#E47D6A','success','#63C99A','warning','#E4C16F'
),true,60,1,now())
on conflict (theme_id) do update set
  name_ar=excluded.name_ar,
  icon_key=excluded.icon_key,
  palette=excluded.palette,
  is_active=excluded.is_active,
  sort_order=excluded.sort_order,
  version=greatest(public.platform_ui_theme_catalog.version, excluded.version)+1,
  updated_at=now();

create or replace function public.get_ui_theme_catalog()
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'theme_id', c.theme_id,
      'name_ar', c.name_ar,
      'icon_key', c.icon_key,
      'palette', c.palette,
      'version', c.version
    ) order by c.sort_order, c.theme_id
  ), '[]'::jsonb)
  from public.platform_ui_theme_catalog c
  where c.is_active = true;
$$;

create or replace function public.get_my_ui_theme()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_theme_id text;
  v_theme public.platform_ui_theme_catalog%rowtype;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select p.theme_id into v_theme_id
  from private.user_ui_theme_preferences p
  where p.user_id = v_uid;

  select * into v_theme
  from public.platform_ui_theme_catalog c
  where c.theme_id = coalesce(v_theme_id, 'gold_luxury')
    and c.is_active = true
  limit 1;

  if v_theme.theme_id is null then
    select * into v_theme
    from public.platform_ui_theme_catalog c
    where c.is_active = true
    order by c.sort_order, c.theme_id
    limit 1;
  end if;

  if v_theme.theme_id is null then
    raise exception 'THEME_CATALOG_EMPTY';
  end if;

  return jsonb_build_object(
    'theme_id', v_theme.theme_id,
    'name_ar', v_theme.name_ar,
    'icon_key', v_theme.icon_key,
    'palette', v_theme.palette,
    'version', v_theme.version
  );
end;
$$;

create or replace function public.set_my_ui_theme(p_theme_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_theme public.platform_ui_theme_catalog%rowtype;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select * into v_theme
  from public.platform_ui_theme_catalog c
  where c.theme_id = trim(coalesce(p_theme_id,''))
    and c.is_active = true
  limit 1;

  if v_theme.theme_id is null then
    raise exception 'THEME_NOT_AVAILABLE';
  end if;

  insert into private.user_ui_theme_preferences(user_id,theme_id,updated_at)
  values(v_uid,v_theme.theme_id,now())
  on conflict(user_id) do update
    set theme_id=excluded.theme_id, updated_at=now();

  return jsonb_build_object(
    'ok', true,
    'theme_id', v_theme.theme_id,
    'name_ar', v_theme.name_ar,
    'icon_key', v_theme.icon_key,
    'palette', v_theme.palette,
    'version', v_theme.version
  );
end;
$$;

revoke execute on function public.get_ui_theme_catalog() from public, anon;
grant execute on function public.get_ui_theme_catalog() to anon, authenticated;
revoke execute on function public.get_my_ui_theme() from public, anon;
grant execute on function public.get_my_ui_theme() to authenticated;
revoke execute on function public.set_my_ui_theme(text) from public, anon;
grant execute on function public.set_my_ui_theme(text) to authenticated;

-- The 20260920 auth migration added a second permissive read policy on a table
-- that already had a public read policy. Keep exactly one public read path.
drop policy if exists platform_ui_runtime_public_read on public.platform_ui_runtime;
