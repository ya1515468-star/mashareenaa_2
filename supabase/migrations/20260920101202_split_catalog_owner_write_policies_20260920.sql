do $$
declare t text;
begin
  foreach t in array array['chat_wallpaper_catalog','garment_sectors','membership_call_minutes'] loop
    execute format('drop policy if exists %I_owner_write on public.%I',t,t);
    execute format('create policy %I_owner_insert on public.%I for insert to public with check ((select private.is_dragon()))',t,t);
    execute format('create policy %I_owner_update on public.%I for update to public using ((select private.is_dragon())) with check ((select private.is_dragon()))',t,t);
    execute format('create policy %I_owner_delete on public.%I for delete to public using ((select private.is_dragon()))',t,t);
  end loop;
end $$;
