create index if not exists idx_user_ui_theme_preferences_theme_id
  on private.user_ui_theme_preferences(theme_id);

drop policy if exists user_ui_theme_preferences_self on private.user_ui_theme_preferences;
create policy user_ui_theme_preferences_self
on private.user_ui_theme_preferences
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create or replace function private.get_my_ui_theme_impl()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_theme_id text;
  v_theme public.platform_ui_theme_catalog%rowtype;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select p.theme_id into v_theme_id
  from private.user_ui_theme_preferences p
  where p.user_id = v_uid;
  select * into v_theme
  from public.platform_ui_theme_catalog c
  where c.theme_id = coalesce(v_theme_id, 'gold_luxury') and c.is_active = true
  limit 1;
  if v_theme.theme_id is null then
    select * into v_theme
    from public.platform_ui_theme_catalog c
    where c.is_active = true
    order by c.sort_order, c.theme_id
    limit 1;
  end if;
  if v_theme.theme_id is null then raise exception 'THEME_CATALOG_EMPTY'; end if;
  return jsonb_build_object('theme_id',v_theme.theme_id,'name_ar',v_theme.name_ar,
    'icon_key',v_theme.icon_key,'palette',v_theme.palette,'version',v_theme.version);
end;
$function$;

create or replace function private.set_my_ui_theme_impl(p_theme_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_theme public.platform_ui_theme_catalog%rowtype;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_theme
  from public.platform_ui_theme_catalog c
  where c.theme_id = trim(coalesce(p_theme_id, '')) and c.is_active = true
  limit 1;
  if v_theme.theme_id is null then raise exception 'THEME_NOT_AVAILABLE'; end if;
  insert into private.user_ui_theme_preferences(user_id,theme_id,updated_at)
  values(v_uid,v_theme.theme_id,now())
  on conflict(user_id) do update set theme_id=excluded.theme_id,updated_at=now();
  return jsonb_build_object('ok',true,'theme_id',v_theme.theme_id,'name_ar',v_theme.name_ar,
    'icon_key',v_theme.icon_key,'palette',v_theme.palette,'version',v_theme.version);
end;
$function$;

grant usage on schema private to authenticated;
revoke execute on function private.get_my_ui_theme_impl() from public, anon, authenticated;
revoke execute on function private.set_my_ui_theme_impl(text) from public, anon, authenticated;
grant execute on function private.get_my_ui_theme_impl() to authenticated;
grant execute on function private.set_my_ui_theme_impl(text) to authenticated;

create or replace function public.get_my_ui_theme()
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $function$
  select private.get_my_ui_theme_impl();
$function$;

create or replace function public.set_my_ui_theme(p_theme_id text)
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
  select private.set_my_ui_theme_impl(p_theme_id);
$function$;

revoke execute on function public.get_my_ui_theme() from public, anon;
grant execute on function public.get_my_ui_theme() to authenticated;
revoke execute on function public.set_my_ui_theme(text) from public, anon;
grant execute on function public.set_my_ui_theme(text) to authenticated;
