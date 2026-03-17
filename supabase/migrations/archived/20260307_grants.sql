-- ARCHIVED on 2026-03-09: original moved to archived/
-- Original: supabase/migrations/20260307_grants.sql
-- Grant minimal read access to anon role so PostgREST exposes endpoints
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO anon;
