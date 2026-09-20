-- Applied to production as remote migration 20260920085559_market_rpc_only_rls_cleanup.
drop policy if exists producer_reels_owner_update on public.producer_reels;
drop policy if exists producer_reels_owner_delete on public.producer_reels;
drop policy if exists reel_comments_owner_delete on public.reel_comments;
drop policy if exists tender_bids_owner_update on public.tender_bids;
drop policy if exists tenders_owner_update on public.tenders;
drop policy if exists tenders_owner_delete on public.tenders;
drop policy if exists reel_quotas_owner_write on public.reel_membership_quotas;
drop policy if exists tender_quotas_owner_write on public.tender_membership_quotas;
drop policy if exists season_owner_write on public.producers_market_season;
