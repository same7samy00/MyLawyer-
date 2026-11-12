-- The office services (consultation, papers, contracts) can be told by voice. The app turns the voice into text,
-- the client never sees that text, and the admin does: it may hold recognition mistakes, so the admin sees how it
-- was entered (owner decision 2026-11-12).
ALTER TABLE consultations
  ADD COLUMN IF NOT EXISTS input_method VARCHAR(5) NOT NULL DEFAULT 'TEXT' CHECK (input_method IN ('TEXT', 'VOICE'));
