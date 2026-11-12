-- Field services (police report, prosecution, hearing, customary council, government offices): the request is for
-- the client or for another person, and it names the place the lawyer goes to. Kept apart from «محاميك حالاً»
-- so that service keeps its own tables and rules (owner decision 2026-11-12).
CREATE TABLE IF NOT EXISTS field_requests (
    request_id UUID PRIMARY KEY REFERENCES service_requests(id) ON DELETE CASCADE,
    for_other BOOLEAN NOT NULL DEFAULT FALSE,
    person_name VARCHAR(120) NULL,
    relation VARCHAR(60) NULL,
    person_detained BOOLEAN NOT NULL DEFAULT FALSE,
    place_name VARCHAR(255) NOT NULL,
    place_kind VARCHAR(20) NOT NULL CHECK (place_kind IN ('police', 'prosecution', 'court', 'government', 'other')),
    -- A place found by name has a known point. A place the client typed by hand is the client's own point
    place_verified BOOLEAN NOT NULL DEFAULT TRUE,
    arrival_radius_m INTEGER NOT NULL CHECK (arrival_radius_m BETWEEN 50 AND 1000),
    -- Only for another person: the client passes it on, and the lawyer types it when they meet
    handover_code CHAR(4) NULL,
    code_attempts INTEGER NOT NULL DEFAULT 0,
    -- How the arrival was proved: area (the lawyer's phone inside the place), code, or client (the client confirmed)
    arrival_method VARCHAR(10) NULL CHECK (arrival_method IN ('area', 'code', 'client')),
    -- The person refused the lawyer after the meeting. The lawyer still gets the full fee
    refused_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Photos the lawyer keeps as evidence for the admin (police station, reception paper). Never shown to the client
CREATE TABLE IF NOT EXISTS field_proofs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES field_requests(request_id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    file_name VARCHAR(80) NOT NULL,
    mime VARCHAR(60) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_field_proofs_request ON field_proofs(request_id);

-- The prices of the field services the control page sets; the policy report and prosecution rows already exist
INSERT INTO problem_prices (problem_type, min_price, max_price) VALUES
    ('حضور جلسة', 350, 350),
    ('حضور مجلس عرفي', 350, 350),
    ('إجراءات إدارية', 350, 350)
ON CONFLICT (problem_type) DO NOTHING;
