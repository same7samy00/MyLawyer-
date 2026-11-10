-- The road time from each asked lawyer to the client, with traffic, so the offer card shows a real arrival time
-- instead of a straight-line guess (owner decision 2026-11-11). Null until it is known.
ALTER TABLE request_recipients ADD COLUMN IF NOT EXISTS road_seconds INT NULL;
