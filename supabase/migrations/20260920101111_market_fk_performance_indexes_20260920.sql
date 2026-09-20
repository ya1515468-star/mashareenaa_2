create index if not exists idx_producer_reels_business_id on public.producer_reels(business_id);
create index if not exists idx_producer_reels_product_id on public.producer_reels(product_id);
create index if not exists idx_tenders_sector_key on public.tenders(sector_key);
create index if not exists idx_platform_ui_runtime_updated_by on public.platform_ui_runtime(updated_by);
