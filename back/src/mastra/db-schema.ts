/**
 * Human-written schema documentation for the seeded demo database
 * (deployment/postgres/01-init.sql). Injected into the agent's instructions
 * so the model can write correct SQL in one shot without a schema
 * introspection round-trip. Keep in sync with the seed script.
 */
export const DB_SCHEMA = `
Database schema (PostgreSQL, all business data lives in these tables):

- table "customers" — companies that buy from us (300 rows):
  customer_id (int, PK), company_name (text), contact_name (text), email (text),
  phone (text), country (text, e.g. 'USA', 'Mongolia'), city (text),
  segment ('enterprise'/'mid-market'/'smb'/'startup'),
  status ('active'/'churned'/'prospect'), created_at (timestamptz)

- table "users" — people: customer users AND our internal staff:
  user_id (int, PK), customer_id (int, FK→customers, NULL for internal staff),
  full_name (text), email (text),
  role (customer users: 'admin'/'billing_manager'/'member'/'viewer';
        internal staff: 'sales_rep'/'account_manager'/'support_agent'),
  is_active (bool), last_login_at (timestamptz, NULL if never), created_at (timestamptz)

- table "products" — items we sell:
  product_id (int, PK), sku (text), name (text),
  category ('software'/'hardware'/'service'/'subscription'/'support'),
  unit_price (numeric, USD), cost (numeric, USD, our cost),
  stock_quantity (int), is_active (bool), created_at (timestamptz)

- table "billing_plans" — subscription price plans (versioned; is_active=true only for current versions):
  plan_id (int, PK), name (text), tier ('Starter'/'Growth'/'Business'/'Pro'/'Enterprise'),
  billing_period ('monthly'/'yearly'), price (numeric), currency ('USD'/'EUR'),
  max_seats (int), is_active (bool), created_at (timestamptz)

- table "subscriptions" — customer subscriptions to plans:
  subscription_id (int, PK), customer_id (int, FK→customers), plan_id (int, FK→billing_plans),
  status ('active'/'canceled'/'past_due'/'trialing'), started_at (date),
  current_period_start (date), current_period_end (date),
  canceled_at (date, NULL unless canceled)

- table "sales" — individual product sales; USE THIS for revenue/sales questions:
  sale_id (int, PK), customer_id (int, FK→customers), product_id (int, FK→products),
  sales_rep_id (int, FK→users, internal staff), sale_date (date),
  quantity (int), unit_price (numeric, USD),
  total_amount (numeric, USD, = quantity × unit_price),
  region ('North America'/'Europe'/'Asia Pacific'/'Latin America'),
  channel ('online'/'direct'/'partner'/'reseller')

- table "invoices" — issued invoices (totals maintained from invoice_items):
  invoice_id (int, PK), customer_id (int, FK→customers),
  subscription_id (int, FK→subscriptions, nullable), invoice_number (text, 'INV-000001'),
  issue_date (date), due_date (date, issue_date + 14 days),
  status ('paid'/'open'/'overdue'/'void'),
  subtotal (numeric), tax (numeric, 10% of subtotal), total (numeric, subtotal + tax),
  currency ('USD')

- table "invoice_items" — line items of invoices:
  item_id (int, PK), invoice_id (int, FK→invoices), product_id (int, FK→products),
  description (text), quantity (int), unit_price (numeric),
  amount (numeric, = quantity × unit_price)

- table "payments" — one row per PAID invoice:
  payment_id (bigint, PK), invoice_id (int, FK→invoices), customer_id (int, FK→customers),
  paid_at (date), amount (numeric, equals invoice total),
  method ('card'/'bank_transfer'/'paypal'/'wire'), status (always 'succeeded'),
  reference (text)

- table "transactions" — money ledger events:
  transaction_id (int, PK), customer_id (int, FK→customers),
  type ('charge'/'refund'/'credit'/'adjustment'),
  amount (numeric, USD; NEGATIVE for refunds), currency ('USD'),
  status ('completed'/'pending'/'failed'), description (text), created_at (timestamptz)

- table "usage_logs" — product usage events by customer users:
  log_id (int, PK), user_id (int, FK→users), customer_id (int, FK→customers),
  event_type ('login'/'api_call'/'report_generated'/'data_export'/'file_upload'/'dashboard_view'),
  feature ('analytics'/'billing'/'reports'/'api'/'storage'/'admin'),
  quantity (int), logged_at (timestamptz)

- table "support_tickets" — customer support tickets:
  ticket_id (int, PK), customer_id (int, FK→customers),
  assigned_to (int, FK→users, internal staff), subject (text),
  category ('billing'/'technical'/'account'/'feature_request'),
  priority ('low'/'medium'/'high'/'urgent'),
  status ('open'/'in_progress'/'resolved'/'closed'),
  opened_at (timestamptz), closed_at (timestamptz, NULL while open)

Query tips:
- "last month" = previous calendar month:
  date_col >= date_trunc('month', CURRENT_DATE) - interval '1 month'
  AND date_col < date_trunc('month', CURRENT_DATE)
- Revenue/sales totals: SUM(sales.total_amount). Collected cash: SUM(payments.amount).
- Refunds are transactions with type='refund' (amounts are negative).
- Always include a LIMIT for row listings.
`.trim();
