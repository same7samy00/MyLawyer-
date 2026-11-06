-- Every change sent on the live line gets a number, so an app that was offline asks only for what it missed
CREATE TABLE IF NOT EXISTS change_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL,
  kind VARCHAR(20) NOT NULL,
  entity_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_change_log_user ON change_log (user_id, id);
CREATE INDEX IF NOT EXISTS idx_change_log_created ON change_log (created_at);
