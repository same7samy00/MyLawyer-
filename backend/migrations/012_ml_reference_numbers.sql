-- One organized numbering for everything: ML, then the kind, then a running number.
-- ML-ORD order, ML-CMP client complaint, ML-RPT lawyer complaint, ML-APL appeal, ML-TRF transfer.
-- Old rows are numbered first by their date, then new rows take the next number automatically.

CREATE SEQUENCE IF NOT EXISTS ml_order_seq;
CREATE SEQUENCE IF NOT EXISTS ml_complaint_seq;
CREATE SEQUENCE IF NOT EXISTS ml_report_seq;
CREATE SEQUENCE IF NOT EXISTS ml_appeal_seq;
CREATE SEQUENCE IF NOT EXISTS ml_transfer_seq;

-- Orders already have a number, so they are renumbered to the new format
WITH numbered AS (SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS n FROM service_orders)
UPDATE service_orders o SET order_number = 'ML-ORD-' || (100000 + numbered.n) FROM numbered WHERE o.id = numbered.id;
SELECT setval('ml_order_seq', 100000 + (SELECT COUNT(*) FROM service_orders));
ALTER TABLE service_orders ALTER COLUMN order_number SET DEFAULT 'ML-ORD-' || nextval('ml_order_seq');

ALTER TABLE complaints ADD COLUMN IF NOT EXISTS reference VARCHAR(32);
WITH numbered AS (SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS n FROM complaints)
UPDATE complaints t SET reference = 'ML-CMP-' || (100000 + numbered.n) FROM numbered WHERE t.id = numbered.id;
SELECT setval('ml_complaint_seq', 100000 + (SELECT COUNT(*) FROM complaints));
ALTER TABLE complaints ALTER COLUMN reference SET DEFAULT 'ML-CMP-' || nextval('ml_complaint_seq');
ALTER TABLE complaints ALTER COLUMN reference SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_complaints_reference ON complaints(reference);

ALTER TABLE lawyer_reports ADD COLUMN IF NOT EXISTS reference VARCHAR(32);
WITH numbered AS (SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS n FROM lawyer_reports)
UPDATE lawyer_reports t SET reference = 'ML-RPT-' || (100000 + numbered.n) FROM numbered WHERE t.id = numbered.id;
SELECT setval('ml_report_seq', 100000 + (SELECT COUNT(*) FROM lawyer_reports));
ALTER TABLE lawyer_reports ALTER COLUMN reference SET DEFAULT 'ML-RPT-' || nextval('ml_report_seq');
ALTER TABLE lawyer_reports ALTER COLUMN reference SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_lawyer_reports_reference ON lawyer_reports(reference);

ALTER TABLE order_appeals ADD COLUMN IF NOT EXISTS reference VARCHAR(32);
WITH numbered AS (SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS n FROM order_appeals)
UPDATE order_appeals t SET reference = 'ML-APL-' || (100000 + numbered.n) FROM numbered WHERE t.id = numbered.id;
SELECT setval('ml_appeal_seq', 100000 + (SELECT COUNT(*) FROM order_appeals));
ALTER TABLE order_appeals ALTER COLUMN reference SET DEFAULT 'ML-APL-' || nextval('ml_appeal_seq');
ALTER TABLE order_appeals ALTER COLUMN reference SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_order_appeals_reference ON order_appeals(reference);

ALTER TABLE wallet_transfers ADD COLUMN IF NOT EXISTS reference VARCHAR(32);
WITH numbered AS (SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS n FROM wallet_transfers)
UPDATE wallet_transfers t SET reference = 'ML-TRF-' || (100000 + numbered.n) FROM numbered WHERE t.id = numbered.id;
SELECT setval('ml_transfer_seq', 100000 + (SELECT COUNT(*) FROM wallet_transfers));
ALTER TABLE wallet_transfers ALTER COLUMN reference SET DEFAULT 'ML-TRF-' || nextval('ml_transfer_seq');
ALTER TABLE wallet_transfers ALTER COLUMN reference SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_wallet_transfers_reference ON wallet_transfers(reference);
