# Entity Relationships & Join Graph

This document provides relational mapping, foreign key chains, cardinality, and recommended join patterns across the tables.

---

## 1. Visual Entity-Relationship Map

```
                +-------------------+
                |    categories     |
                +-------------------+
                    | 1         ^ parent_id
                    |           | (self-referential)
                    | N         |
                +-------------------+
                |     products      | <------+
                +-------------------+        |
                    | 1         ^ 1          |
                    |           |            |
                    | N         | N          |
+-------------------+   +------------------+ |
|      reviews      |   |   order_items    | |
+-------------------+   +------------------+ |
        | N                     | N          |
        |                       |            |
        | 1                     | 1          |
+-------------------+   +------------------+ |
|     customers     |---|      orders      | |
+-------------------+ 1 +------------------+ |
    | 1          | 1             | 1         |
    |            |               |           |
    | N          | N             | N         |
+-------------------+   +------------------+ |
|   subscriptions   |   |     payments     | |
+-------------------+   +------------------+ |
```

---

## 2. Foreign Key Definitions & Join Conditions

| Left Table | Right Table | Join Condition | Cardinality | Join Type Recommendation |
| :--- | :--- | :--- | :---: | :--- |
| `orders` | `customers` | `orders.customer_id = customers.customer_id` | N : 1 | `INNER JOIN` (orders always have a customer) |
| `orders` | `order_items` | `orders.order_id = order_items.order_id` | 1 : N | `INNER JOIN` for item analysis; `LEFT JOIN` if counting orders with or without items |
| `order_items` | `products` | `order_items.product_id = products.product_id` | N : 1 | `INNER JOIN` |
| `products` | `categories` | `products.category_id = categories.category_id` | N : 1 | `LEFT JOIN` (in case category is unassigned) or `INNER JOIN` |
| `categories` | `categories` (parent) | `child.parent_id = parent.category_id` | N : 1 | `LEFT JOIN` (top-level categories have `parent_id IS NULL`) |
| `orders` | `payments` | `orders.order_id = payments.order_id` | 1 : N | `LEFT JOIN` (some orders may be pending payment or have multiple attempts) |
| `customers` | `subscriptions`| `customers.customer_id = subscriptions.customer_id` | 1 : N | `LEFT JOIN` (not all customers have active subscriptions) |
| `products` | `reviews` | `products.product_id = reviews.product_id` | 1 : N | `LEFT JOIN` (new products may have 0 reviews) |
| `customers` | `reviews` | `customers.customer_id = reviews.customer_id` | 1 : N | `INNER JOIN` |

---

## 3. Common Traversal Patterns

### A. Customer Purchase History with Product Names
To list what products a customer has purchased:
```sql
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    o.order_id,
    o.order_date,
    p.name AS product_name,
    oi.quantity,
    oi.unit_price,
    oi.total_price
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id;
```

### B. Category Sales & Revenue Aggregation
To roll up order sales by product category:
```sql
SELECT
    cat.name AS category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.total_price) AS total_revenue
FROM categories cat
INNER JOIN products p ON cat.category_id = p.category_id
INNER JOIN order_items oi ON p.product_id = oi.product_id
INNER JOIN orders o ON oi.order_id = o.order_id
WHERE o.status IN ('completed', 'shipped', 'delivered')
GROUP BY cat.category_id, cat.name;
```

### C. Identifying Customer Subscription + Transaction Value
To see combined SaaS MRR and one-off purchase value per customer:
```sql
SELECT
    c.customer_id,
    c.email,
    COALESCE(s.mrr_amount, 0.00) AS monthly_subscription,
    COALESCE(SUM(o.total_amount), 0.00) AS total_order_spend
FROM customers c
LEFT JOIN subscriptions s ON c.customer_id = s.customer_id AND s.status = 'active'
LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.status IN ('completed', 'shipped', 'delivered')
GROUP BY c.customer_id, c.email, s.mrr_amount;
```

---

## 4. Critical Rules for Multi-Table Aggregations

1. **Beware of Duplication via `1:N` Multi-Joins**:
   - If joining `orders` with both `order_items` (1:N) and `payments` (1:N), summing `total_amount` or `payment.amount` will multiply values (Cartesian expansion).
   - **Remedy**: Aggregate line items in a subquery or Common Table Expression (CTE) first before joining with orders or payments:
   ```sql
   WITH item_totals AS (
       SELECT order_id, SUM(quantity) AS total_items, SUM(total_price) AS items_total
       FROM order_items
       GROUP BY order_id
   )
   SELECT o.order_id, o.total_amount, it.total_items
   FROM orders o
   JOIN item_totals it ON o.order_id = it.order_id;
   ```
2. **Filtered Status Joins**:
   - When calculating revenue or customer metrics, always filter `orders.status` to exclude `'cancelled'` or `'refunded'` unless the query specifically asks for refund analytics.

