-- New lawyers used to start at a fixed Cairo point that was never their real place
UPDATE lawyer_profiles
SET latitude = NULL, longitude = NULL
WHERE last_location_updated_at IS NULL
  AND latitude = 30.0444 AND longitude = 31.2357;
