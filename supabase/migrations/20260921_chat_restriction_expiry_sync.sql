-- Keep expired chat restrictions from leaving stale member flags behind.
-- The live function was updated directly first; this file records the same
-- production change for repository migration parity.
create or replace function public.sync_chat_member_ban_state(p_room_id uuid, p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = 'public'
as $function$
declare
  v_banned boolean := false;
begin
  if p_room_id is null or p_user_id is null then
    return false;
  end if;

  update public.chat_room_penalties
  set is_active = false,
      updated_at = now()
  where room_id = p_room_id
    and user_id = p_user_id
    and is_active = true
    and expires_at is not null
    and expires_at <= now();

  v_banned := exists (
    select 1
    from public.chat_room_penalties cp
    where cp.room_id = p_room_id
      and cp.user_id = p_user_id
      and cp.penalty_type = 'ban'
      and cp.is_active = true
      and (cp.expires_at is null or cp.expires_at > now())
  );

  update public.chat_room_members
  set is_banned = v_banned
  where room_id = p_room_id
    and user_id = p_user_id;

  return v_banned;
end;
$function$;