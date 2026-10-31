-- =============================================================================
-- Database Schema: Enterprise E-Commerce & SaaS Analytics Platform
-- Dialect: MySQL 8.0 / Amazon Aurora MySQL
-- Purpose: Reference DDL for Amazon Bedrock Text-to-SQL Knowledge Base
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- Table: customers
-- Description: Stores registered user accounts and customer demographic profiles
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    customer_id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    first_name          VARCHAR(50)     NOT NULL,
    last_name           VARCHAR(50)     NOT NULL,
    email               VARCHAR(100)    NOT NULL UNIQUE,
    phone               VARCHAR(20)     DEFAULT NULL,
    city                VARCHAR(50)     NOT NULL,
    state               VARCHAR(50)     DEFAULT NULL,
    country             VARCHAR(50)     NOT NULL DEFAULT 'United States',
    postal_code         VARCHAR(20)     DEFAULT NULL,
    customer_tier       ENUM('standard', 'premium', 'vip', 'enterprise') NOT NULL DEFAULT 'standard',
    status              ENUM('active', 'inactive', 'churned', 'suspended') NOT NULL DEFAULT 'active',
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_customers_status (status),
    INDEX idx_customers_tier (customer_tier),
    INDEX idx_customers_country_city (country, city),
    INDEX idx_customers_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Customer directory with status, location, and membership tiers';

-- -----------------------------------------------------------------------------
-- Table: categories
-- Description: Hierarchical product classification categories
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
    category_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name                VARCHAR(100)    NOT NULL,
    slug                VARCHAR(100)    NOT NULL UNIQUE,
    parent_id           INT UNSIGNED    DEFAULT NULL,
    description         TEXT            DEFAULT NULL,
    is_active           TINYINT(1)      NOT NULL DEFAULT 1,
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) 
        REFERENCES categories (category_id) ON DELETE SET NULL,
    INDEX idx_categories_parent (parent_id),
    INDEX idx_categories_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Product categories with hierarchical self-referencing parent structure';

-- -----------------------------------------------------------------------------
-- Table: products
-- Description: Inventory catalog including pricing, stock, and category linkage
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
    product_id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_id         INT UNSIGNED    NOT NULL,
    sku                 VARCHAR(50)     NOT NULL UNIQUE,
    name                VARCHAR(150)    NOT NULL,
    description         TEXT            DEFAULT NULL,
    cost_price          DECIMAL(10, 2)  NOT NULL COMMENT 'Cost to manufacture or acquire product',
    retail_price        DECIMAL(10, 2)  NOT NULL COMMENT 'Current standard selling price',
    stock_quantity      INT             NOT NULL DEFAULT 0,
    low_stock_threshold INT             NOT NULL DEFAULT 10,
    is_available        TINYINT(1)      NOT NULL DEFAULT 1,
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) 
        REFERENCES categories (category_id) ON DELETE RESTRICT,
    INDEX idx_products_category (category_id),
    INDEX idx_products_price (retail_price),
    INDEX idx_products_stock (stock_quantity, is_available)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Product inventory items with pricing and stock levels';

-- -----------------------------------------------------------------------------
-- Table: orders
-- Description: High-level transactional orders placed by customers
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
    order_id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id         BIGINT UNSIGNED NOT NULL,
    order_date          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status              ENUM('pending', 'processing', 'completed', 'shipped', 'delivered', 'cancelled', 'refunded') NOT NULL DEFAULT 'pending',
    subtotal_amount     DECIMAL(12, 2)  NOT NULL DEFAULT 0.00,
    discount_amount     DECIMAL(10, 2)  NOT NULL DEFAULT 0.00,
    tax_amount          DECIMAL(10, 2)  NOT NULL DEFAULT 0.00,
    shipping_amount     DECIMAL(10, 2)  NOT NULL DEFAULT 0.00,
    total_amount        DECIMAL(12, 2)  NOT NULL DEFAULT 0.00 COMMENT 'Net final paid amount including tax, shipping, minus discounts',
    payment_method      ENUM('credit_card', 'debit_card', 'paypal', 'apple_pay', 'bank_transfer', 'crypto') NOT NULL DEFAULT 'credit_card',
    shipping_city       VARCHAR(50)     NOT NULL,
    shipping_state      VARCHAR(50)     DEFAULT NULL,
    shipping_country    VARCHAR(50)     NOT NULL,
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) 
        REFERENCES customers (customer_id) ON DELETE RESTRICT,
    INDEX idx_orders_customer (customer_id),
    INDEX idx_orders_date (order_date),
    INDEX idx_orders_status (status),
    INDEX idx_orders_total (total_amount)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Customer orders with lifecycle statuses and financial totals';

-- -----------------------------------------------------------------------------
-- Table: order_items
-- Description: Individual line items associated with each order
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_items (
    item_id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id            BIGINT UNSIGNED NOT NULL,
    product_id          BIGINT UNSIGNED NOT NULL,
    quantity            INT UNSIGNED    NOT NULL DEFAULT 1,
    unit_price          DECIMAL(10, 2)  NOT NULL COMMENT 'Unit price at the time of purchase',
    total_price         DECIMAL(12, 2)  NOT NULL COMMENT 'quantity * unit_price',
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) 
        REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) 
        REFERENCES products (product_id) ON DELETE RESTRICT,
    INDEX idx_order_items_order (order_id),
    INDEX idx_order_items_product (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Line-item breakdown of products per order';

-- -----------------------------------------------------------------------------
-- Table: payments
-- Description: Payment transaction records for order billing
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
    payment_id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id            BIGINT UNSIGNED NOT NULL,
    customer_id         BIGINT UNSIGNED NOT NULL,
    amount              DECIMAL(12, 2)  NOT NULL,
    currency            VARCHAR(3)      NOT NULL DEFAULT 'USD',
    payment_method      VARCHAR(30)     NOT NULL,
    status              ENUM('authorized', 'captured', 'failed', 'refunded', 'voided') NOT NULL,
    transaction_ref     VARCHAR(100)    NOT NULL UNIQUE,
    processed_at        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) 
        REFERENCES orders (order_id) ON DELETE RESTRICT,
    CONSTRAINT fk_payments_customer FOREIGN KEY (customer_id) 
        REFERENCES customers (customer_id) ON DELETE RESTRICT,
    INDEX idx_payments_order (order_id),
    INDEX idx_payments_customer (customer_id),
    INDEX idx_payments_status_date (status, processed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Payment ledger recording financial transactions and gateway statuses';

-- -----------------------------------------------------------------------------
-- Table: subscriptions
-- Description: Recurring SaaS subscription agreements
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subscriptions (
    subscription_id     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id         BIGINT UNSIGNED NOT NULL,
    plan_tier           ENUM('starter', 'professional', 'business', 'enterprise') NOT NULL,
    billing_cycle       ENUM('monthly', 'quarterly', 'annual') NOT NULL DEFAULT 'monthly',
    mrr_amount          DECIMAL(10, 2)  NOT NULL COMMENT 'Normalized Monthly Recurring Revenue contributed by this plan',
    status              ENUM('trialing', 'active', 'past_due', 'canceled', 'paused') NOT NULL DEFAULT 'trialing',
    started_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    current_period_end  DATETIME        NOT NULL,
    canceled_at         DATETIME        DEFAULT NULL,
    CONSTRAINT fk_subscriptions_customer FOREIGN KEY (customer_id) 
        REFERENCES customers (customer_id) ON DELETE RESTRICT,
    INDEX idx_subscriptions_customer (customer_id),
    INDEX idx_subscriptions_status (status),
    INDEX idx_subscriptions_mrr (mrr_amount)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Recurring SaaS subscriptions contributing to Monthly Recurring Revenue (MRR)';

-- -----------------------------------------------------------------------------
-- Table: reviews
-- Description: Customer feedback and ratings for catalog products
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reviews (
    review_id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id          BIGINT UNSIGNED NOT NULL,
    customer_id         BIGINT UNSIGNED NOT NULL,
    rating              TINYINT UNSIGNED NOT NULL CHECK (rating BETWEEN 1 AND 5),
    headline            VARCHAR(255)    DEFAULT NULL,
    body                TEXT            DEFAULT NULL,
    is_verified_buyer   TINYINT(1)      NOT NULL DEFAULT 0,
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reviews_product FOREIGN KEY (product_id) 
        REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT fk_reviews_customer FOREIGN KEY (customer_id) 
        REFERENCES customers (customer_id) ON DELETE RESTRICT,
    INDEX idx_reviews_product_rating (product_id, rating),
    INDEX idx_reviews_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Customer product reviews and 1 to 5 star ratings';

SET FOREIGN_KEY_CHECKS = 1;

