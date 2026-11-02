-- One reminder to rate the lawyer, sent a day after the task ends if the client has not rated yet
ALTER TABLE service_orders ADD COLUMN IF NOT EXISTS review_reminder_sent BOOLEAN NOT NULL DEFAULT FALSE;
