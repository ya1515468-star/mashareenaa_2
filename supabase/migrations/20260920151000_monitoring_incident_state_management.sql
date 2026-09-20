create or replace function private.sync_client_error_resolution()
returns trigger
language plpgsql
security definer
set search_path=public,private
as $fn$
begin
  update public.platform_incidents
  set status = case
    when new.resolved = true then 'resolved'
    when status = 'resolved' then 'open'
    else status
  end,
  updated_at = now()
  where incident_key = 'client_error:' || new.fingerprint;
  return new;
end;
$fn$;

revoke all on function private.sync_client_error_resolution() from public,anon,authenticated;
drop trigger if exists trg_client_error_resolution on public.client_error_logs;
create trigger trg_client_error_resolution
after update of resolved on public.client_error_logs
for each row execute function private.sync_client_error_resolution();

create or replace function public.admin_set_security_alert_state(p_id uuid,p_state text)
returns jsonb language plpgsql security definer set search_path=public
as $fn$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.has_absolute_view(v_uid) then raise exception 'FORBIDDEN'; end if;
  if p_state not in ('open','reviewed','contained','resolved','false_positive') then raise exception 'INVALID_ALERT_STATE'; end if;
  update public.security_alerts
  set state=p_state,
      resolved_at=case when p_state='resolved' then now() else null end,
      resolved_by=case when p_state='resolved' then v_uid else null end
  where id=p_id;
  if not found then raise exception 'ALERT_NOT_FOUND'; end if;
  perform public.write_audit('security_alert_state_change',p_id::text,gen_random_uuid(),'succeeded',jsonb_build_object('state',p_state));
  return jsonb_build_object('ok',true,'id',p_id,'state',p_state);
end;
$fn$;

revoke all on function public.admin_set_security_alert_state(uuid,text) from public,anon,authenticated;
grant execute on function public.admin_set_security_alert_state(uuid,text) to authenticated;

create or replace function public.admin_set_platform_incident_status(p_id uuid,p_status text)
returns jsonb language plpgsql security definer set search_path=public
as $fn$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.has_absolute_view(v_uid) then raise exception 'FORBIDDEN'; end if;
  if p_status not in ('open','acknowledged','mitigated','resolved') then raise exception 'INVALID_INCIDENT_STATUS'; end if;
  update public.platform_incidents set status=p_status,updated_at=now() where id=p_id;
  if not found then raise exception 'INCIDENT_NOT_FOUND'; end if;
  perform public.write_audit('platform_incident_status_change',p_id::text,gen_random_uuid(),'succeeded',jsonb_build_object('status',p_status));
  return jsonb_build_object('ok',true,'id',p_id,'status',p_status);
end;
$fn$;

revoke all on function public.admin_set_platform_incident_status(uuid,text) from public,anon,authenticated;
grant execute on function public.admin_set_platform_incident_status(uuid,text) to authenticated;
