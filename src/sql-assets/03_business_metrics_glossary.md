# Business Metrics, KPIs & Semantic Glossary

This reference provides standardized definitions and exact SQL formulas for key business metrics, ensuring consistent analytical queries across Amazon Bedrock Text-to-SQL workflows.

---

## 1. Revenue Metrics

### Gross Revenue / Gross Merchandise Value (GMV)
* **Definition**: The total value of all completed, shipped, or delivered merchandise sold before deducting discounts, taxes, or shipping.
* **SQL Logic**:
  ```sql
  SELECT SUM(subtotal_amount) AS gross_revenue
  FROM orders
  WHERE status IN ('completed', 'shipped', 'delivered');
  ```

### Net Revenue
* **Definition**: The actual collected revenue: `subtotal - discounts + tax + shipping` for successful orders.
* **SQL Logic**:
  ```sql
  SELECT SUM(total_amount) AS net_revenue
  FROM orders
  WHERE status IN ('completed', 'shipped', 'delivered');
  ```

### Average Order Value (AOV)
* **Definition**: The average revenue generated per completed order.
* **Formula**: `Total Net Revenue / Count of Orders`
* **SQL Logic**:
  ```sql
  SELECT
      ROUND(SUM(total_amount) / COUNT(order_id), 2) AS average_order_value
  FROM orders
  WHERE status IN ('completed', 'shipped', 'delivered');
  ```

---

## 2. Customer Performance Metrics

### Active Customers
* **Definition**: Customers who placed at least one completed order within the last $N$ days (standard window: 30, 60, or 90 days), or have an active subscription.
* **SQL Logic (Last 30 Days)**:
  ```sql
  SELECT COUNT(DISTINCT customer_id) AS active_customers_30d
  FROM orders
  WHERE order_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
    AND status IN ('completed', 'shipped', 'delivered');
  ```

### Customer Lifetime Value (LTV)
* **Definition**: Total historical spend of a customer across all completed orders.
* **SQL Logic**:
  ```sql
  SELECT
      c.customer_id,
      CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
      c.email,
      COALESCE(SUM(o.total_amount), 0.00) AS lifetime_value,
      COUNT(o.order_id) AS total_orders_placed
  FROM customers c
  LEFT JOIN orders o ON c.customer_id = o.customer_id
      AND o.status IN ('completed', 'shipped', 'delivered')
  GROUP BY c.customer_id, c.first_name, c.last_name, c.email
  ORDER BY lifetime_value DESC;
  ```

### Churned Customers
* **Definition**: Customers marked with `status = 'churned'` OR customers whose last order was placed more than 90 days ago.
* **SQL Logic**:
  ```sql
  SELECT
      c.customer_id,
      c.email,
      MAX(o.order_date) AS last_order_date,
      DATEDIFF(NOW(), MAX(o.order_date)) AS days_since_last_order
  FROM customers c
  INNER JOIN orders o ON c.customer_id = o.customer_id
  WHERE o.status IN ('completed', 'shipped', 'delivered')
  GROUP BY c.customer_id, c.email
  HAVING last_order_date < DATE_SUB(NOW(), INTERVAL 90 DAY);
  ```

### Churn Rate
* **Definition**: Percentage of customers who have churned out of total registered accounts.
* **Formula**: `(Count of Churned / Total Customers) * 100`
* **SQL Logic**:
  ```sql
  SELECT
      ROUND(
          (COUNT(CASE WHEN status = 'churned' THEN 1 END) * 100.0) / COUNT(*),
          2
      ) AS churn_rate_percentage
  FROM customers;
  ```

---

## 3. SaaS & Subscription Metrics

### Monthly Recurring Revenue (MRR)
* **Definition**: The normalized monthly subscription value actively generating recurring revenue.
* **SQL Logic**:
  ```sql
  SELECT
      SUM(mrr_amount) AS total_mrr
  FROM subscriptions
  WHERE status = 'active';
  ```

### Annual Recurring Revenue (ARR)
* **Definition**: Annualized run rate of subscription revenue: `MRR * 12`.
* **SQL Logic**:
  ```sql
  SELECT
      ROUND(SUM(mrr_amount) * 12, 2) AS total_arr
  FROM subscriptions
  WHERE status = 'active';
  ```

### MRR Breakdown by Plan Tier
* **SQL Logic**:
  ```sql
  SELECT
      plan_tier,
      COUNT(subscription_id) AS active_subscribers,
      SUM(mrr_amount) AS total_plan_mrr,
      ROUND(AVG(mrr_amount), 2) AS arpu_per_tier
  FROM subscriptions
  WHERE status = 'active'
  GROUP BY plan_tier
  ORDER BY total_plan_mrr DESC;
  ```

---

## 4. Product & Inventory Metrics

### Top-Selling Products by Revenue
* **SQL Logic**:
  ```sql
  SELECT
      p.product_id,
      p.name AS product_name,
      p.sku,
      SUM(oi.quantity) AS units_sold,
      SUM(oi.total_price) AS total_revenue
  FROM products p
  INNER JOIN order_items oi ON p.product_id = oi.product_id
  INNER JOIN orders o ON oi.order_id = o.order_id
  WHERE o.status IN ('completed', 'shipped', 'delivered')
  GROUP BY p.product_id, p.name, p.sku
  ORDER BY total_revenue DESC
  LIMIT 10;
  ```

### Gross Margin per Product
* **Definition**: `(Retail Price - Cost Price) / Retail Price * 100`
* **SQL Logic**:
  ```sql
  SELECT
      product_id,
      name,
      retail_price,
      cost_price,
      (retail_price - cost_price) AS profit_per_unit,
      ROUND(((retail_price - cost_price) / retail_price) * 100, 2) AS gross_margin_percentage
  FROM products
  WHERE is_available = 1
  ORDER BY gross_margin_percentage DESC;
  ```

### Low Stock / Reorder Alert
* **Definition**: Products where current stock is at or below the predefined threshold.
* **SQL Logic**:
  ```sql
  SELECT
      product_id,
      sku,
      name,
      stock_quantity,
      low_stock_threshold,
      (low_stock_threshold - stock_quantity) AS units_needed
  FROM products
  WHERE stock_quantity <= low_stock_threshold
    AND is_available = 1
  ORDER BY stock_quantity ASC;
  ```

---

## 5. Order Fulfillment & Financial Health

### Refund Rate
* **Definition**: Percentage of orders that resulted in a refund or cancellation.
* **SQL Logic**:
  ```sql
  SELECT
      ROUND(
          (COUNT(CASE WHEN status IN ('refunded', 'cancelled') THEN 1 END) * 100.0) / COUNT(*),
          2
      ) AS refund_cancellation_rate_pct
  FROM orders;
  ```

### Payment Gateway Success Rate
* **SQL Logic**:
  ```sql
  SELECT
      payment_method,
      COUNT(*) AS total_attempts,
      COUNT(CASE WHEN status = 'captured' THEN 1 END) AS successful_payments,
      ROUND(
          (COUNT(CASE WHEN status = 'captured' THEN 1 END) * 100.0) / COUNT(*),
          2
      ) AS success_rate_pct
  FROM payments
  GROUP BY payment_method
  ORDER BY total_attempts DESC;
  ```

