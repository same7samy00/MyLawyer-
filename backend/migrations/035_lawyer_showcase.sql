-- The lawyers map shows every approved lawyer, and its list shows the top rated in each governorate.
-- The governorate is worked out on the server from the lawyer's saved place, again whenever the place changes.
ALTER TABLE lawyer_profiles ADD COLUMN IF NOT EXISTS governorate VARCHAR(40) NULL;
ALTER TABLE lawyer_profiles ADD COLUMN IF NOT EXISTS governorate_at TIMESTAMPTZ NULL;
CREATE INDEX IF NOT EXISTS idx_lawyer_profiles_showcase ON lawyer_profiles (latitude, longitude) WHERE approval_status = 'approved';
CREATE INDEX IF NOT EXISTS idx_lawyer_profiles_governorate ON lawyer_profiles (governorate, rating DESC) WHERE approval_status = 'approved';
