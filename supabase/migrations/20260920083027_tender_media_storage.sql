update storage.buckets
set file_size_limit=104857600,
    allowed_mime_types=array['video/mp4','video/webm','video/quicktime','image/png','image/jpeg','image/webp','image/gif','application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']::text[]
where id='producer-market-media';

drop policy if exists producer_market_media_tender_insert on storage.objects;
create policy producer_market_media_tender_insert on storage.objects
for insert to authenticated
with check(bucket_id='producer-market-media' and (storage.foldername(name))[1]='tenders' and (storage.foldername(name))[2]=(select auth.uid())::text);

drop policy if exists producer_market_media_tender_update on storage.objects;
create policy producer_market_media_tender_update on storage.objects
for update to authenticated
using(bucket_id='producer-market-media' and (storage.foldername(name))[1]='tenders' and (storage.foldername(name))[2]=(select auth.uid())::text)
with check(bucket_id='producer-market-media' and (storage.foldername(name))[1]='tenders' and (storage.foldername(name))[2]=(select auth.uid())::text);

drop policy if exists producer_market_media_tender_delete on storage.objects;
create policy producer_market_media_tender_delete on storage.objects
for delete to authenticated
using(bucket_id='producer-market-media' and (storage.foldername(name))[1]='tenders' and (storage.foldername(name))[2]=(select auth.uid())::text);
