-- «استشارة سريعة»: الموكل يدفع سعر ثابت، والإدارة تكلمه على تليفونه خلال دقايق.
-- CALL استشارة بس، PAPERS اطلاع على ورق واستشارة (سعر أساسي + سعر لكل ورقة).
-- PAID مستني المكالمة، CONTACTING الإدارة بتكلمه، DONE تمت، REJECTED اترفضت والفلوس رجعت لرصيده.

CREATE TABLE IF NOT EXISTS consultation_settings (
    id BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),
    call_price NUMERIC(10, 2) NOT NULL DEFAULT 200,
    papers_base_price NUMERIC(10, 2) NOT NULL DEFAULT 250,
    page_price NUMERIC(10, 2) NOT NULL DEFAULT 30,
    max_pages INT NOT NULL DEFAULT 10 CHECK (max_pages BETWEEN 1 AND 20),
    call_minutes INT NOT NULL DEFAULT 7 CHECK (call_minutes BETWEEN 1 AND 120),
    min_details_chars INT NOT NULL DEFAULT 50 CHECK (min_details_chars BETWEEN 10 AND 1000),
    is_open BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO consultation_settings (id) VALUES (TRUE) ON CONFLICT (id) DO NOTHING;

CREATE SEQUENCE IF NOT EXISTS ml_consultation_seq START 100001;

CREATE TABLE IF NOT EXISTS consultations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference VARCHAR(32) NOT NULL UNIQUE DEFAULT ('ML-CNS-' || nextval('ml_consultation_seq')),
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    kind VARCHAR(8) NOT NULL CHECK (kind IN ('CALL', 'PAPERS')),
    details TEXT NOT NULL,
    pages INT NOT NULL DEFAULT 0,
    price NUMERIC(10, 2) NOT NULL,
    payment_method VARCHAR(10) NOT NULL CHECK (payment_method IN ('WALLET', 'DIRECT')),
    status VARCHAR(12) NOT NULL DEFAULT 'PAID' CHECK (status IN ('PAID', 'CONTACTING', 'DONE', 'REJECTED')),
    admin_note TEXT NULL,
    reject_reason TEXT NULL,
    handled_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    contacted_at TIMESTAMPTZ NULL,
    closed_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_consultations_client ON consultations(client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_consultations_status ON consultations(status, created_at);

-- صور الورق في التخزين الخاص، وماحدش يشوفها غير صاحبها والإدارة
CREATE TABLE IF NOT EXISTS consultation_pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consultation_id UUID NOT NULL REFERENCES consultations(id) ON DELETE CASCADE,
    file_name VARCHAR(128) NOT NULL,
    mime VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_consultation_pages_consultation ON consultation_pages(consultation_id);
