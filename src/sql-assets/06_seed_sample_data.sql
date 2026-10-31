-- =============================================================================
-- Seed Data: Enterprise E-Commerce & SaaS Analytics Platform
-- Dialect: MySQL 8.0 / Amazon Aurora MySQL
-- Purpose: Sample data for testing Text-to-SQL queries and validation
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- 1. Insert Customers
-- -----------------------------------------------------------------------------
INSERT INTO customers (customer_id, first_name, last_name, email, phone, city, state, country, postal_code, customer_tier, status, created_at)
VALUES
(1, 'Alice',   'Johnson',   'alice.johnson@example.com',   '+1-555-0101', 'Seattle',       'WA', 'United States', '98101', 'vip',        'active',   '2025-01-15 08:30:00'),
(2, 'Bob',     'Smith',     'bob.smith@example.com',       '+1-555-0102', 'Austin',        'TX', 'United States', '78701', 'enterprise', 'active',   '2025-02-01 10:15:00'),
(3, 'Charlie', 'Davis',     'charlie.davis@example.com',   '+1-555-0103', 'San Francisco', 'CA', 'United States', '94105', 'premium',    'active',   '2025-03-10 14:20:00'),
(4, 'Diana',   'Prince',    'diana.prince@example.com',    '+1-555-0104', 'New York',      'NY', 'United States', '10001', 'standard',   'active',   '2025-04-05 09:00:00'),
(5, 'Evan',    'Wright',    'evan.wright@example.com',     '+1-555-0105', 'Chicago',       'IL', 'United States', '60601', 'standard',   'churned',  '2025-01-20 11:45:00'),
(6, 'Fiona',   'Gallagher', 'fiona.g@example.co.uk',       '+44-20-7946', 'London',        NULL, 'United Kingdom', 'EC1A', 'vip',        'active',   '2025-02-18 16:30:00'),
(7, 'George',  'Miller',    'george.miller@example.ca',    '+1-416-555',  'Toronto',       'ON', 'Canada',        'M5H',   'premium',    'active',   '2025-05-12 13:10:00'),
(8, 'Hannah',  'Schmidt',   'hannah.s@example.de',         '+49-30-1234', 'Berlin',        NULL, 'Germany',       '10115', 'standard',   'active',   '2025-06-25 17:00:00'),
(9, 'Ian',     'Malcolm',   'ian.malcolm@example.com',     '+1-555-0109', 'Boston',        'MA', 'United States', '02108', 'enterprise', 'active',   '2025-07-04 12:00:00'),
(10, 'Julia',  'Roberts',   'julia.roberts@example.com',   '+1-555-0110', 'Denver',        'CO', 'United States', '80202', 'standard',   'suspended','2025-08-14 15:40:00')
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- -----------------------------------------------------------------------------
-- 2. Insert Categories
-- -----------------------------------------------------------------------------
INSERT INTO categories (category_id, name, slug, parent_id, description, is_active)
VALUES
(1, 'Developer Tools',     'developer-tools',     NULL, 'Software development IDEs, compilers, and SDKs', 1),
(2, 'Cloud Infrastructure', 'cloud-infrastructure', NULL, 'Virtual machines, storage, and database services', 1),
(3, 'Office Hardware',      'office-hardware',      NULL, 'Monitors, laptops, and ergonomic accessories',   1),
(4, 'Database Systems',     'database-systems',     2,    'Relational and NoSQL database management tools',  1),
(5, 'AI & Machine Learning','ai-machine-learning',  1,    'LLM SDKs, model fine-tuning and inference APIs',  1)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- -----------------------------------------------------------------------------
-- 3. Insert Products
-- -----------------------------------------------------------------------------
INSERT INTO products (product_id, category_id, sku, name, description, cost_price, retail_price, stock_quantity, low_stock_threshold, is_available)
VALUES
(1,  1, 'DEV-IDE-PRO',   'CloudIDE Studio Pro',        'Full-featured collaborative web IDE license',       25.00,  99.00,  500, 20, 1),
(2,  1, 'DEV-COPILOT',   'AI Code Assistant Seat',      'AI pair programmer extension monthly access',       10.00,  29.00,  999, 50, 1),
(3,  2, 'CLD-STORE-1TB', 'Enterprise Cloud Vault 1TB', 'High durability multi-region object storage',        15.00,  45.00,  200, 15, 1),
(4,  2, 'CLD-COMP-8X',   'High-Compute Compute Unit',   'Dedicated 8-vCPU cloud container instance',         40.00, 120.00,  150, 10, 1),
(5,  3, 'HW-MON-4K',     'UltraView 32-inch 4K Monitor','IPS panel monitor with USB-C 90W power delivery',   280.00, 499.00,    8, 10, 1),
(6,  3, 'HW-MECH-KB',    'ErgoMech Wireless Keyboard',  'Split mechanical keyboard with tactile switches',    65.00, 149.00,   45, 15, 1),
(7,  3, 'HW-DESK-MAT',   'Precision Desk Mat XXL',      'Waterproof felt and rubber desk pad',                 8.00,  25.00,    5, 10, 1),
(8,  4, 'DB-SQL-MGMT',   'SQL Master Optimizer Tool',   'Index tuning and query performance diagnostics',    50.00, 199.00,  300, 20, 1),
(9,  4, 'DB-REPL-SYNC',  'Cross-Region Data Replicator','Automated continuous MySQL streaming replication', 80.00, 250.00,  100, 10, 1),
(10, 5, 'AI-TITAN-API',  'Titan Model API Credits 10M', 'Token allowance pack for Bedrock inference',        30.00,  80.00,  850, 50, 1)
ON DUPLICATE KEY UPDATE retail_price = VALUES(retail_price);

-- -----------------------------------------------------------------------------
-- 4. Insert Orders
-- -----------------------------------------------------------------------------
INSERT INTO orders (order_id, customer_id, order_date, status, subtotal_amount, discount_amount, tax_amount, shipping_amount, total_amount, payment_method, shipping_city, shipping_state, shipping_country)
VALUES
(1001, 1, '2026-01-05 10:20:00', 'delivered',  648.00, 50.00, 53.82, 0.00,   651.82,  'credit_card', 'Seattle',       'WA', 'United States'),
(1002, 2, '2026-01-12 14:45:00', 'completed',  998.00,  0.00, 82.34, 15.00, 1095.34,  'bank_transfer','Austin',        'TX', 'United States'),
(1003, 3, '2026-01-20 16:10:00', 'delivered',  248.00, 20.00, 18.24, 0.00,   246.24,  'apple_pay',   'San Francisco', 'CA', 'United States'),
(1004, 4, '2026-02-02 09:30:00', 'delivered',  499.00,  0.00, 44.29, 25.00,  568.29,  'credit_card', 'New York',      'NY', 'United States'),
(1005, 1, '2026-02-10 11:00:00', 'delivered',  198.00, 15.00, 14.64, 0.00,   197.64,  'credit_card', 'Seattle',       'WA', 'United States'),
(1006, 5, '2026-02-14 13:25:00', 'refunded',   149.00,  0.00, 11.92, 10.00,  170.92,  'paypal',      'Chicago',       'IL', 'United States'),
(1007, 6, '2026-02-22 15:50:00', 'delivered',  579.00, 40.00, 43.12, 35.00,  617.12,  'credit_card', 'London',        NULL, 'United Kingdom'),
(1008, 7, '2026-03-01 10:05:00', 'delivered',  279.00,  0.00, 36.27, 20.00,  335.27,  'credit_card', 'Toronto',       'ON', 'Canada'),
(1009, 8, '2026-03-15 17:40:00', 'completed',  160.00, 10.00, 28.50, 15.00,  193.50,  'paypal',      'Berlin',        NULL, 'Germany'),
(1010, 9, '2026-03-22 08:55:00', 'completed', 1250.00,100.00, 92.00,  0.00, 1242.00,  'bank_transfer','Boston',        'MA', 'United States'),
(1011, 2, '2026-04-02 12:15:00', 'delivered',  499.00,  0.00, 41.17,  0.00,  540.17,  'credit_card', 'Austin',        'TX', 'United States'),
(1012, 3, '2026-04-10 14:00:00', 'shipped',    174.00, 15.00, 12.72,  0.00,  171.72,  'apple_pay',   'San Francisco', 'CA', 'United States'),
(1013, 4, '2026-04-18 16:20:00', 'cancelled',   80.00,  0.00,  6.40,  0.00,   86.40,  'credit_card', 'New York',      'NY', 'United States'),
(1014, 1, '2026-04-25 10:45:00', 'delivered',  250.00, 25.00, 18.00,  0.00,  243.00,  'credit_card', 'Seattle',       'WA', 'United States'),
(1015, 9, '2026-05-01 09:10:00', 'completed',  990.00, 50.00, 75.20,  0.00, 1015.20,  'bank_transfer','Boston',        'MA', 'United States')
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- -----------------------------------------------------------------------------
-- 5. Insert Order Items
-- -----------------------------------------------------------------------------
INSERT INTO order_items (item_id, order_id, product_id, quantity, unit_price, total_price)
VALUES
(1,  1001, 5,  1, 499.00, 499.00),
(2,  1001, 6,  1, 149.00, 149.00),
(3,  1002, 5,  2, 499.00, 998.00),
(4,  1003, 1,  2,  99.00, 198.00),
(5,  1003, 7,  2,  25.00,  50.00),
(6,  1004, 5,  1, 499.00, 499.00),
(7,  1005, 1,  2,  99.00, 198.00),
(8,  1006, 6,  1, 149.00, 149.00),
(9,  1007, 5,  1, 499.00, 499.00),
(10, 1007, 10, 1,  80.00,  80.00),
(11, 1008, 6,  1, 149.00, 149.00),
(12, 1008, 4,  1, 120.00, 120.00),
(13, 1009, 10, 2,  80.00, 160.00),
(14, 1010, 9,  5, 250.00,1250.00),
(15, 1011, 5,  1, 499.00, 499.00),
(16, 1012, 6,  1, 149.00, 149.00),
(17, 1012, 7,  1,  25.00,  25.00),
(18, 1013, 10, 1,  80.00,  80.00),
(19, 1014, 9,  1, 250.00, 250.00),
(20, 1015, 1, 10,  99.00, 990.00)
ON DUPLICATE KEY UPDATE quantity = VALUES(quantity);

-- -----------------------------------------------------------------------------
-- 6. Insert Payments
-- -----------------------------------------------------------------------------
INSERT INTO payments (payment_id, order_id, customer_id, amount, currency, payment_method, status, transaction_ref, processed_at)
VALUES
(1,  1001, 1,  651.82, 'USD', 'credit_card',   'captured', 'TXN-901-001', '2026-01-05 10:20:15'),
(2,  1002, 2, 1095.34, 'USD', 'bank_transfer', 'captured', 'TXN-901-002', '2026-01-12 14:46:02'),
(3,  1003, 3,  246.24, 'USD', 'apple_pay',     'captured', 'TXN-901-003', '2026-01-20 16:10:45'),
(4,  1004, 4,  568.29, 'USD', 'credit_card',   'captured', 'TXN-901-004', '2026-02-02 09:30:50'),
(5,  1005, 1,  197.64, 'USD', 'credit_card',   'captured', 'TXN-901-005', '2026-02-10 11:00:22'),
(6,  1006, 5,  170.92, 'USD', 'paypal',        'refunded', 'TXN-901-006', '2026-02-14 13:25:30'),
(7,  1007, 6,  617.12, 'GBP', 'credit_card',   'captured', 'TXN-901-007', '2026-02-22 15:51:00'),
(8,  1008, 7,  335.27, 'CAD', 'credit_card',   'captured', 'TXN-901-008', '2026-03-01 10:05:40'),
(9,  1009, 8,  193.50, 'EUR', 'paypal',        'captured', 'TXN-901-009', '2026-03-15 17:41:10'),
(10, 1010, 9, 1242.00, 'USD', 'bank_transfer', 'captured', 'TXN-901-010', '2026-03-22 08:55:55'),
(11, 1011, 2,  540.17, 'USD', 'credit_card',   'captured', 'TXN-901-011', '2026-04-02 12:15:20'),
(12, 1012, 3,  171.72, 'USD', 'apple_pay',     'captured', 'TXN-901-012', '2026-04-10 14:00:45'),
(13, 1013, 4,   86.40, 'USD', 'credit_card',   'voided',   'TXN-901-013', '2026-04-18 16:21:00'),
(14, 1014, 1,  243.00, 'USD', 'credit_card',   'captured', 'TXN-901-014', '2026-04-25 10:45:30'),
(15, 1015, 9, 1015.20, 'USD', 'bank_transfer', 'captured', 'TXN-901-015', '2026-05-01 09:10:40')
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- -----------------------------------------------------------------------------
-- 7. Insert Subscriptions
-- -----------------------------------------------------------------------------
INSERT INTO subscriptions (subscription_id, customer_id, plan_tier, billing_cycle, mrr_amount, status, started_at, current_period_end)
VALUES
(1, 1, 'professional', 'monthly',  149.00, 'active',   '2025-02-01 00:00:00', '2026-11-01 00:00:00'),
(2, 2, 'enterprise',   'annual',   850.00, 'active',   '2025-03-01 00:00:00', '2027-03-01 00:00:00'),
(3, 3, 'starter',      'monthly',   49.00, 'active',   '2025-04-01 00:00:00', '2026-11-01 00:00:00'),
(4, 5, 'starter',      'monthly',   49.00, 'canceled', '2025-02-15 00:00:00', '2025-05-15 00:00:00'),
(5, 6, 'professional', 'monthly',  149.00, 'active',   '2025-03-15 00:00:00', '2026-11-15 00:00:00'),
(6, 7, 'business',     'monthly',  299.00, 'active',   '2025-06-01 00:00:00', '2026-11-01 00:00:00'),
(7, 9, 'enterprise',   'annual',  1200.00, 'active',   '2025-08-01 00:00:00', '2027-08-01 00:00:00')
ON DUPLICATE KEY UPDATE mrr_amount = VALUES(mrr_amount);

-- -----------------------------------------------------------------------------
-- 8. Insert Product Reviews
-- -----------------------------------------------------------------------------
INSERT INTO reviews (review_id, product_id, customer_id, rating, headline, body, is_verified_buyer, created_at)
VALUES
(1, 5, 1, 5, 'Exceptional 4K clarity for coding',  'Text sharpness is crisp, single USB-C cable powers my laptop with 90W cleanly.', 1, '2026-01-20 12:00:00'),
(2, 5, 2, 5, 'Best office monitor fleet upgrade', 'Purchased for multiple engineers, flawless color reproduction and viewing angles.', 1, '2026-01-25 15:30:00'),
(3, 6, 1, 4, 'Ergonomic wrist relief',            'Mechanical split layout resolved wrist fatigue. Takes a couple of days to adjust.', 1, '2026-02-01 09:20:00'),
(4, 6, 3, 5, 'Superb build quality',              'Tactile switches feel great and battery lasts for weeks over Bluetooth.', 1, '2026-02-15 18:45:00'),
(5, 1, 3, 4, 'Solid cloud IDE experience',        'Great for remote pairing and spinning up instant dev containers.', 1, '2026-02-28 14:10:00'),
(6, 9, 9, 5, 'Rock solid replication',            'Zero lag MySQL replication across multi-region VPCs. Handled traffic spikes smoothly.', 1, '2026-04-05 11:15:00'),
(7, 7, 3, 3, 'Average desk mat',                  'Quality is decent for the price, but edges started fraying slightly after 2 months.', 1, '2026-04-12 16:00:00')
ON DUPLICATE KEY UPDATE rating = VALUES(rating);

SET FOREIGN_KEY_CHECKS = 1;

