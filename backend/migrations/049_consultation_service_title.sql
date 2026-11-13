-- The office service the client actually chose on the home page («استشارة قانونية»، «اطلاع على مستندات»،
-- «كتابة عقد أو مستندات»). Two of them share the CALL kind, so the kind alone can't name the order on its card
-- (owner decision 2026-11-13). Older rows stay NULL and the app names them by their kind.
ALTER TABLE consultations
  ADD COLUMN IF NOT EXISTS service_title VARCHAR(80) NULL;
