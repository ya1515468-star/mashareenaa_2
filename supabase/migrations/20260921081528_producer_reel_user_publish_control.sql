create or replace function private_rpc.set_producer_reel_published(
  p_reel_id uuid,
  p_is_published boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_published boolean;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select owner_uid
    into v_owner
  from public.producer_reels
  where id = p_reel_id
  for update;

  if v_owner is null then
    raise exception 'REEL_NOT_FOUND';
  end if;

  if v_owner <> v_uid and not public._is_platform_owner(v_uid) then
    raise exception 'FORBIDDEN';
  end if;

  v_published := coalesce(p_is_published, false);

  update public.producer_reels
     set is_published = v_published,
         updated_at = now()
   where id = p_reel_id;

  perform public.write_audit(
    'producer_reel_publish_state',
    p_reel_id::text,
    gen_random_uuid(),
    'succeeded',
    jsonb_build_object(
      'is_published', v_published,
      'actor_uid', v_uid
    )
  );

  return jsonb_build_object(
    'ok', true,
    'id', p_reel_id,
    'is_published', v_published
  );
end;
$function$;

create or replace function public.set_producer_reel_published(
  p_reel_id uuid,
  p_is_published boolean
)
returns jsonb
language sql
set search_path = 'public', 'private_rpc'
as $function$
  select private_rpc.set_producer_reel_published($1, $2);
$function$;

revoke all on function public.set_producer_reel_published(uuid, boolean) from public;
grant execute on function public.set_producer_reel_published(uuid, boolean) to authenticated;
