begin;
grant usage on schema private_rpc to authenticated, service_role;
grant execute on all functions in schema private_rpc to authenticated, service_role;
commit;
