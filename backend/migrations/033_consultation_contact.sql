-- الإدارة ما قدرتش توصل للموكل: بتبعتله تنبيه، وهو يدوس «طلب التواصل» لما يكون متاح
ALTER TABLE consultations ADD COLUMN IF NOT EXISTS unreachable_at TIMESTAMPTZ NULL;
ALTER TABLE consultations ADD COLUMN IF NOT EXISTS callback_requested_at TIMESTAMPTZ NULL;
