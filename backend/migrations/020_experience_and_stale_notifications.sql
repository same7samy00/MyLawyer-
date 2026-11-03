-- Experience is now typed by the lawyer, so the old automatic 5 years is cleared
ALTER TABLE lawyer_profiles ALTER COLUMN experience_years SET DEFAULT 0;
UPDATE lawyer_profiles SET experience_years = 0;

-- Requests to act that the order has already passed
DELETE FROM notifications n USING service_orders o
WHERE o.id = n.order_id AND (
  (n.title = 'طلب جديد' AND o.status <> 'PENDING')
  OR (n.title = 'المحامي وافق' AND o.status <> 'ACCEPTED')
  OR (n.title = 'الموكل دفع' AND (o.status <> 'ACTIVE' OR o.arrived_at IS NOT NULL))
);
