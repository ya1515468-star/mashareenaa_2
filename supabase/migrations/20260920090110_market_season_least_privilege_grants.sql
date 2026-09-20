-- Applied to production as the next least-privilege grant hardening migration.
revoke references,trigger,truncate on public.producers_market_season from public,anon,authenticated;
