# Few-Shot Text-to-SQL Examples

This document contains canonical Natural Language questions paired with verified, optimal MySQL 8.0 queries and explanations. These examples serve as vector retrieval training exemplars for the Bedrock Agent.

---

### Example 1: Basic Total Sales
* **Question**: "What is the total revenue generated from all delivered orders?"
* **SQL Query**:
  ```sql
  SELECT
      COALESCE(SUM(total_amount), 0.00) AS total_revenue
  FROM orders
  WHERE status = 'delivered';
  ```
* **Explanation**: Sums `total_amount` from `orders` filtering strictly by `status = 'delivered'`, using `COALESCE` to guard against empty sets.

---

### Example 2: Monthly Sales Trend
* **Question**: "Show me monthly revenue and order volume for the year 2026."
* **SQL Query**:
  ```sql
  SELECT
      DATE_FORMAT(order_date, '%Y-%m') AS order_month,
      COUNT(order_id) AS total_orders,
      SUM(total_amount) AS monthly_revenue
  FROM orders
  WHERE status IN ('completed', 'shipped', 'delivered')
    AND order_date >= '2026-01-01 00:00:00'
    AND order_date < '2027-01-01 00:00:00'
  GROUP BY DATE_FORMAT(order_date, '%Y-%m')
  ORDER BY order_month ASC;
  ```
* **Explanation**: Groups completed orders by year and month using `DATE_FORMAT`, filtering within the 2026 calendar year.

---

### Example 3: Top 5 Highest Spending Customers
* **Question**: "Who are our top 5 customers by total spending?"
* **SQL Query**:
  ```sql
  SELECT
      c.customer_id,
      CONCAT(c.first_name, ' ', c.last_name) AS full_name,
      c.email,
      c.customer_tier,
      SUM(o.total_amount) AS total_spent
  FROM customers c
  INNER JOIN orders o ON c.customer_id = o.customer_id
  WHERE o.status IN ('completed', 'shipped', 'delivered')
  GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.customer_tier
  ORDER BY total_spent DESC
  LIMIT 5;
  ```
* **Explanation**: Joins `customers` and `orders`, sums `total_amount`, orders descending by total spent, and limits the output to 5 rows.

---

### Example 4: Products with Low Inventory
* **Question**: "Which active products are running out of stock?"
* **SQL Query**:
  ```sql
  SELECT
      product_id,
      sku,
      name,
      stock_quantity,
      low_stock_threshold
  FROM products
  WHERE is_available = 1
    AND stock_quantity <= low_stock_threshold
  ORDER BY stock_quantity ASC;
  ```
* **Explanation**: Finds catalog products marked available where the warehouse count has fallen to or below the threshold.

---

### Example 5: Sales Breakdown by Category
* **Question**: "What is the total sales amount and quantity sold for each product category?"
* **SQL Query**:
  ```sql
  SELECT
      cat.category_id,
      cat.name AS category_name,
      COALESCE(SUM(oi.quantity), 0) AS total_units_sold,
      COALESCE(SUM(oi.total_price), 0.00) AS total_sales
  FROM categories cat
  LEFT JOIN products p ON cat.category_id = p.category_id
  LEFT JOIN order_items oi ON p.product_id = oi.product_id
  LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status IN ('completed', 'shipped', 'delivered')
  GROUP BY cat.category_id, cat.name
  ORDER BY total_sales DESC;
  ```
* **Explanation**: Uses `LEFT JOIN` so categories with zero sales are still represented, aggregating quantity and line-item revenue.

---

### Example 6: Active SaaS Subscriptions & Total MRR
* **Question**: "What is our current active Monthly Recurring Revenue (MRR) by plan tier?"
* **SQL Query**:
  ```sql
  SELECT
      plan_tier,
      COUNT(subscription_id) AS active_subscriptions,
      SUM(mrr_amount) AS total_mrr
  FROM subscriptions
  WHERE status = 'active'
  GROUP BY plan_tier
  ORDER BY total_mrr DESC;
  ```
* **Explanation**: Filters subscriptions with `status = 'active'` and aggregates active count and MRR per plan tier.

---

### Example 7: Average Review Rating by Product
* **Question**: "List the top 10 highest-rated products with at least 5 customer reviews."
* **SQL Query**:
  ```sql
  SELECT
      p.product_id,
      p.name AS product_name,
      ROUND(AVG(r.rating), 2) AS average_rating,
      COUNT(r.review_id) AS total_reviews
  FROM products p
  INNER JOIN reviews r ON p.product_id = r.product_id
  GROUP BY p.product_id, p.name
  HAVING COUNT(r.review_id) >= 5
  ORDER BY average_rating DESC, total_reviews DESC
  LIMIT 10;
  ```
* **Explanation**: Uses `HAVING` clause to filter out products with fewer than 5 reviews, sorting by rating and count.

---

### Example 8: Geographic Sales Distribution
* **Question**: "What are the top 5 countries by revenue from orders placed in the last 90 days?"
* **SQL Query**:
  ```sql
  SELECT
      shipping_country AS country,
      COUNT(order_id) AS order_count,
      SUM(total_amount) AS revenue
  FROM orders
  WHERE status IN ('completed', 'shipped', 'delivered')
    AND order_date >= DATE_SUB(NOW(), INTERVAL 90 DAY)
  GROUP BY shipping_country
  ORDER BY revenue DESC
  LIMIT 5;
  ```
* **Explanation**: Aggregates order totals grouped by destination country with a rolling 90-day time window.

---

### Example 9: Customers Who Have Never Placed an Order
* **Question**: "Find all registered customers who haven't placed any orders yet."
* **SQL Query**:
  ```sql
  SELECT
      c.customer_id,
      CONCAT(c.first_name, ' ', c.last_name) AS full_name,
      c.email,
      c.created_at
  FROM customers c
  LEFT JOIN orders o ON c.customer_id = o.customer_id
  WHERE o.order_id IS NULL
  ORDER BY c.created_at DESC;
  ```
* **Explanation**: Standard anti-join pattern using `LEFT JOIN` on `orders` and filtering where `o.order_id IS NULL`.

---

### Example 10: Repeat Customer Rate
* **Question**: "How many customers have placed more than one completed order?"
* **SQL Query**:
  ```sql
  WITH customer_order_counts AS (
      SELECT
          customer_id,
          COUNT(order_id) AS orders_placed
      FROM orders
      WHERE status IN ('completed', 'shipped', 'delivered')
      GROUP BY customer_id
  )
  SELECT
      COUNT(CASE WHEN orders_placed > 1 THEN 1 END) AS repeat_customers,
      COUNT(*) AS total_ordering_customers,
      ROUND(
          (COUNT(CASE WHEN orders_placed > 1 THEN 1 END) * 100.0) / COUNT(*),
          2
      ) AS repeat_rate_percentage
  FROM customer_order_counts;
  ```
* **Explanation**: Uses a CTE to count orders per customer, then computes the repeat buyer percentage in the outer query.

---

### Example 11: Products Bought Together
* **Question**: "Which pairs of products are most frequently purchased together in the same order?"
* **SQL Query**:
  ```sql
  SELECT
      p1.name AS product_a,
      p2.name AS product_b,
      COUNT(*) AS times_bought_together
  FROM order_items oi1
  INNER JOIN order_items oi2 ON oi1.order_id = oi2.order_id AND oi1.product_id < oi2.product_id
  INNER JOIN products p1 ON oi1.product_id = p1.product_id
  INNER JOIN products p2 ON oi2.product_id = p2.product_id
  GROUP BY p1.name, p2.name
  ORDER BY times_bought_together DESC
  LIMIT 10;
  ```
* **Explanation**: Self-joins `order_items` on matching `order_id` with `oi1.product_id < oi2.product_id` to prevent duplicate reciprocal pairs and self-pairing.

---

### Example 12: Order Refund Analysis
* **Question**: "What is the total refund amount and number of refunded orders by payment method?"
* **SQL Query**:
  ```sql
  SELECT
      payment_method,
      COUNT(order_id) AS refunded_orders,
      SUM(total_amount) AS total_refunded_amount
  FROM orders
  WHERE status = 'refunded'
  GROUP BY payment_method
  ORDER BY total_refunded_amount DESC;
  ```
* **Explanation**: Groups refunded orders by payment method and calculates count and refunded currency amounts.

