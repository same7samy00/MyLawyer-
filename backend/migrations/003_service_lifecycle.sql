-- ==============================================================================
-- MyLawyer Platform
-- Migration 003: Completion Code, Payout Hold, Complaints, Reviews, Pricing, Notifications
-- ==============================================================================

-- 1. Order lifecycle columns
ALTER TABLE service_orders
    ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS completion_code VARCHAR(4) NULL,
    ADD COLUMN IF NOT EXISTS code_attempts INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS hold_until TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS payout_status VARCHAR(20) NULL,
    ADD COLUMN IF NOT EXISTS payout_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS reminder_first_sent BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS reminder_second_sent BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS commission_percent NUMERIC(5, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS lawyer_amount NUMERIC(10, 2) NULL,
    ADD COLUMN IF NOT EXISTS response_deadline TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS payment_deadline TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS arrived_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS arrived_latitude NUMERIC(10, 7) NULL,
    ADD COLUMN IF NOT EXISTS arrived_longitude NUMERIC(10, 7) NULL;

-- Orders created before this migration follow the new rules
UPDATE service_orders SET lawyer_amount = price WHERE lawyer_amount IS NULL;
UPDATE service_orders SET payout_status = 'AVAILABLE', payout_amount = price
    WHERE status = 'COMPLETED' AND payout_status IS NULL;
UPDATE service_orders SET status = 'NO_RESPONSE' WHERE status = 'PENDING';
UPDATE service_orders SET status = 'PAYMENT_EXPIRED' WHERE status = 'ACCEPTED';
UPDATE service_orders
    SET paid_at = COALESCE(paid_at, updated_at),
        expires_at = NOW() + INTERVAL '24 hours',
        completion_code = lpad((1000 + floor(random() * 9000))::int::text, 4, '0')
    WHERE status = 'ACTIVE' AND completion_code IS NULL;

CREATE INDEX IF NOT EXISTS idx_orders_expires ON service_orders(status, expires_at);
CREATE INDEX IF NOT EXISTS idx_orders_hold ON service_orders(payout_status, hold_until);

-- 2. Complaints. Open complaints freeze the order and its money until an admin decides
CREATE TABLE IF NOT EXISTS complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES service_orders(id) ON DELETE RESTRICT,
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    lawyer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL,
    filed_after_hold BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    resolution VARCHAR(20) NULL,
    refund_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    admin_note TEXT NULL,
    resolved_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_complaints_one_open
    ON complaints(order_id) WHERE status = 'OPEN';
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints(status, created_at);

-- 3. Lawyer appeals on orders closed by the 48 hour deadline
CREATE TABLE IF NOT EXISTS order_appeals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE REFERENCES service_orders(id) ON DELETE RESTRICT,
    lawyer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    admin_note TEXT NULL,
    resolved_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Client balance entries. Refunds stay here until the payment gateway exists
CREATE TABLE IF NOT EXISTS client_credits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    order_id UUID NULL REFERENCES service_orders(id) ON DELETE SET NULL,
    amount NUMERIC(10, 2) NOT NULL,
    reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_client_credits_client ON client_credits(client_id, created_at DESC);

-- 5. Reviews: one per completed order, published after the complaint window
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE REFERENCES service_orders(id) ON DELETE RESTRICT,
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    lawyer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT NULL,
    publish_at TIMESTAMPTZ NOT NULL,
    published_at TIMESTAMPTZ NULL,
    is_hidden BOOLEAN NOT NULL DEFAULT FALSE,
    edited BOOLEAN NOT NULL DEFAULT FALSE,
    report_reason TEXT NULL,
    reported_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reviews_lawyer ON reviews(lawyer_id, published_at DESC);

-- 6. Price range per problem, and the price fixed for each client on first request
CREATE TABLE IF NOT EXISTS problem_prices (
    problem_type VARCHAR(100) PRIMARY KEY,
    min_price NUMERIC(10, 2) NOT NULL,
    max_price NUMERIC(10, 2) NOT NULL,
    commission_percent NUMERIC(5, 2) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (min_price > 0 AND max_price >= min_price),
    CHECK (commission_percent >= 0 AND commission_percent < 100)
);

CREATE TABLE IF NOT EXISTS client_problem_prices (
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    problem_type VARCHAR(100) NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (client_id, problem_type)
);

INSERT INTO problem_prices (problem_type, min_price, max_price) VALUES
    ('محضر في قسم الشرطة', 350, 350),
    ('القبض على شخص أو احتجازه بقسم الشرطة', 350, 350),
    ('تحقيق عاجل في النيابة العامة', 350, 350),
    ('مشاجرة أو اعتداء أو تهديد', 350, 350),
    ('حادث سير أو نزاع مروري طارئ', 350, 350),
    ('كمين أو استيقاف أمني أو فحص هوية', 350, 350),
    ('تفتيش أو ضبط أو التحفظ على ممتلكات', 350, 350),
    ('نزاع حيازة أو طرد أو تمكين', 350, 350),
    ('إثبات حالة أو واقعة عاجلة', 350, 350),
    ('تحقيق إداري أو تأديبي عاجل في العمل', 350, 350),
    ('فصل تعسفي أو مستحقات عمالية متأخرة', 350, 350),
    ('نزاع أسري عاجل أو امتناع عن تنفيذ حكم', 350, 350),
    ('سرقة أو نصب أو احتيال', 350, 350),
    ('مشكلة قانونية أخرى', 350, 350)
ON CONFLICT (problem_type) DO NOTHING;

-- 7. In-app notifications
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    order_id UUID NULL REFERENCES service_orders(id) ON DELETE SET NULL,
    read_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);

-- 8. Ratings now come only from real reviews
ALTER TABLE lawyer_profiles ALTER COLUMN rating SET DEFAULT 0;
UPDATE lawyer_profiles SET rating = 0, reviews_count = 0;

-- 9. Client names, warnings, lawyer response tracking and suspensions
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS full_name VARCHAR(255) NULL,
    ADD COLUMN IF NOT EXISTS warnings_count INT NOT NULL DEFAULT 0;

ALTER TABLE lawyer_profiles
    ADD COLUMN IF NOT EXISTS missed_orders INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS suspended_until TIMESTAMPTZ NULL;

CREATE TABLE IF NOT EXISTS lawyer_strikes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lawyer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NULL REFERENCES service_orders(id) ON DELETE SET NULL,
    kind VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lawyer_strikes ON lawyer_strikes(lawyer_id, kind, created_at);

-- 10. Lawyer reports about clients
CREATE TABLE IF NOT EXISTS lawyer_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES service_orders(id) ON DELETE RESTRICT,
    lawyer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    admin_note TEXT NULL,
    resolved_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
