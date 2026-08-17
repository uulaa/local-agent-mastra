-- Demo seed data for the local AI agent.
-- Runs automatically on first `docker compose up` (postgres init script).
-- 12 tables, 100+ rows each, generated procedurally so dates are always
-- relative to "today" (e.g. "last month's sales" always has data).
--
-- Pattern note: per-row random draws that are reused across columns are
-- computed in an inner subquery over generate_series. Volatile functions in
-- a subquery's target list prevent pull-up, so they are evaluated per row
-- (an uncorrelated LATERAL would be evaluated only once).

SELECT setseed(0.42);

-- ────────────────────────────────────────────────────────────────────────
-- 1. billing_plans (5 tiers × 2 periods × 3 regions × 6 versions = 180)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE billing_plans (
  plan_id        INT PRIMARY KEY,
  name           TEXT NOT NULL,
  tier           TEXT NOT NULL,
  billing_period TEXT NOT NULL,
  price          NUMERIC(10, 2) NOT NULL,
  currency       TEXT NOT NULL DEFAULT 'USD',
  max_seats      INT NOT NULL,
  is_active      BOOLEAN NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL
);

INSERT INTO billing_plans
SELECT
  ROW_NUMBER() OVER (ORDER BY t.tier, p.period, r.region, v.version),
  t.tier
    || CASE p.period WHEN 'yearly' THEN ' Annual' ELSE '' END
    || CASE r.region WHEN 'Global' THEN '' ELSE ' (' || r.region || ')' END
    || ' v' || v.version,
  t.tier,
  p.period,
  ROUND((t.base_price
         * CASE p.period WHEN 'yearly' THEN 10 ELSE 1 END
         * (1 + v.version * 0.05)
         * CASE r.region WHEN 'EU' THEN 1.1 WHEN 'APAC' THEN 0.9 ELSE 1 END)::numeric, 2),
  CASE r.region WHEN 'EU' THEN 'EUR' ELSE 'USD' END,
  t.seats,
  v.version = 6,                       -- only the latest version is active
  NOW() - ((7 - v.version) * 120 || ' days')::interval
FROM (VALUES ('Starter', 19.0, 5), ('Growth', 49.0, 20), ('Business', 99.0, 50),
             ('Pro', 199.0, 200), ('Enterprise', 499.0, 1000)) AS t(tier, base_price, seats)
CROSS JOIN (VALUES ('monthly'), ('yearly')) AS p(period)
CROSS JOIN (VALUES ('Global'), ('EU'), ('APAC')) AS r(region)
CROSS JOIN generate_series(1, 6) AS v(version);

-- ────────────────────────────────────────────────────────────────────────
-- 2. customers (300)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE customers (
  customer_id  INT PRIMARY KEY,
  company_name TEXT NOT NULL,
  contact_name TEXT NOT NULL,
  email        TEXT NOT NULL UNIQUE,
  phone        TEXT NOT NULL,
  country      TEXT NOT NULL,
  city         TEXT NOT NULL,
  segment      TEXT NOT NULL,
  status       TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL
);

INSERT INTO customers
SELECT
  g,
  (ARRAY['Blue','Nova','Prime','Apex','Cedar','Golden','Iron','Silver','Vertex','Lumen',
         'North','Delta','Echo','Falcon','Orbit','Pioneer','Quantum','Ridge','Summit','Terra'])[pi]
    || (ARRAY['Tech','Soft','Data','Logic','Works','Labs','Systems','Trade','Media','Foods',
              'Energy','Motors','Build','Care','Finance','Retail','Cloud','Mining','Textile','Logistics'])[ci]
    || ' ' || (ARRAY['LLC','Inc','Ltd','Group','Co'])[si],
  (ARRAY['James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','David','Elizabeth',
         'William','Barbara','Richard','Susan','Joseph','Jessica','Thomas','Sarah','Daniel','Karen'])[fi]
    || ' ' ||
  (ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez',
         'Anderson','Taylor','Thomas','Moore','Jackson','Martin','Lee','Thompson','White','Harris'])[li],
  LOWER((ARRAY['James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','David','Elizabeth',
               'William','Barbara','Richard','Susan','Joseph','Jessica','Thomas','Sarah','Daniel','Karen'])[fi]
        || '.' ||
        (ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez',
               'Anderson','Taylor','Thomas','Moore','Jackson','Martin','Lee','Thompson','White','Harris'])[li])
    || g || '@example.com',
  '+1-555-' || LPAD((1000 + FLOOR(random()*9000))::int::text, 4, '0'),
  (ARRAY['USA','USA','Germany','UK','Japan','Mongolia','Korea','Singapore','Australia','Canada'])[loci],
  (ARRAY['New York','San Francisco','Berlin','London','Tokyo','Ulaanbaatar','Seoul','Singapore','Sydney','Toronto'])[loci],
  (ARRAY['enterprise','mid-market','smb','startup'])[1 + FLOOR(random()*4)::int],
  CASE WHEN r1 < 0.85 THEN 'active' WHEN r2 < 0.6 THEN 'churned' ELSE 'prospect' END,
  NOW() - (random() * 900 * 86400)::int * INTERVAL '1 second'
FROM (
  SELECT g,
         1 + FLOOR(random()*20)::int AS pi,
         1 + FLOOR(random()*20)::int AS ci,
         1 + FLOOR(random()*5)::int  AS si,
         1 + FLOOR(random()*20)::int AS fi,
         1 + FLOOR(random()*20)::int AS li,
         1 + FLOOR(random()*10)::int AS loci,
         random() AS r1,
         random() AS r2
  FROM generate_series(1, 300) AS g
) sub;

-- ────────────────────────────────────────────────────────────────────────
-- 3. users (600: ids 1–550 belong to customers, 551–600 internal staff)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE users (
  user_id       INT PRIMARY KEY,
  customer_id   INT REFERENCES customers(customer_id),
  full_name     TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  role          TEXT NOT NULL,
  is_active     BOOLEAN NOT NULL,
  last_login_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL
);

INSERT INTO users
SELECT
  g,
  CASE WHEN g <= 550 THEN cid END,
  (ARRAY['James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','David','Elizabeth',
         'Bat-Erdene','Khulan','Temuulen','Anu','Sarnai','Jessica','Thomas','Sarah','Daniel','Karen'])[fi]
    || ' ' ||
  (ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Bold','Ganbold',
         'Anderson','Taylor','Thomas','Moore','Jackson','Martin','Lee','Thompson','White','Harris'])[li],
  LOWER((ARRAY['James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','David','Elizabeth',
               'Bat-Erdene','Khulan','Temuulen','Anu','Sarnai','Jessica','Thomas','Sarah','Daniel','Karen'])[fi]
        || '.' ||
        (ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Bold','Ganbold',
               'Anderson','Taylor','Thomas','Moore','Jackson','Martin','Lee','Thompson','White','Harris'])[li])
    || g || CASE WHEN g <= 550 THEN '@client.example.com' ELSE '@novatech.example.com' END,
  CASE
    WHEN g > 550 THEN (ARRAY['sales_rep','account_manager','support_agent'])[1 + FLOOR(random()*3)::int]
    ELSE (ARRAY['admin','billing_manager','member','viewer'])[1 + FLOOR(random()*4)::int]
  END,
  random() < 0.9,
  CASE WHEN random() < 0.8 THEN NOW() - (random() * 30 * 86400)::int * INTERVAL '1 second' END,
  NOW() - (random() * 700 * 86400)::int * INTERVAL '1 second'
FROM (
  SELECT g,
         1 + FLOOR(random()*300)::int AS cid,
         1 + FLOOR(random()*20)::int  AS fi,
         1 + FLOOR(random()*20)::int  AS li
  FROM generate_series(1, 600) AS g
) sub;

-- ────────────────────────────────────────────────────────────────────────
-- 4. products (150)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE products (
  product_id     INT PRIMARY KEY,
  sku            TEXT NOT NULL UNIQUE,
  name           TEXT NOT NULL,
  category       TEXT NOT NULL,
  unit_price     NUMERIC(10, 2) NOT NULL,
  cost           NUMERIC(10, 2) NOT NULL,
  stock_quantity INT NOT NULL,
  is_active      BOOLEAN NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL
);

INSERT INTO products
SELECT
  g,
  'SKU-' || LPAD(g::text, 5, '0'),
  (ARRAY['Cloud','Edge','Smart','Rapid','Secure','Flex','Core','Ultra','Nano','Hyper'])[1 + FLOOR(random()*10)::int]
    || ' ' ||
  (ARRAY['Analytics Module','Storage Pack','API Gateway','Dashboard','Backup Service','Monitoring Suite',
         'Security Add-on','Data Connector','Report Builder','Support Package','License Seat','Compute Unit'])[1 + FLOOR(random()*12)::int]
    || ' #' || g,
  (ARRAY['software','hardware','service','subscription','support'])[1 + FLOOR(random()*5)::int],
  p,
  ROUND(p * (0.3 + random()*0.4)::numeric, 2),
  FLOOR(random()*500)::int,
  random() < 0.9,
  NOW() - (random() * 900 * 86400)::int * INTERVAL '1 second'
FROM (
  SELECT g, ROUND((10 + random()*990)::numeric, 2) AS p
  FROM generate_series(1, 150) AS g
) sub;

-- ────────────────────────────────────────────────────────────────────────
-- 5. subscriptions (350)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE subscriptions (
  subscription_id      INT PRIMARY KEY,
  customer_id          INT NOT NULL REFERENCES customers(customer_id),
  plan_id              INT NOT NULL REFERENCES billing_plans(plan_id),
  status               TEXT NOT NULL,
  started_at           DATE NOT NULL,
  current_period_start DATE NOT NULL,
  current_period_end   DATE NOT NULL,
  canceled_at          DATE
);

INSERT INTO subscriptions
SELECT
  g,
  1 + FLOOR(random()*300)::int,
  1 + FLOOR(random()*180)::int,
  status,
  d,
  DATE_TRUNC('month', CURRENT_DATE)::date,
  (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month')::date,
  CASE WHEN status = 'canceled' THEN d + (30 + random()*300)::int END
FROM (
  SELECT g,
         (CURRENT_DATE - (random()*700)::int) AS d,
         CASE
           WHEN random() < 0.70 THEN 'active'
           WHEN random() < 0.50 THEN 'canceled'
           WHEN random() < 0.50 THEN 'past_due'
           ELSE 'trialing'
         END AS status
  FROM generate_series(1, 350) AS g
) sub;

-- ────────────────────────────────────────────────────────────────────────
-- 6. invoices (1200; totals are filled in from invoice_items below)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE invoices (
  invoice_id      INT PRIMARY KEY,
  customer_id     INT NOT NULL REFERENCES customers(customer_id),
  subscription_id INT REFERENCES subscriptions(subscription_id),
  invoice_number  TEXT NOT NULL UNIQUE,
  issue_date      DATE NOT NULL,
  due_date        DATE NOT NULL,
  status          TEXT NOT NULL,
  subtotal        NUMERIC(12, 2) NOT NULL DEFAULT 0,
  tax             NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total           NUMERIC(12, 2) NOT NULL DEFAULT 0,
  currency        TEXT NOT NULL DEFAULT 'USD'
);

INSERT INTO invoices (invoice_id, customer_id, subscription_id, invoice_number,
                      issue_date, due_date, status)
SELECT
  g,
  1 + FLOOR(random()*300)::int,
  CASE WHEN random() < 0.7 THEN 1 + FLOOR(random()*350)::int END,
  'INV-' || LPAD(g::text, 6, '0'),
  d,
  d + 14,
  CASE
    WHEN random() < 0.70 THEN 'paid'
    WHEN random() < 0.50 THEN 'open'
    WHEN random() < 0.65 THEN 'overdue'
    ELSE 'void'
  END
FROM (
  SELECT g, (CURRENT_DATE - (random()*540)::int) AS d
  FROM generate_series(1, 1200) AS g
) sub;

-- ────────────────────────────────────────────────────────────────────────
-- 7. invoice_items (3000; every invoice gets ≥1 item, then extras)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE invoice_items (
  item_id     INT PRIMARY KEY,
  invoice_id  INT NOT NULL REFERENCES invoices(invoice_id),
  product_id  INT NOT NULL REFERENCES products(product_id),
  description TEXT NOT NULL,
  quantity    INT NOT NULL,
  unit_price  NUMERIC(10, 2) NOT NULL,
  amount      NUMERIC(12, 2) NOT NULL
);

INSERT INTO invoice_items
SELECT
  g,
  inv_id,
  pr.product_id,
  pr.name,
  q,
  pr.unit_price,
  ROUND(q * pr.unit_price, 2)
FROM (
  SELECT g,
         CASE WHEN g <= 1200 THEN g ELSE 1 + FLOOR(random()*1200)::int END AS inv_id,
         1 + FLOOR(random()*150)::int AS pid,
         1 + FLOOR(random()*10)::int  AS q
  FROM generate_series(1, 3000) AS g
) sub
JOIN products pr ON pr.product_id = sub.pid;

UPDATE invoices i
SET subtotal = agg.s,
    tax      = ROUND(agg.s * 0.10, 2),
    total    = agg.s + ROUND(agg.s * 0.10, 2)
FROM (SELECT invoice_id, SUM(amount) AS s FROM invoice_items GROUP BY invoice_id) agg
WHERE agg.invoice_id = i.invoice_id;

-- ────────────────────────────────────────────────────────────────────────
-- 8. payments (one per paid invoice, ~840)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE payments (
  payment_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  invoice_id  INT NOT NULL REFERENCES invoices(invoice_id),
  customer_id INT NOT NULL REFERENCES customers(customer_id),
  paid_at     DATE NOT NULL,
  amount      NUMERIC(12, 2) NOT NULL,
  method      TEXT NOT NULL,
  status      TEXT NOT NULL,
  reference   TEXT NOT NULL
);

INSERT INTO payments (invoice_id, customer_id, paid_at, amount, method, status, reference)
SELECT
  invoice_id,
  customer_id,
  issue_date + (random()*13)::int,
  total,
  (ARRAY['card','bank_transfer','paypal','wire'])[1 + FLOOR(random()*4)::int],
  'succeeded',
  'PAY-' || LPAD(invoice_id::text, 6, '0')
FROM invoices
WHERE status = 'paid';

-- ────────────────────────────────────────────────────────────────────────
-- 9. transactions (2000, ledger-style events)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE transactions (
  transaction_id INT PRIMARY KEY,
  customer_id    INT NOT NULL REFERENCES customers(customer_id),
  type           TEXT NOT NULL,
  amount         NUMERIC(12, 2) NOT NULL,
  currency       TEXT NOT NULL DEFAULT 'USD',
  status         TEXT NOT NULL,
  description    TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL
);

INSERT INTO transactions
SELECT
  g,
  1 + FLOOR(random()*300)::int,
  type,
  CASE WHEN type = 'refund' THEN -a ELSE a END,
  'USD',
  CASE WHEN random() < 0.9 THEN 'completed' WHEN random() < 0.5 THEN 'pending' ELSE 'failed' END,
  INITCAP(type) || ' — '
    || (ARRAY['monthly subscription','product purchase','plan upgrade','service fee','usage overage','manual adjustment'])[1 + FLOOR(random()*6)::int],
  NOW() - (random() * 540 * 86400)::int * INTERVAL '1 second'
FROM (
  SELECT g,
         (ARRAY['charge','charge','charge','refund','credit','adjustment'])[1 + FLOOR(random()*6)::int] AS type,
         ROUND((5 + random()*1995)::numeric, 2) AS a
  FROM generate_series(1, 2000) AS g
) sub;

-- ────────────────────────────────────────────────────────────────────────
-- 10. sales (2500; the "last month's sales" table)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE sales (
  sale_id      INT PRIMARY KEY,
  customer_id  INT NOT NULL REFERENCES customers(customer_id),
  product_id   INT NOT NULL REFERENCES products(product_id),
  sales_rep_id INT REFERENCES users(user_id),
  sale_date    DATE NOT NULL,
  quantity     INT NOT NULL,
  unit_price   NUMERIC(10, 2) NOT NULL,
  total_amount NUMERIC(12, 2) NOT NULL,
  region       TEXT NOT NULL,
  channel      TEXT NOT NULL
);

INSERT INTO sales
SELECT
  g,
  1 + FLOOR(random()*300)::int,
  pr.product_id,
  551 + FLOOR(random()*50)::int,           -- internal staff user_ids 551–600
  CURRENT_DATE - (random()*540)::int,
  q,
  pr.unit_price,
  ROUND(q * pr.unit_price, 2),
  (ARRAY['North America','Europe','Asia Pacific','Latin America'])[1 + FLOOR(random()*4)::int],
  (ARRAY['online','direct','partner','reseller'])[1 + FLOOR(random()*4)::int]
FROM (
  SELECT g,
         1 + FLOOR(random()*150)::int AS pid,
         1 + FLOOR(random()*20)::int  AS q
  FROM generate_series(1, 2500) AS g
) sub
JOIN products pr ON pr.product_id = sub.pid;

-- ────────────────────────────────────────────────────────────────────────
-- 11. usage_logs (5000)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE usage_logs (
  log_id      INT PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(user_id),
  customer_id INT REFERENCES customers(customer_id),
  event_type  TEXT NOT NULL,
  feature     TEXT NOT NULL,
  quantity    INT NOT NULL,
  logged_at   TIMESTAMPTZ NOT NULL
);

INSERT INTO usage_logs
SELECT
  g,
  u.user_id,
  u.customer_id,
  (ARRAY['login','api_call','report_generated','data_export','file_upload','dashboard_view'])[1 + FLOOR(random()*6)::int],
  (ARRAY['analytics','billing','reports','api','storage','admin'])[1 + FLOOR(random()*6)::int],
  1 + FLOOR(random()*100)::int,
  NOW() - (random() * 180 * 86400)::int * INTERVAL '1 second'
FROM (
  SELECT g, 1 + FLOOR(random()*550)::int AS uid
  FROM generate_series(1, 5000) AS g
) sub
JOIN users u ON u.user_id = sub.uid;

-- ────────────────────────────────────────────────────────────────────────
-- 12. support_tickets (400)
-- ────────────────────────────────────────────────────────────────────────
CREATE TABLE support_tickets (
  ticket_id   INT PRIMARY KEY,
  customer_id INT NOT NULL REFERENCES customers(customer_id),
  assigned_to INT REFERENCES users(user_id),
  subject     TEXT NOT NULL,
  category    TEXT NOT NULL,
  priority    TEXT NOT NULL,
  status      TEXT NOT NULL,
  opened_at   TIMESTAMPTZ NOT NULL,
  closed_at   TIMESTAMPTZ
);

INSERT INTO support_tickets
SELECT
  g,
  1 + FLOOR(random()*300)::int,
  551 + FLOOR(random()*50)::int,
  (ARRAY['Cannot access','Question about','Error in','Request to change','Problem with'])[1 + FLOOR(random()*5)::int]
    || ' ' ||
  (ARRAY['invoice','billing portal','API integration','subscription','payment method','report export','user permissions'])[1 + FLOOR(random()*7)::int],
  (ARRAY['billing','technical','account','feature_request'])[1 + FLOOR(random()*4)::int],
  (ARRAY['low','medium','medium','high','urgent'])[1 + FLOOR(random()*5)::int],
  s,
  t,
  CASE WHEN s IN ('resolved','closed') THEN t + (random() * 14 * 86400)::int * INTERVAL '1 second' END
FROM (
  SELECT g,
         NOW() - (random() * 365 * 86400)::int * INTERVAL '1 second' AS t,
         (ARRAY['open','in_progress','resolved','resolved','closed','closed'])[1 + FLOOR(random()*6)::int] AS s
  FROM generate_series(1, 400) AS g
) sub;

-- ────────────────────────────────────────────────────────────────────────
-- Indexes on common join/filter columns
-- ────────────────────────────────────────────────────────────────────────
CREATE INDEX idx_invoices_customer   ON invoices(customer_id);
CREATE INDEX idx_invoices_issue_date ON invoices(issue_date);
CREATE INDEX idx_items_invoice       ON invoice_items(invoice_id);
CREATE INDEX idx_payments_invoice    ON payments(invoice_id);
CREATE INDEX idx_sales_date          ON sales(sale_date);
CREATE INDEX idx_sales_customer      ON sales(customer_id);
CREATE INDEX idx_tx_customer         ON transactions(customer_id);
CREATE INDEX idx_usage_user          ON usage_logs(user_id);
CREATE INDEX idx_subs_customer       ON subscriptions(customer_id);
