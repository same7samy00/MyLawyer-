-- The nearest available lawyers are read straight from an index that is ordered by distance, so a request
-- touches about 20 lawyers instead of every available lawyer inside its circle (2026-11-11).
-- The longitude is shrunk by cos(30 degrees), Egypt's middle, so one degree means about the same distance both ways.
CREATE INDEX IF NOT EXISTS idx_lawyer_profiles_near
  ON lawyer_profiles USING gist (point((longitude::float8) * 0.866, latitude::float8))
  WHERE is_available = TRUE;

-- The sweep reads the available lawyers every few seconds
CREATE INDEX IF NOT EXISTS idx_lawyer_profiles_available ON lawyer_profiles (user_id) WHERE is_available = TRUE;

-- Replaced by the index above, a copy of the showcase index, and an index on last_active_at that made every
-- «still here» from a lawyer's phone rewrite all the indexes of the row
DROP INDEX IF EXISTS idx_lawyer_profiles_map;
DROP INDEX IF EXISTS idx_lawyer_profiles_coords;
DROP INDEX IF EXISTS idx_lawyer_profiles_availability;
