-- Production security hardening applied to the production Supabase project.
-- Keeps SECURITY DEFINER implementation functions in private schema,
-- exposes only authenticated invoker wrappers, and makes Google Play
-- purchase receipts server-only.
-- This migration mirrors the live production change applied on 2026-09-21.

begin;

revoke execute on function public.record_signup_legal_acceptance() from public, anon, authenticated;
grant execute on function public.record_signup_legal_acceptance() to postgres;

create or replace function private.accept_required_legal_documents()
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, private, pg_temp
as $function$
declare v_uid uuid := auth.uid(); v_count int;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  insert into public.legal_acceptances(user_id,document_key,document_version)
  select v_uid,d.document_key,d.version from public.legal_documents d
  where d.document_key in ('terms_of_use','community_guidelines','privacy_policy')
  on conflict do nothing;
  select count(*) into v_count
  from public.legal_acceptances a
  join public.legal_documents d on d.document_key=a.document_key and d.version=a.document_version
  where a.user_id=v_uid and d.document_key in ('terms_of_use','community_guidelines')
    and d.is_required_for_ugc=true;
  if v_count < 2 then raise exception 'LEGAL_ACCEPTANCE_FAILED'; end if;
  return jsonb_build_object('ok',true,'terms',true,'community_guidelines',true,'privacy',true);
end;
$function$;

create or replace function public.accept_required_legal_documents()
returns jsonb language plpgsql security invoker
set search_path = pg_catalog, public, private, pg_temp
as $function$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  return private.accept_required_legal_documents();
end;
$function$;

revoke execute on function public.accept_required_legal_documents() from public, anon;
grant execute on function public.accept_required_legal_documents() to authenticated;

create or replace function private.has_current_ugc_legal_acceptance(p_user_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private, pg_temp
as $function$
  select exists (
    select 1 from public.legal_documents t
    join public.legal_acceptances a_t on a_t.document_key=t.document_key
      and a_t.document_version=t.version and a_t.user_id=p_user_id
    where t.document_key='terms_of_use'
  ) and exists (
    select 1 from public.legal_documents g
    join public.legal_acceptances a_g on a_g.document_key=g.document_key
      and a_g.document_version=g.version and a_g.user_id=p_user_id
    where g.document_key='community_guidelines'
  );
$function$;

create or replace function public.has_current_ugc_legal_acceptance(p_user_id uuid default auth.uid())
returns boolean language plpgsql stable security invoker
set search_path = pg_catalog, public, private, pg_temp
as $function$
begin
  if auth.uid() is null or p_user_id is null or p_user_id <> auth.uid() then return false; end if;
  return private.has_current_ugc_legal_acceptance(p_user_id);
end;
$function$;

revoke execute on function public.has_current_ugc_legal_acceptance(uuid) from public, anon;
grant execute on function public.has_current_ugc_legal_acceptance(uuid) to authenticated;

create or replace function private.purge_user_data(p_user_id uuid)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, private, pg_temp
as $function$
declare r record; v_other_owner uuid;
begin
  if p_user_id is null then raise exception 'INVALID_USER'; end if;
  if auth.uid() <> p_user_id and current_user <> 'service_role' then raise exception 'FORBIDDEN'; end if;

  delete from public.user_follows where follower_uid=p_user_id or following_uid=p_user_id;
  delete from public.points_wallets where user_id=p_user_id;
  delete from public.gems_wallets where user_id=p_user_id;
  delete from public.membership_transactions where user_id=p_user_id;
  delete from public.membership_subscriptions where user_id=p_user_id;
  delete from public.google_play_purchase_receipts where user_id=p_user_id;
  delete from public.wallet_transactions where user_id=p_user_id;
  delete from public.purchases where user_id=p_user_id;

  for r in select id from public.chat_rooms where owner_id=p_user_id loop
    select crm.user_id into v_other_owner from public.chat_room_members crm
    where crm.room_id=r.id and crm.user_id<>p_user_id order by crm.user_id limit 1;
    if v_other_owner is null then delete from public.chat_rooms where id=r.id;
    else update public.chat_rooms set owner_id=v_other_owner where id=r.id;
    end if;
  end loop;

  update public.activity_log set actor_id=null where actor_id=p_user_id;
  update public.chat_features set created_by=null where created_by=p_user_id;
  update public.chat_role_permissions set granted_by=null where granted_by=p_user_id;
  update public.chat_room_roles set created_by=null where created_by=p_user_id;
  update public.platform_chat_settings set owner_id=null where owner_id=p_user_id;
  update public.absolute_view_grants set granted_by=null where granted_by=p_user_id;
  update public.points_package_prices set created_by=null where created_by=p_user_id;
  update public.store_item_prices set created_by=null where created_by=p_user_id;
  update public.user_roles set assigned_by=null where assigned_by=p_user_id;
  update public.wallet_transactions set created_by=null where created_by=p_user_id;
  update public.store_items set owner_id=null where owner_id=p_user_id;

  for r in
    select distinct c.table_name,c.column_name from information_schema.columns c
    where c.table_schema='public' and c.data_type='uuid'
      and c.column_name in ('user_id','owner_uid','uid','author_id','sender_id','receiver_id',
        'target_user_id','source_user_id','first_user_id','last_user_id','follower_uid',
        'following_uid','bidder_uid','caller_uid','callee_uid','member_id','member_uid',
        'from_user_id','to_user_id')
      and c.table_name not in ('profiles','user_follows','chat_rooms','activity_log','chat_features',
        'chat_role_permissions','chat_room_roles','platform_chat_settings','absolute_view_grants',
        'points_package_prices','store_item_prices','store_items','points_wallets','gems_wallets',
        'membership_subscriptions','membership_transactions','wallet_transactions','purchases',
        'google_play_purchase_receipts','legal_documents','legal_acceptances','account_deletion_requests',
        'google_play_product_map','points_packages','audit_logs','security_events','security_alerts',
        'platform_incidents')
  loop
    begin
      execute format('delete from public.%I where %I = $1',r.table_name,r.column_name) using p_user_id;
    exception when undefined_table or undefined_column then null;
    end;
  end loop;

  delete from public.app_documents where owner_id=p_user_id or (collection_path='accounts' and doc_id=p_user_id::text);
  update public.account_deletion_requests set status='completed',completed_at=now(),user_id=null,metadata='{}'::jsonb where user_id=p_user_id;
  update public.audit_logs set actor_user_id=null where actor_user_id=p_user_id;
  update public.security_events set user_id=null where user_id=p_user_id;
  update public.security_alerts set user_id=null where user_id=p_user_id;
  update public.platform_incidents set last_user_id=null where last_user_id=p_user_id;
  delete from public.profiles where id=p_user_id;
  return jsonb_build_object('ok',true,'userId',p_user_id,'purged',true);
end;
$function$;

create or replace function public.purge_user_data(p_user_id uuid)
returns jsonb language plpgsql security invoker
set search_path = pg_catalog, public, private, pg_temp
as $function$
begin
  if auth.uid() is null or p_user_id is null or p_user_id <> auth.uid() then raise exception 'FORBIDDEN'; end if;
  return private.purge_user_data(p_user_id);
end;
$function$;

revoke execute on function public.purge_user_data(uuid) from public, anon;
grant execute on function public.purge_user_data(uuid) to authenticated;

revoke all on table public.google_play_purchase_receipts from public, anon, authenticated;
drop policy if exists google_play_purchase_receipts_client_no_read on public.google_play_purchase_receipts;
create policy google_play_purchase_receipts_client_no_read
  on public.google_play_purchase_receipts for select to anon, authenticated using (false);

commit;
