insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('producer-market-media','producer-market-media',false,104857600,array['video/mp4','video/webm','video/quicktime','image/png','image/jpeg','image/webp','image/gif']::text[])
on conflict(id) do update set public=false,file_size_limit=104857600,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists producer_market_media_insert on storage.objects;
create policy producer_market_media_insert on storage.objects for insert to authenticated with check(bucket_id='producer-market-media' and (((storage.foldername(name))[1]='reels' and (storage.foldername(name))[2]=(select auth.uid())::text) or ((storage.foldername(name))[1]='season' and (select private.is_dragon()))));
drop policy if exists producer_market_media_update on storage.objects;
create policy producer_market_media_update on storage.objects for update to authenticated using(bucket_id='producer-market-media' and (((storage.foldername(name))[1]='reels' and (storage.foldername(name))[2]=(select auth.uid())::text) or ((storage.foldername(name))[1]='season' and (select private.is_dragon())))) with check(bucket_id='producer-market-media' and (((storage.foldername(name))[1]='reels' and (storage.foldername(name))[2]=(select auth.uid())::text) or ((storage.foldername(name))[1]='season' and (select private.is_dragon()))));
drop policy if exists producer_market_media_delete on storage.objects;
create policy producer_market_media_delete on storage.objects for delete to authenticated using(bucket_id='producer-market-media' and (((storage.foldername(name))[1]='reels' and (storage.foldername(name))[2]=(select auth.uid())::text) or ((storage.foldername(name))[1]='season' and (select private.is_dragon()))));
