-- Runtime regression fixes verified against production Supabase project.
-- 1) Gift overlays expire after 15 seconds, not 30 days.
-- 2) Expose a safe authenticated RPC for resolving the canonical platform owner.

begin;

create or replace function public._gift_global_event_trigger()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $function$
declare
  v_room uuid;
  v_payload jsonb;
  v_from_name text;
  v_to_name text;
  v_image text;
begin
  begin
    v_room := nullif(new.metadata->>'room_id','')::uuid;
  exception when others then
    v_room := null;
  end;

  select coalesce(nullif(trim(display_name),''),username,'عضو')
    into v_from_name
  from public.profiles
  where id = new.from_uid;

  select coalesce(nullif(trim(display_name),''),username,'عضو')
    into v_to_name
  from public.profiles
  where id = new.to_uid;

  select gc.image_url
    into v_image
  from public.gift_catalog gc
  where gc.id = new.gift_id;

  v_payload := jsonb_build_object(
    'gift_id', new.gift_id,
    'gift_name', coalesce(new.metadata->>'gift_name', new.gift_id),
    'emoji', coalesce(new.metadata->>'emoji','🎁'),
    'image_url', coalesce(new.metadata->>'gift_image_url', new.metadata->>'image_url', v_image, ''),
    'from_uid', new.from_uid::text,
    'to_uid', new.to_uid::text,
    'from_name', coalesce(v_from_name,'عضو'),
    'to_name', coalesce(v_to_name,'عضو'),
    'room_id', v_room::text,
    'price_points', new.price_points,
    'created_at', now()
  );

  insert into public.chat_global_events(
    event_type, actor_uid, room_id, payload, expires_at
  )
  values(
    'gift', new.from_uid, v_room, v_payload, now() + interval '15 seconds'
  );

  return new;
exception when others then
  return new;
end
$function$;

update public.chat_global_events
set expires_at = least(
  coalesce(expires_at, created_at + interval '15 seconds'),
  created_at + interval '15 seconds'
)
where event_type in ('gift','points_transfer','gems_transfer');

create or replace function private.get_platform_owner_uid()
returns uuid
language sql
stable
security definer
set search_path = 'public'
as $function$
  select ur.user_id
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  join public.profiles p on p.id = ur.user_id
  where r.code = 'dragon'
    and coalesce(p.is_active, true) = true
    and coalesce(p.is_suspended, false) = false
  order by coalesce(r.priority, 0) desc, ur.user_id
  limit 1
$function$;

create or replace function private_rpc.get_platform_owner_uid()
returns uuid
language sql
stable
security definer
set search_path = 'public'
as $function$
  select private.get_platform_owner_uid()
$function$;

create or replace function public.get_platform_owner_uid()
returns uuid
language sql
stable
security invoker
set search_path = 'public', 'private_rpc'
as $function$
  select private_rpc.get_platform_owner_uid()
$function$;

revoke all on function public.get_platform_owner_uid() from public, anon;
grant execute on function public.get_platform_owner_uid() to authenticated;

commit;
