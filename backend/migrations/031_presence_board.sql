-- "Where I'll be": a public board where lawyers say which courts and places they'll be at on a day,
-- so colleagues who need something there can call or message them. Separate from the app's accounts.
CREATE TABLE IF NOT EXISTS presence_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(80) NOT NULL,
    phone VARCHAR(11) NOT NULL UNIQUE,
    whatsapp VARCHAR(11) NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Only a hash of each sign-in token is kept
CREATE TABLE IF NOT EXISTS presence_sessions (
    token_hash CHAR(64) PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES presence_accounts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_presence_sessions_account ON presence_sessions(account_id);

-- One day in one city, at one or more courts or places
CREATE TABLE IF NOT EXISTS presence_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES presence_accounts(id) ON DELETE CASCADE,
    city VARCHAR(40) NOT NULL,
    places TEXT[] NOT NULL,
    day DATE NOT NULL,
    time_from TIME,
    time_to TIME,
    note VARCHAR(200),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_presence_entries_day ON presence_entries(day);
CREATE INDEX IF NOT EXISTS idx_presence_entries_account ON presence_entries(account_id, day);
