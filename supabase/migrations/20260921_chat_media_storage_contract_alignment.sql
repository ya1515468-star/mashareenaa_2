-- Align production storage MIME contracts with the Flutter upload gateway.
-- chat-media-plus is intentionally kept service-gated by its existing RLS policies.
update storage.buckets
set allowed_mime_types = ARRAY[
  'image/png','image/jpeg','image/webp','image/gif',
  'video/mp4','video/webm','video/quicktime',
  'audio/mpeg','audio/wav','audio/ogg','audio/mp4','audio/aac','audio/webm',
  'application/pdf','application/zip','application/octet-stream',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain'
]
where id = 'chat-media-plus';

update storage.buckets
set allowed_mime_types = ARRAY[
  'image/png','image/jpeg','image/webp','image/gif',
  'video/mp4','video/webm','video/quicktime',
  'audio/mpeg','audio/wav','audio/ogg','audio/mp4','audio/aac','audio/webm',
  'application/pdf','application/zip','application/octet-stream',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain'
]
where id = 'media';

update storage.buckets
set allowed_mime_types = ARRAY[
  'image/png','image/jpeg','image/webp','image/gif',
  'video/mp4','video/webm','video/quicktime',
  'audio/mpeg','audio/wav','audio/ogg','audio/mp4','audio/aac','audio/webm',
  'application/pdf','application/zip','application/octet-stream',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain'
]
where id = 'store-media';
