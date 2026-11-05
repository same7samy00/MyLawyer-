-- The map asks for the lawyers inside the visible area
CREATE INDEX IF NOT EXISTS idx_lawyer_profiles_map ON lawyer_profiles (latitude, longitude) WHERE is_available = TRUE;
