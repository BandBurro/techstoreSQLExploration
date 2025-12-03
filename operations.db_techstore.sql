-- Get customer details with order summary
CREATE OR REPLACE VIEW v_customer_summary AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS full_name,
    c.email,
    c.phone,
    c.city || ', ' || c.state AS location,
    COUNT(DISTINCT o.order_id) AS total_orders,
    fn_get_customer_total_spent(c.customer_id) AS lifetime_value,
    MAX(o.order_date) AS last_order_date
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.phone, c.city, c.state;

-- Usage:
-- SELECT * FROM v_customer_summary ORDER BY lifetime_value DESC;

-- Find customers who haven't ordered recently
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    MAX(o.order_date) AS last_order_date,
    CURRENT_DATE - MAX(o.order_date)::date AS days_since_last_order
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email
HAVING MAX(o.order_date) IS NULL OR MAX(o.order_date) < CURRENT_DATE - INTERVAL '90 days'
ORDER BY days_since_last_order DESC NULLS FIRST;

-- Product inventory overview
CREATE OR REPLACE VIEW v_product_inventory AS
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    p.sku,
    p.price,
    p.stock_quantity,
    COALESCE(SUM(oi.quantity), 0) AS total_sold,
    CASE 
        WHEN p.stock_quantity = 0 THEN 'CRITICAL'
        WHEN p.stock_quantity < 5 THEN 'LOW'
        WHEN p.stock_quantity < 15 THEN 'MEDIUM'
        ELSE 'OK'
    END AS stock_status,
    p.stock_quantity * p.price AS inventory_value
FROM products p
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, c.category_name, p.sku, p.price, p.stock_quantity
ORDER BY stock_status, p.stock_quantity ASC;

-- Usage:
-- SELECT * FROM v_product_inventory WHERE stock_status IN ('CRITICAL', 'LOW');

-- Products that need restocking
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    p.stock_quantity,
    p.price,
    COALESCE(SUM(oi.quantity), 0) AS units_sold_last_30_days
FROM products p
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
    AND EXISTS (
        SELECT 1 FROM orders o 
        WHERE o.order_id = oi.order_id 
        AND o.order_date >= CURRENT_DATE - INTERVAL '30 days'
    )
WHERE p.stock_quantity < 10
GROUP BY p.product_id, p.product_name, c.category_name, p.stock_quantity, p.price
ORDER BY p.stock_quantity ASC;

-- Total inventory value by category
SELECT 
    c.category_name,
    COUNT(p.product_id) AS product_count,
    SUM(p.stock_quantity) AS total_units,
    SUM(p.stock_quantity * p.price) AS total_value,
    AVG(p.price) AS avg_price
FROM categories c
JOIN products p ON c.category_id = p.category_id
GROUP BY c.category_id, c.category_name
ORDER BY total_value DESC;

-- Daily sales summary
SELECT 
    DATE(o.order_date) AS sale_date,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(o.total_amount) AS daily_revenue,
    AVG(o.total_amount) AS avg_order_value
FROM orders o
WHERE o.status != 'cancelled'
GROUP BY DATE(o.order_date)
ORDER BY sale_date DESC
LIMIT 30;

-- Monthly sales report
SELECT 
    DATE_TRUNC('month', o.order_date) AS month,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(o.total_amount) AS monthly_revenue,
    AVG(o.total_amount) AS avg_order_value,
    SUM(oi.quantity) AS total_units_sold
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status != 'cancelled'
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY month DESC;

-- Sales by product category (last 30 days)
SELECT 
    c.category_name,
    COUNT(DISTINCT oi.order_id) AS orders,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.subtotal) AS revenue,
    AVG(oi.unit_price) AS avg_selling_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
  AND o.status != 'cancelled'
GROUP BY c.category_id, c.category_name
ORDER BY revenue DESC;

-- Top performing products (last 90 days)
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    COUNT(DISTINCT oi.order_id) AS times_ordered,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.subtotal) AS revenue,
    AVG(oi.unit_price) AS avg_selling_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '90 days'
  AND o.status != 'cancelled'
GROUP BY p.product_id, p.product_name, c.category_name
ORDER BY revenue DESC
LIMIT 20;

-- Pending orders requiring attention
SELECT 
    o.order_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    o.order_date,
    o.total_amount,
    o.status,
    COUNT(oi.order_item_id) AS item_count
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status IN ('pending', 'processing')
GROUP BY o.order_id, c.first_name, c.last_name, o.order_date, o.total_amount, o.status
ORDER BY o.order_date ASC;

-- Order details view
CREATE OR REPLACE VIEW v_order_details AS
SELECT 
    o.order_id,
    o.order_date,
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email AS customer_email,
    o.status,
    o.total_amount,
    COUNT(oi.order_item_id) AS item_count,
    STRING_AGG(p.product_name, ', ' ORDER BY oi.order_item_id) AS products
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
GROUP BY o.order_id, o.order_date, c.customer_id, c.first_name, c.last_name, 
         c.email, o.status, o.total_amount;

-- Usage:
-- SELECT * FROM v_order_details WHERE order_id = 1;

-- Average order value by customer segment
SELECT 
    CASE 
        WHEN fn_get_customer_total_spent(c.customer_id) >= 5000 THEN 'VIP'
        WHEN fn_get_customer_total_spent(c.customer_id) >= 2000 THEN 'Premium'
        WHEN fn_get_customer_total_spent(c.customer_id) >= 500 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    COUNT(DISTINCT o.order_id) AS total_orders,
    AVG(o.total_amount) AS avg_order_value,
    SUM(o.total_amount) AS segment_revenue
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status != 'cancelled' OR o.status IS NULL
GROUP BY customer_segment
ORDER BY avg_order_value DESC;

-- Recent price changes summary
SELECT 
    p.product_name,
    c.category_name,
    COUNT(pa.audit_id) AS price_changes,
    MIN(pa.old_price) AS lowest_price,
    MAX(pa.new_price) AS highest_price,
    MAX(pa.changed_at) AS last_change_date
FROM price_audit pa
JOIN products p ON pa.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY p.product_id, p.product_name, c.category_name
HAVING COUNT(pa.audit_id) > 0
ORDER BY price_changes DESC, last_change_date DESC;

-- Price change trends (products with most frequent changes)
SELECT 
    p.product_name,
    c.category_name,
    COUNT(pa.audit_id) AS change_count,
    AVG(pa.new_price - pa.old_price) AS avg_price_change,
    SUM(CASE WHEN pa.new_price > pa.old_price THEN 1 ELSE 0 END) AS price_increases,
    SUM(CASE WHEN pa.new_price < pa.old_price THEN 1 ELSE 0 END) AS price_decreases
FROM price_audit pa
JOIN products p ON pa.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY p.product_id, p.product_name, c.category_name
HAVING COUNT(pa.audit_id) >= 2
ORDER BY change_count DESC;

-- Customer acquisition and retention
SELECT 
    DATE_TRUNC('month', c.created_at) AS acquisition_month,
    COUNT(DISTINCT c.customer_id) AS new_customers,
    COUNT(DISTINCT o.customer_id) AS customers_with_orders,
    ROUND(100.0 * COUNT(DISTINCT o.customer_id) / COUNT(DISTINCT c.customer_id), 2) AS conversion_rate
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY DATE_TRUNC('month', c.created_at)
ORDER BY acquisition_month DESC;

-- Product performance matrix
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    p.price,
    p.stock_quantity,
    COALESCE(SUM(oi.quantity), 0) AS total_sold,
    COALESCE(SUM(oi.subtotal), 0) AS total_revenue,
    CASE 
        WHEN COALESCE(SUM(oi.quantity), 0) = 0 THEN 'No Sales'
        WHEN p.stock_quantity = 0 THEN 'Out of Stock'
        WHEN p.stock_quantity < SUM(oi.quantity) / 30.0 THEN 'High Demand'
        ELSE 'Normal'
    END AS performance_status
FROM products p
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status != 'cancelled'
GROUP BY p.product_id, p.product_name, c.category_name, p.price, p.stock_quantity
ORDER BY total_revenue DESC;

-- Clean up old audit records (keep last 1000)
-- DELETE FROM price_audit 
-- WHERE audit_id NOT IN (
--     SELECT audit_id FROM price_audit 
--     ORDER BY changed_at DESC 
--     LIMIT 1000
-- );

-- Update order totals (if needed after manual changes)
-- UPDATE orders o
-- SET total_amount = (
--     SELECT COALESCE(SUM(subtotal), 0)
--     FROM order_items oi
--     WHERE oi.order_id = o.order_id
-- );

