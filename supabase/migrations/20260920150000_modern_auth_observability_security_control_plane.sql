-- Modern server-driven Auth UI + production observability/security control plane.
-- No client-side authority is introduced by this migration.

-- ---------------------------------------------------------------------------
-- 1) Server-driven Auth UI contract
-- ---------------------------------------------------------------------------
create or replace function public.get_auth_ui_runtime()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'version', version,
    'config', coalesce(config, '{}'::jsonb)
  )
  from public.platform_ui_runtime
  where id = true;
$$;

revoke all on function public.get_auth_ui_runtime() from public, anon, authenticated;
grant execute on function public.get_auth_ui_runtime() to anon, authenticated;

drop policy if exists platform_ui_runtime_public_read on public.platform_ui_runtime;
drop policy if exists platform_ui_runtime_read on public.platform_ui_runtime;
create policy platform_ui_runtime_read
on public.platform_ui_runtime
for select
to anon, authenticated
using (id = true);

grant select on public.platform_ui_runtime to anon, authenticated;

grant select on public.platform_ui_runtime to service_role;

update public.platform_ui_runtime
set
  version = version + 1,
  config = config || jsonb_build_object(
    'brand', jsonb_build_object(
      'name_ar', 'مشاريعنا',
      'name_en', 'Mashareena',
      'tagline_ar', 'من الفكرة إلى السوق، كل شيء في مكان واحد'
    ),
    'auth', jsonb_build_object(
      'mode', 'modern_auth_v2',
      'brand_tagline_ar', 'من الفكرة إلى السوق، كل شيء في مكان واحد',
      'login_title_ar', 'مرحبًا بعودتك',
      'login_subtitle_ar', 'سجّل الدخول لمتابعة أعمالك، محادثاتك وطلباتك.',
      'login_button_ar', 'تسجيل الدخول',
      'register_title_ar', 'أنشئ حسابك',
      'register_subtitle_ar', 'أنشئ هويتك المهنية وابدأ ببناء حضورك داخل مشاريعنا.',
      'register_button_ar', 'إنشاء الحساب',
      'switch_to_register_ar', 'ليس لديك حساب؟ إنشاء حساب',
      'switch_to_login_ar', 'لديك حساب بالفعل؟ تسجيل الدخول',
      'security_note_ar', 'حماية الجلسة وإدارة الهوية تتم عبر خوادم المنصة.',
      'trust_label_ar', 'حماية الخادم مفعّلة',
      'pattern_opacity', 0.05,
      'features', jsonb_build_array(
        jsonb_build_object('icon', 'badge', 'label_ar', 'هوية احترافية'),
        jsonb_build_object('icon', 'store', 'label_ar', 'تجارة وأعمال'),
        jsonb_build_object('icon', 'chat', 'label_ar', 'محادثات واتصال')
      ),
      'hero_image_url', null,
      'palette', jsonb_build_object(
        'name_ar', 'مشاريعنا — Obsidian Gold',
        'accent', '#E7B85A',
        'accent_muted', '#B98A38',
        'accent_bright', '#FFE6A6',
        'secondary', '#6D5AE6',
        'secondary_bright', '#9D8FFF',
        'background', '#070A12',
        'surface', '#0F1420',
        'surface_elevated', '#171D2B',
        'surface_highlight', '#20283A',
        'text_primary', '#F8FAFF',
        'text_secondary', '#A8B3C7',
        'text_muted', '#68748A',
        'divider', '#283247',
        'error', '#FF667D',
        'success', '#35D2A1',
        'warning', '#FFBF69'
      )
    )
  ),
  updated_at = now()
where id = true;

-- ---------------------------------------------------------------------------
-- 2) Incident / security control-plane tables
-- ---------------------------------------------------------------------------
create table if not exists public.platform_incidents (
  id uuid primary key default gen_random_uuid(),
  incident_key text not null unique,
  category text not null check (category in ('client_error','security','integrity','performance','availability','auth')),
  severity text not null check (severity in ('info','warning','error','fatal','critical')),
  status text not null default 'open' check (status in ('open','acknowledged','mitigated','resolved')),
  title text not null,
  summary text,
  source text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  occurrences integer not null default 1 check (occurrences >= 1),
  affected_users integer not null default 0 check (affected_users >= 0),
  last_user_id uuid,
  last_screen text,
  last_app_version text,
  last_platform text,
  remediation_key text,
  remediation_status text not null default 'not_applicable'
    check (remediation_status in ('not_applicable','pending','running','succeeded','failed','blocked')),
  remediation_attempts integer not null default 0 check (remediation_attempts >= 0),
  last_remediation_at timestamptz,
  remediation_result jsonb not null default '{}'::jsonb,
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.security_detection_rules (
  id uuid primary key default gen_random_uuid(),
  rule_key text not null unique,
  name_ar text not null,
  description_ar text,
  event_type text not null,
  min_occurrences integer not null default 1 check (min_occurrences >= 1),
  window_seconds integer not null default 300 check (window_seconds between 30 and 86400),
  risk_delta integer not null default 0 check (risk_delta between 0 and 100),
  enabled boolean not null default true,
  remediation_key text,
  remediation_config jsonb not null default '{}'::jsonb,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create table if not exists public.security_alerts (
  id uuid primary key default gen_random_uuid(),
  alert_key text not null unique,
  event_type text not null,
  severity text not null check (severity in ('warning','error','fatal','critical')),
  user_id uuid,
  risk_score_before integer check (risk_score_before between 0 and 100),
  risk_score_after integer check (risk_score_after between 0 and 100),
  source text not null default 'server',
  ip_hash text,
  device_id_hash text,
  session_id_hash text,
  evidence jsonb not null default '{}'::jsonb,
  state text not null default 'open'
    check (state in ('open','reviewed','contained','resolved','false_positive')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid
);

create index if not exists platform_incidents_status_last_seen_idx
  on public.platform_incidents(status, last_seen_at desc);
create index if not exists platform_incidents_severity_last_seen_idx
  on public.platform_incidents(severity, last_seen_at desc);
create index if not exists security_detection_rules_enabled_event_idx
  on public.security_detection_rules(enabled, event_type);
create index if not exists security_alerts_state_created_idx
  on public.security_alerts(state, created_at desc);
create index if not exists security_alerts_user_created_idx
  on public.security_alerts(user_id, created_at desc);

alter table public.platform_incidents enable row level security;
alter table public.security_detection_rules enable row level security;
alter table public.security_alerts enable row level security;

drop policy if exists platform_incidents_select_authorized on public.platform_incidents;
create policy platform_incidents_select_authorized
on public.platform_incidents
for select
to authenticated
using ((select public.has_absolute_view((select auth.uid()))));

drop policy if exists security_detection_rules_select_authorized on public.security_detection_rules;
create policy security_detection_rules_select_authorized
on public.security_detection_rules
for select
to authenticated
using ((select public.has_absolute_view((select auth.uid()))));

drop policy if exists security_alerts_select_authorized on public.security_alerts;
create policy security_alerts_select_authorized
on public.security_alerts
for select
to authenticated
using ((select public.has_absolute_view((select auth.uid()))));

revoke all on public.platform_incidents from anon, authenticated;
revoke all on public.security_detection_rules from anon, authenticated;
revoke all on public.security_alerts from anon, authenticated;
grant select on public.platform_incidents to authenticated;
grant select on public.security_detection_rules to authenticated;
grant select on public.security_alerts to authenticated;
grant all on public.platform_incidents to service_role;
grant all on public.security_detection_rules to service_role;
grant all on public.security_alerts to service_role;

-- ---------------------------------------------------------------------------
-- 3) Server-side incident aggregation for real client failures
-- ---------------------------------------------------------------------------
create or replace function private.sync_client_error_incident()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_incident_key text := 'client_error:' || new.fingerprint;
  v_rule public.security_detection_rules%rowtype;
  v_rule_found boolean := false;
  v_flag_key text;
  v_did_repair boolean := false;
  v_repair_result jsonb := '{}'::jsonb;
begin
  insert into public.platform_incidents (
    incident_key, category, severity, title, summary, source,
    first_seen_at, last_seen_at, occurrences, affected_users,
    last_user_id, last_screen, last_app_version, last_platform,
    remediation_key, remediation_status, evidence, created_at, updated_at
  ) values (
    v_incident_key, 'client_error', new.severity,
    left(new.message, 240),
    left(coalesce(new.details, ''), 1800),
    left(coalesce(new.source, 'client'), 160),
    new.first_seen_at, new.last_seen_at, new.occurrences,
    new.affected_users, new.last_user_id, new.screen, new.app_version,
    new.platform, null, 'not_applicable',
    jsonb_build_object('fingerprint', new.fingerprint, 'resolved', new.resolved),
    coalesce(new.first_seen_at, now()), now()
  )
  on conflict (incident_key) do update set
    severity = excluded.severity,
    title = excluded.title,
    summary = excluded.summary,
    source = excluded.source,
    last_seen_at = excluded.last_seen_at,
    occurrences = excluded.occurrences,
    affected_users = excluded.affected_users,
    last_user_id = excluded.last_user_id,
    last_screen = excluded.last_screen,
    last_app_version = excluded.last_app_version,
    last_platform = excluded.last_platform,
    evidence = excluded.evidence,
    updated_at = now();

  -- Safe online repair is intentionally allow-listed. It can only disable a
  -- feature flag explicitly bound to a server-side rule; it cannot edit code,
  -- grant privilege, change money, or modify auth policy.
  select * into v_rule
  from public.security_detection_rules
  where enabled = true
    and event_type = 'client_error'
    and (rule_key = new.source or rule_key = v_incident_key)
  order by updated_at desc
  limit 1;
  v_rule_found := found;

  if v_rule_found
     and new.severity in ('error','fatal','critical')
     and new.occurrences >= v_rule.min_occurrences
     and v_rule.remediation_key = 'disable_feature_flag'
     and v_rule.remediation_config ? 'flag_key' then
    v_flag_key := nullif(trim(v_rule.remediation_config->>'flag_key'), '');
    if v_flag_key is not null then
      update public.feature_flags
      set is_enabled = false,
          updated_at = now(),
          updated_by = null
      where flag_key = v_flag_key
        and is_enabled = true;

      if found then
        v_did_repair := true;
        v_repair_result := jsonb_build_object(
          'ok', true,
          'action', 'disable_feature_flag',
          'flag_key', v_flag_key,
          'trigger', new.fingerprint
        );
        insert into public.audit_logs(
          action, resource_type, resource_id, metadata,
          created_at, target_id, request_id, result
        ) values (
          'auto_safe_remediation', 'feature_flag', v_flag_key,
          jsonb_build_object('rule_key', v_rule.rule_key, 'fingerprint', new.fingerprint),
          now(), v_flag_key, gen_random_uuid(), 'succeeded'
        );
      end if;
    end if;
  end if;

  if v_did_repair then
    update public.platform_incidents
    set remediation_key = v_rule.remediation_key,
        remediation_status = 'succeeded',
        remediation_attempts = remediation_attempts + 1,
        last_remediation_at = now(),
        remediation_result = v_repair_result,
        updated_at = now()
    where incident_key = v_incident_key;
  elsif v_rule_found and v_rule.remediation_key is not null then
    update public.platform_incidents
    set remediation_key = v_rule.remediation_key,
        remediation_status = 'blocked',
        remediation_attempts = remediation_attempts + 1,
        last_remediation_at = now(),
        remediation_result = jsonb_build_object(
          'ok', false,
          'reason', 'NO_SAFE_MATCH',
          'rule_key', v_rule.rule_key
        ),
        updated_at = now()
    where incident_key = v_incident_key;
  end if;

  return new;
end;
$$;

revoke all on function private.sync_client_error_incident() from public, anon, authenticated;

drop trigger if exists trg_client_error_incident on public.client_error_logs;
create trigger trg_client_error_incident
after insert or update of occurrences, affected_users, last_seen_at, resolved
on public.client_error_logs
for each row execute function private.sync_client_error_incident();

-- ---------------------------------------------------------------------------
-- 4) Server-side security event to incident/alert pipeline
-- ---------------------------------------------------------------------------
create or replace function private.sync_security_event_alert()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if lower(coalesce(new.severity,'')) in ('error','fatal','critical') then
    insert into public.platform_incidents (
      incident_key, category, severity, title, summary, source,
      last_user_id, last_seen_at, occurrences, affected_users,
      evidence, created_at, updated_at
    ) values (
      'security_event:' || new.id::text,
      'security',
      case when lower(new.severity) = 'critical' then 'critical'
           when lower(new.severity) = 'fatal' then 'fatal'
           else 'error' end,
      left(coalesce(new.event_type, 'security event'), 240),
      left(coalesce(new.description, ''), 1800),
      'security_events',
      new.user_id, new.created_at, 1,
      case when new.user_id is null then 0 else 1 end,
      coalesce(new.metadata, '{}'::jsonb),
      new.created_at, now()
    )
    on conflict (incident_key) do nothing;

    insert into public.security_alerts (
      alert_key, event_type, severity, user_id, source,
      evidence, created_at
    ) values (
      'security_event:' || new.id::text,
      new.event_type,
      case when lower(new.severity) = 'critical' then 'critical'
           when lower(new.severity) = 'fatal' then 'fatal'
           else 'error' end,
      new.user_id,
      'security_events',
      coalesce(new.metadata, '{}'::jsonb) || jsonb_build_object(
        'description', new.description,
        'event_id', new.id
      ),
      new.created_at
    )
    on conflict (alert_key) do nothing;
  end if;

  return new;
end;
$$;

revoke all on function private.sync_security_event_alert() from public, anon, authenticated;

drop trigger if exists trg_security_event_alert on public.security_events;
create trigger trg_security_event_alert
after insert on public.security_events
for each row execute function private.sync_security_event_alert();

-- ---------------------------------------------------------------------------
-- 5) Owner-only rule management. All automated actions remain allow-listed.
-- ---------------------------------------------------------------------------
create or replace function public.admin_upsert_security_detection_rule(
  p_rule_key text,
  p_name_ar text,
  p_description_ar text,
  p_event_type text,
  p_min_occurrences integer,
  p_window_seconds integer,
  p_risk_delta integer,
  p_enabled boolean,
  p_remediation_key text,
  p_remediation_config jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_rule public.security_detection_rules%rowtype;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.has_absolute_view(v_uid) then raise exception 'FORBIDDEN'; end if;

  if trim(coalesce(p_rule_key,'')) = '' then raise exception 'RULE_KEY_REQUIRED'; end if;
  if p_event_type not in ('client_error','security_event','integrity') then
    raise exception 'UNSUPPORTED_EVENT_TYPE';
  end if;
  if p_remediation_key is not null
     and p_remediation_key <> 'disable_feature_flag' then
    raise exception 'UNSUPPORTED_REMEDIATION';
  end if;
  if p_remediation_key = 'disable_feature_flag'
     and not (coalesce(p_remediation_config,'{}'::jsonb) ? 'flag_key') then
    raise exception 'FLAG_KEY_REQUIRED';
  end if;

  insert into public.security_detection_rules(
    rule_key, name_ar, description_ar, event_type,
    min_occurrences, window_seconds, risk_delta, enabled,
    remediation_key, remediation_config, updated_by, updated_at
  ) values (
    trim(p_rule_key), left(trim(p_name_ar),160), left(nullif(trim(p_description_ar),''),500),
    p_event_type, greatest(1, least(coalesce(p_min_occurrences,1), 100000)),
    greatest(30, least(coalesce(p_window_seconds,300), 86400)),
    greatest(0, least(coalesce(p_risk_delta,0),100)),
    coalesce(p_enabled,true), p_remediation_key,
    coalesce(p_remediation_config,'{}'::jsonb), v_uid, now()
  )
  on conflict (rule_key) do update set
    name_ar = excluded.name_ar,
    description_ar = excluded.description_ar,
    event_type = excluded.event_type,
    min_occurrences = excluded.min_occurrences,
    window_seconds = excluded.window_seconds,
    risk_delta = excluded.risk_delta,
    enabled = excluded.enabled,
    remediation_key = excluded.remediation_key,
    remediation_config = excluded.remediation_config,
    updated_by = v_uid,
    updated_at = now()
  returning * into v_rule;

  perform public.write_audit(
    'security_detection_rule_upsert',
    v_rule.rule_key,
    gen_random_uuid(),
    'succeeded',
    jsonb_build_object('event_type', v_rule.event_type, 'remediation_key', v_rule.remediation_key)
  );

  return jsonb_build_object(
    'ok', true,
    'rule_key', v_rule.rule_key,
    'enabled', v_rule.enabled,
    'remediation_key', v_rule.remediation_key
  );
end;
$$;

revoke all on function public.admin_upsert_security_detection_rule(text,text,text,text,integer,integer,integer,boolean,text,jsonb)
from public, anon, authenticated;
grant execute on function public.admin_upsert_security_detection_rule(text,text,text,text,integer,integer,integer,boolean,text,jsonb)
to authenticated;

-- Re-surface all previously aggregated errors as incidents without inventing data.
insert into public.platform_incidents (
  incident_key, category, severity, title, summary, source,
  first_seen_at, last_seen_at, occurrences, affected_users,
  last_user_id, last_screen, last_app_version, last_platform,
  evidence, created_at, updated_at
)
select
  'client_error:' || e.fingerprint,
  'client_error', e.severity,
  left(e.message,240), left(coalesce(e.details,''),1800), left(coalesce(e.source,'client'),160),
  e.first_seen_at, e.last_seen_at, e.occurrences, e.affected_users,
  e.last_user_id, e.screen, e.app_version, e.platform,
  jsonb_build_object('fingerprint', e.fingerprint, 'resolved', e.resolved),
  e.first_seen_at, now()
from public.client_error_logs e
on conflict (incident_key) do update set
  severity = excluded.severity,
  title = excluded.title,
  summary = excluded.summary,
  source = excluded.source,
  last_seen_at = excluded.last_seen_at,
  occurrences = excluded.occurrences,
  affected_users = excluded.affected_users,
  last_user_id = excluded.last_user_id,
  last_screen = excluded.last_screen,
  last_app_version = excluded.last_app_version,
  last_platform = excluded.last_platform,
  evidence = excluded.evidence,
  updated_at = now();
