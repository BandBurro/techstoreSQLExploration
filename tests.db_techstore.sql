
-- Test for customer with multiple orders
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    fn_get_customer_total_spent(c.customer_id) AS total_spent
FROM customers c
ORDER BY total_spent DESC;

-- Test for specific customer (John Smith - customer_id 1)
SELECT 
    'John Smith' AS customer,
    fn_get_customer_total_spent(1) AS total_lifetime_value;

-- Test for customer with no orders (should return 0)
-- First, let's see all customers and their totals
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    COUNT(o.order_id) AS order_count,
    fn_get_customer_total_spent(c.customer_id) AS total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC NULLS LAST;

-- Test 1: Process a valid order
-- Customer 1 (John Smith) orders 2 units of product 19 (Logitech Keyboard)
CALL sp_process_new_order(1, 19, 2);

-- Verify the order was created
SELECT 
    o.order_id,
    c.first_name || ' ' || c.last_name AS customer,
    o.order_date,
    o.total_amount,
    o.status
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
ORDER BY o.order_id DESC
LIMIT 5;

-- Verify order items
SELECT 
    oi.order_item_id,
    oi.order_id,
    p.product_name,
    oi.quantity,
    oi.unit_price,
    oi.subtotal
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
ORDER BY oi.order_id DESC, oi.order_item_id DESC
LIMIT 5;

-- Verify stock was updated
SELECT 
    product_id,
    product_name,
    stock_quantity
FROM products
WHERE product_id = 19;

-- Test 2: Try to order more than available stock (should fail)
-- First, check current stock
SELECT product_id, product_name, stock_quantity 
FROM products 
WHERE product_id = 6;  -- RTX 4090

-- This should raise an exception
-- CALL sp_process_new_order(2, 6, 100);

-- Test 3: Try to order with invalid customer_id (should fail)
-- CALL sp_process_new_order(999, 1, 1);

-- Test 4: Try to order with invalid product_id (should fail)
-- CALL sp_process_new_order(1, 999, 1);    

-- View current prices
SELECT product_id, product_name, price, updated_at
FROM products
WHERE product_id IN (1, 6, 10)
ORDER BY product_id;

-- View current audit log
SELECT * FROM price_audit ORDER BY changed_at DESC LIMIT 10;

-- Update a product price (should trigger audit)
UPDATE products
SET price = 599.99
WHERE product_id = 1;  -- Intel i9-13900K (was 589.99)

-- Update another product price
UPDATE products
SET price = 1649.99
WHERE product_id = 6;  -- RTX 4090 (was 1599.99)

-- Update multiple prices
UPDATE products
SET price = price * 0.95  -- 5% discount
WHERE category_id = 3;  -- Memory category

-- Verify audit entries were created
SELECT 
    pa.audit_id,
    p.product_name,
    pa.old_price,
    pa.new_price,
    pa.new_price - pa.old_price AS price_change,
    pa.changed_at,
    pa.changed_by
FROM price_audit pa
JOIN products p ON pa.product_id = p.product_id
ORDER BY pa.changed_at DESC;

-- Check all constraints are working
-- Test CHECK constraint on price (should fail)
-- INSERT INTO products (product_name, category_id, price, stock_quantity) 
-- VALUES ('Test Product', 1, -10, 5);

-- Test UNIQUE constraint on email (should fail)
-- INSERT INTO customers (first_name, last_name, email) 
-- VALUES ('Test', 'User', 'john.smith@email.com');

-- Test UNIQUE constraint on SKU (should fail)
-- INSERT INTO products (product_name, category_id, price, stock_quantity, sku) 
-- VALUES ('Test Product', 1, 100, 5, 'CPU-INTEL-I9-13900K');

-- Test FOREIGN KEY constraint (should fail)
-- INSERT INTO products (product_name, category_id, price, stock_quantity) 
-- VALUES ('Test Product', 999, 100, 5);

-- Top 10 customers by total spent
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    COUNT(DISTINCT o.order_id) AS total_orders,
    fn_get_customer_total_spent(c.customer_id) AS total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email
ORDER BY total_spent DESC
LIMIT 10;

-- Top selling products
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.subtotal) AS total_revenue,
    COUNT(DISTINCT oi.order_id) AS times_ordered
FROM products p
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, c.category_name
ORDER BY total_revenue DESC
LIMIT 10;

-- Revenue by category
SELECT 
    c.category_name,
    COUNT(DISTINCT oi.product_id) AS products_sold,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.subtotal) AS total_revenue,
    AVG(oi.unit_price) AS avg_price
FROM categories c
JOIN products p ON c.category_id = p.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY c.category_id, c.category_name
ORDER BY total_revenue DESC;

-- Order status distribution
SELECT 
    status,
    COUNT(*) AS order_count,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS avg_order_value
FROM orders
GROUP BY status
ORDER BY order_count DESC;

-- Products low on stock
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    p.stock_quantity,
    p.price,
    CASE 
        WHEN p.stock_quantity = 0 THEN 'Out of Stock'
        WHEN p.stock_quantity < 5 THEN 'Low Stock'
        WHEN p.stock_quantity < 10 THEN 'Medium Stock'
        ELSE 'In Stock'
    END AS stock_status
FROM products p
JOIN categories c ON p.category_id = c.category_id
WHERE p.stock_quantity < 10
ORDER BY p.stock_quantity ASC;

-- Recent price changes (from audit log)
SELECT 
    p.product_name,
    c.category_name,
    pa.old_price,
    pa.new_price,
    ROUND(((pa.new_price - pa.old_price) / pa.old_price * 100)::numeric, 2) AS percent_change,
    pa.changed_at,
    pa.changed_by
FROM price_audit pa
JOIN products p ON pa.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
ORDER BY pa.changed_at DESC
LIMIT 20;

-- Verify order totals match sum of order_items
SELECT 
    o.order_id,
    o.total_amount AS order_total,
    COALESCE(SUM(oi.subtotal), 0) AS calculated_total,
    o.total_amount - COALESCE(SUM(oi.subtotal), 0) AS difference
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.total_amount
HAVING ABS(o.total_amount - COALESCE(SUM(oi.subtotal), 0)) > 0.01
ORDER BY o.order_id;

-- Check for orphaned order_items
SELECT oi.*
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Check for orphaned products
SELECT p.*
FROM products p
LEFT JOIN categories c ON p.category_id = c.category_id
WHERE c.category_id IS NULL;

-- Verify stock quantities are non-negative
SELECT product_id, product_name, stock_quantity
FROM products
WHERE stock_quantity < 0;