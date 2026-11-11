-- The two accounts Google's app reviewers sign in with (2026-11-11). They are kept apart from real people:
-- the review lawyer never shows on the map or gets a real client's request, and neither account can be
-- deleted or suspended by mistake. The flag is set on the server for those two accounts only.
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_review_account BOOLEAN NOT NULL DEFAULT FALSE;
