-- Tax is taken from the price first, then the platform share from what remains
CREATE TABLE IF NOT EXISTS platform_settings (
    id BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),
    tax_percent NUMERIC(5, 2) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO platform_settings (id) VALUES (TRUE) ON CONFLICT DO NOTHING;

ALTER TABLE service_orders ADD COLUMN IF NOT EXISTS tax_percent NUMERIC(5, 2) NOT NULL DEFAULT 0;

-- A lawyer joins the urgent service by accepting its terms
ALTER TABLE lawyer_profiles ADD COLUMN IF NOT EXISTS urgent_terms_accepted_at TIMESTAMPTZ;
UPDATE lawyer_profiles SET urgent_terms_accepted_at = NOW()
WHERE urgent_terms_accepted_at IS NULL AND approval_status = 'approved';
