-- إشعار الاستشارة بيفتح الاستشارة نفسها لما الموكل يلمسه
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS consultation_id UUID NULL REFERENCES consultations(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_notifications_consultation ON notifications(consultation_id) WHERE consultation_id IS NOT NULL;
