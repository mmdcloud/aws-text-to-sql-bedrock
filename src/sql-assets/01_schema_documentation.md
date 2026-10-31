# Database Schema Reference & Data Dictionary

This document details the production relational database schema designed for our E-Commerce & SaaS Analytics platform running on **MySQL 8.0**.

---

## 1. Table: `customers`
Stores registered customer accounts, contact information, geographic location, and tier classifications.

| Column Name | Data Type | Nullable | Default | Description & Allowed Values |
| :--- | :--- | :---: | :--- | :--- |
| `customer_id` | `BIGINT UNSIGNED` | NO | Auto-Increment | Primary key identifier for the customer. |
| `first_name` | `VARCHAR(50)` | NO | None | Customer's given name. |
| `last_name` | `VARCHAR(50)` | NO | None | Customer's family name. |
| `email` | `VARCHAR(100)` | NO | Unique | Unique email address used for identification and login. |
| `phone` | `VARCHAR(20)` | YES | NULL | Contact phone number. |
| `city` | `VARCHAR(50)` | NO | None | Billing or primary residence city. |
| `state` | `VARCHAR(50)` | YES | NULL | State, province, or region. |
| `country` | `VARCHAR(50)` | NO | 'United States' | ISO country name. |
| `postal_code` | `VARCHAR(20)` | YES | NULL | Postal/ZIP code. |
| `customer_tier` | `ENUM` | NO | 'standard' | Values: `'standard'`, `'premium'`, `'vip'`, `'enterprise'`. |
| `status` | `ENUM` | NO | 'active' | Values: `'active'` (current), `'inactive'` (idle), `'churned'` (stopped buying/using), `'suspended'`. |
| `created_at` | `DATETIME` | NO | `CURRENT_TIMESTAMP` | Account registration timestamp. |
| `updated_at` | `DATETIME` | NO | Auto-update | Timestamp of last record update. |

---

## 2. Table: `categories`
Hierarchical product catalog taxonomy. Supports nested categories via self-referential `parent_id`.

| Column Name | Data Type | Nullable | Default | Description & Allowed Values |
| :--- | :--- | :---: | :--- | :--- |
| `category_id` | `INT UNSIGNED` | NO | Auto-Increment | Primary key identifier for the category. |
| `name` | `VARCHAR(100)` | NO | None | Human-readable name (e.g., "Electronics", "Cloud Storage"). |
| `slug` | `VARCHAR(100)` | NO | Unique | URL-friendly unique identifier (e.g., "cloud-storage"). |
| `parent_id` | `INT UNSIGNED` | YES | NULL | Self-reference to `categories.category_id`. NULL indicates a top-level category. |
| `description` | `TEXT` | YES | NULL | Category scope and details. |
| `is_active` | `TINYINT(1)` | NO | 1 | Flag indicating if category is active (1 = active, 0 = disabled). |
| `created_at` | `DATETIME` | NO | `CURRENT_TIMESTAMP` | Creation timestamp. |

---

## 3. Table: `products`
Product catalog items, physical goods, or digital offerings with stock levels and price histories.

| Column Name | Data Type | Nullable | Default | Description & Allowed Values |
| :--- | :--- | :---: | :--- | :--- |
| `product_id` | `BIGINT UNSIGNED` | NO | Auto-Increment | Primary key identifier for the product. |
| `category_id` | `INT UNSIGNED` | NO | Foreign Key | References `categories.category_id`. |
| `sku` | `VARCHAR(50)` | NO | Unique | Stock Keeping Unit code (e.g., "PROD-TECH-001"). |
| `name` | `VARCHAR(150)` | NO | None | Product title / commercial name. |
| `description` | `TEXT` | YES | NULL | Detailed product specifications. |
| `cost_price` | `DECIMAL(10, 2)` | NO | None | Cost of goods sold (COGS) to acquire or make the item. |
| `retail_price` | `DECIMAL(10, 2)` | NO | None | Current listing price charged to customers. |
| `stock_quantity` | `INT` | NO | 0 | Current quantity available in warehouse. |
| `low_stock_threshold`| `INT` | NO | 10 | Minimum inventory level before restock alert. |
| `is_available` | `TINYINT(1)` | NO | 1 | 1 = available for purchase; 0 = out of catalog or retired. |
| `created_at` | `DATETIME` | NO | `CURRENT_TIMESTAMP` | When the product was added. |
| `updated_at` | `DATETIME` | NO | Auto-update | Last modification timestamp. |

---

## 4. Table: `orders`
High-level order header records capturing checkout events, delivery status, and financial summaries.

| Column Name | Data Type | Nullable | Default | Description & Allowed Values |
| :--- | :--- | :---: | :--- | :--- |
| `order_id` | `BIGINT UNSIGNED` | NO | Auto-Increment | Unique order number. |
| `customer_id` | `BIGINT UNSIGNED` | NO | Foreign Key | References `customers.customer_id`. |
| `order_date` | `DATETIME` | NO | `CURRENT_TIMESTAMP` | Timestamp when customer placed the order. |
| `status` | `ENUM` | NO | 'pending' | Allowed: `'pending'`, `'processing'`, `'completed'`, `'shipped'`, `'delivered'`, `'cancelled'`, `'refunded'`. |
| `subtotal_amount` | `DECIMAL(12, 2)` | NO | 0.00 | Total sum of line items before discounts, taxes, and shipping. |
| `discount_amount` | `DECIMAL(10, 2)` | NO | 0.00 | Promotional voucher or coupon discount subtracted. |
| `tax_amount` | `DECIMAL(10, 2)` | NO | 0.00 | Total state/local sales tax applied. |
| `shipping_amount` | `DECIMAL(10, 2)` | NO | 0.00 | Shipping and handling cost. |
| `total_amount` | `DECIMAL(12, 2)` | NO | 0.00 | Net billed total: `subtotal - discount + tax + shipping`. |
| `payment_method` | `ENUM` | NO | 'credit_card' | Values: `'credit_card'`, `'debit_card'`, `'paypal'`, `'apple_pay'`, `'bank_transfer'`, `'crypto'`. |
| `shipping_city` | `VARCHAR(50)` | NO | None | Destination city. |
| `shipping_state` | `VARCHAR(50)` | YES | NULL | Destination state or province. |
| `shipping_country` | `VARCHAR(50)` | NO | None | Destination country. |
| `created_at` | `DATETIME` | NO | `CURRENT_TIMESTAMP` | Order record creation timestamp. |

---

## 5. Table: `order_items`
Line item details for each product purchased in an order.

| Column Name | Data Type | Nullable | Default | Description & Allowed Values |
| :--- | :--- | :---: | :--- | :--- |
| `item_id` | `BIGINT UNSIGNED` | NO | Auto-Increment | Primary key identifier for the order line item. |
| `order_id` | `BIGINT UNSIGNED` | NO | Foreign Key | References `orders.order_id`. |
| `product_id` | `BIGINT UNSIGNED` | NO | Foreign Key | References `products.product_id`. |
| `quantity` | `INT UNSIGNED` | NO | 1 | Number of units purchased. |
| `unit_price` | `DECIMAL(10, 2)` | NO | None | Price per unit at purchase time (locks historical price). |
| `total_price` | `DECIMAL(12, 2)` | NO | None | Line total: `quantity * unit_price`. |

---

## 6. Table: `payments`
Financial transactions and payment gateway attempts.

| Column Name | Data Type | Nullable | Default | Description & Allowed Values |
| :--- | :--- | :---: | :--- | :--- |
| `payment_id` | `BIGINT UNSIGNED` | NO | Auto-Increment | Primary key transaction ID. |
| `order_id` | `BIGINT UNSIGNED` | NO | Foreign Key | References `orders.order_id`. |
| `customer_id` | `BIGINT UNSIGNED` | NO | Foreign Key | References `customers.customer_id`. |
| `amount` | `DECIMAL(12, 2)` | NO | None | Transaction value settled in the gateway. |
| `currency` | `VARCHAR(3)` | NO | 'USD' | 3-letter ISO-4217 currency code. |
| `payment_method` | `VARCHAR(30)` | NO | None | Payment provider or channel. |
| `status` | `ENUM` | NO | None | Values: `'authorized'`, `'captured'`, `'failed'`, `'refunded'`, `'voided'`. |
| `transaction_ref` | `VARCHAR(100)` | NO | Unique | External gateway transaction hash / reference. |
| `processed_at` | `DATETIME` | NO | `CURRENT_TIMESTAMP` | Settlement timestamp. |

---

## 7. Table: `subscriptions`
Recurring SaaS service contracts, billing intervals, and Monthly Recurring Revenue (MRR).

| Column Name | Data Type | Nullable | Default | Description & Allowed Values |
| :--- | :--- | :---: | :--- | :--- |
| `subscription_id` | `BIGINT UNSIGNED` | NO | Auto-Increment | Primary key identifier. |
| `customer_id` | `BIGINT UNSIGNED` | NO | Foreign Key | References `customers.customer_id`. |
| `plan_tier` | `ENUM` | NO | None | Allowed: `'starter'`, `'professional'`, `'business'`, `'enterprise'`. |
| `billing_cycle` | `ENUM` | NO | 'monthly' | Values: `'monthly'`, `'quarterly'`, `'annual'`. |
| `mrr_amount` | `DECIMAL(10, 2)` | NO | None | Normalized Monthly Recurring Revenue contributed by this plan. |
| `status` | `ENUM` | NO | 'trialing' | Values: `'trialing'`, `'active'`, `'past_due'`, `'canceled'`, `'paused'`. |
| `started_at` | `DATETIME` | NO | `CURRENT_TIMESTAMP` | Initial activation date. |
| `current_period_end`| `DATETIME` | NO | None | Renewal or expiration date. |
| `canceled_at` | `DATETIME` | YES | NULL | Timestamp of cancellation if canceled. |

---

## 8. Table: `reviews`
User ratings and written reviews for catalog products.

| Column Name | Data Type | Nullable | Default | Description & Allowed Values |
| :--- | :--- | :---: | :--- | :--- |
| `review_id` | `BIGINT UNSIGNED` | NO | Auto-Increment | Primary key identifier. |
| `product_id` | `BIGINT UNSIGNED` | NO | Foreign Key | References `products.product_id`. |
| `customer_id` | `BIGINT UNSIGNED` | NO | Foreign Key | References `customers.customer_id`. |
| `rating` | `TINYINT UNSIGNED`| NO | None | Customer score from 1 (lowest) to 5 (highest). |
| `headline` | `VARCHAR(255)` | YES | NULL | Short summary header. |
| `body` | `TEXT` | YES | NULL | Full feedback review text. |
| `is_verified_buyer`| `TINYINT(1)` | NO | 0 | 1 = user confirmed to have purchased the item; 0 = unverified. |
| `created_at` | `DATETIME` | NO | `CURRENT_TIMESTAMP` | Review submission timestamp. |

