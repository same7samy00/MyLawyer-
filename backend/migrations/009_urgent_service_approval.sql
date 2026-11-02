-- Lawyers apply to the urgent service, and the control page approves or rejects them
ALTER TABLE lawyer_profiles ADD COLUMN IF NOT EXISTS urgent_status VARCHAR(20) NOT NULL DEFAULT 'NONE';
ALTER TABLE lawyer_profiles ADD COLUMN IF NOT EXISTS urgent_rejection_reason TEXT;
UPDATE lawyer_profiles SET urgent_status = 'APPROVED' WHERE urgent_terms_accepted_at IS NOT NULL;

-- Clients can upload a profile photo too
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_photo_path TEXT;
