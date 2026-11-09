-- The client no longer asks one lawyer by name with a fixed price per client: every request goes to the nearest
-- lawyers and each prices it (2026-11-09). The saved per-client prices and the missed-request counter go.
DROP TABLE IF EXISTS client_problem_prices;
ALTER TABLE lawyer_profiles DROP COLUMN IF EXISTS missed_orders;
