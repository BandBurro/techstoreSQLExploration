
-- Step 1: Check product availability
SELECT 
    product_id,
    product_name,
    price,
    stock_quantity
FROM products
WHERE product_name ILIKE '%RTX 4070%';

-- Step 2: Process the order using the stored procedure
CALL sp_process_new_order(
    p_customer_id := 1,      -- John Smith
    p_product_id := 9,      -- RTX 4070
    p_quantity := 1
); 

-- Step 3: Verify the order was created
SELECT 
    o.order_id,
    c.first_name || ' ' || c.last_name AS customer,
    o.order_date,
    o.total_amount,
    o.status
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_id = (SELECT MAX(order_id) FROM orders);

-- Step 4: View order details
SELECT 
    oi.order_item_id,
    p.product_name,
    oi.quantity,
    oi.unit_price,
    oi.subtotal
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
WHERE oi.order_id = (SELECT MAX(order_id) FROM orders);

-- Get total spent by a specific customer
SELECT 
    c.first_name || ' ' || c.last_name AS customer_name,
    fn_get_customer_total_spent(c.customer_id) AS total_spent
FROM customers c
WHERE c.customer_id = 1;

-- Compare all customers
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    COUNT(DISTINCT o.order_id) AS order_count,
    fn_get_customer_total_spent(c.customer_id) AS lifetime_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY lifetime_value DESC;

-- Before update: Check current price
SELECT product_id, product_name, price
FROM products
WHERE product_id = 6;  -- RTX 4090

-- Update the price (trigger will automatically audit)
UPDATE products
SET price = 1649.99
WHERE product_id = 6;

-- Verify the audit entry was created
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
WHERE pa.product_id = 6
ORDER BY pa.changed_at DESC
LIMIT 5;

-- Process multiple items for a single customer
-- This simulates adding items to a cart one by one
-- (In a real application, you might have a procedure that handles multiple items)

-- Order item 1
CALL sp_process_new_order(2, 19, 1);  -- Logitech Keyboard

-- Get the order_id that was just created
DO $$
DECLARE
    v_order_id INTEGER;
BEGIN
    SELECT MAX(order_id) INTO v_order_id FROM orders;
    
    -- Add another item to the same order
    -- Note: The current procedure creates a new order each time
    -- In production, you might want a procedure that adds items to existing orders
    RAISE NOTICE 'Order % created. To add more items, you may need to modify the order_items table directly or create an additional procedure.', v_order_id;
END $$;

-- Check low stock items
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    p.stock_quantity,
    CASE 
        WHEN p.stock_quantity = 0 THEN 'OUT OF STOCK'
        WHEN p.stock_quantity < 5 THEN 'LOW STOCK - REORDER NEEDED'
        WHEN p.stock_quantity < 10 THEN 'LOW STOCK'
        ELSE 'OK'
    END AS stock_status
FROM products p
JOIN categories c ON p.category_id = c.category_id
WHERE p.stock_quantity < 10
ORDER BY p.stock_quantity ASC;

-- Restock a product
UPDATE products
SET stock_quantity = stock_quantity + 50,
    updated_at = CURRENT_TIMESTAMP
WHERE product_id = 6;  -- RTX 4090

-- Verify stock update
SELECT product_id, product_name, stock_quantity, updated_at
FROM products
WHERE product_id = 6;

-- Daily sales report
SELECT 
    DATE(o.order_date) AS sale_date,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.customer_id) AS customers,
    SUM(o.total_amount) AS revenue,
    AVG(o.total_amount) AS avg_order_value
FROM orders o
WHERE o.status != 'cancelled'
  AND o.order_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(o.order_date)
ORDER BY sale_date DESC;

-- Top customers this month
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(o.total_amount) AS monthly_spending
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE DATE_TRUNC('month', o.order_date) = DATE_TRUNC('month', CURRENT_DATE)
  AND o.status != 'cancelled'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY monthly_spending DESC
LIMIT 10;

-- These examples show what happens when constraints are violated
-- Uncomment to test:

-- Test 1: Invalid customer_id
-- CALL sp_process_new_order(999, 1, 1);
-- Expected: ERROR: Customer with ID 999 does not exist

-- Test 2: Invalid product_id
-- CALL sp_process_new_order(1, 999, 1);
-- Expected: ERROR: Product with ID 999 does not exist

-- Test 3: Insufficient stock
-- First, check stock
SELECT product_id, product_name, stock_quantity 
FROM products 
WHERE product_id = 6;

-- Then try to order more than available
-- CALL sp_process_new_order(1, 6, 1000);
-- Expected: ERROR: Insufficient stock. Available: X, Requested: 1000

-- Test 4: Invalid quantity
-- CALL sp_process_new_order(1, 1, 0);
-- Expected: ERROR: Quantity must be greater than 0

-- Test 5: Negative price (CHECK constraint)
-- INSERT INTO products (product_name, category_id, price, stock_quantity)
-- VALUES ('Test Product', 1, -100, 10);
-- Expected: ERROR: new row for relation "products" violates check constraint "chk_price_positive"

-- Test 6: Duplicate email (UNIQUE constraint)
-- INSERT INTO customers (first_name, last_name, email)
-- VALUES ('Test', 'User', 'john.smith@email.com');
-- Expected: ERROR: duplicate key value violates unique constraint "customers_email_key"

-- Customer summary view
SELECT * FROM v_customer_summary
WHERE lifetime_value > 1000
ORDER BY lifetime_value DESC;

-- Product inventory view
SELECT * FROM v_product_inventory
WHERE stock_status IN ('CRITICAL', 'LOW')
ORDER BY stock_quantity ASC;

-- Order details view
SELECT * FROM v_order_details
WHERE order_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY order_date DESC;

-- View price change history for a specific product
SELECT 
    pa.changed_at,
    pa.old_price,
    pa.new_price,
    pa.new_price - pa.old_price AS change_amount,
    ROUND(((pa.new_price - pa.old_price) / pa.old_price * 100)::numeric, 2) AS percent_change,
    pa.changed_by
FROM price_audit pa
WHERE pa.product_id = 6  -- RTX 4090
ORDER BY pa.changed_at DESC;

-- Products with most price volatility
SELECT 
    p.product_name,
    c.category_name,
    COUNT(pa.audit_id) AS price_changes,
    MIN(pa.old_price) AS min_price,
    MAX(pa.new_price) AS max_price,
    MAX(pa.new_price) - MIN(pa.old_price) AS price_range
FROM price_audit pa
JOIN products p ON pa.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY p.product_id, p.product_name, c.category_name
HAVING COUNT(pa.audit_id) > 0
ORDER BY price_changes DESC;

-- Step 1: Customer browses products
SELECT 
    p.product_name,
    c.category_name,
    p.price,
    p.stock_quantity,
    CASE 
        WHEN p.stock_quantity > 0 THEN 'In Stock'
        ELSE 'Out of Stock'
    END AS availability
FROM products p
JOIN categories c ON p.category_id = c.category_id
WHERE c.category_name = 'GPU'
ORDER BY p.price DESC;

-- Step 2: Customer places order
CALL sp_process_new_order(
    p_customer_id := 3,      -- David Johnson
    p_product_id := 8,       -- AMD RX 7900 XTX
    p_quantity := 1
);

-- Step 3: Update order status to processing
UPDATE orders
SET status = 'processing'
WHERE order_id = (SELECT MAX(order_id) FROM orders);

-- Step 4: Ship the order
UPDATE orders
SET status = 'shipped'
WHERE order_id = (SELECT MAX(order_id) FROM orders);

-- Step 5: Mark as delivered
UPDATE orders
SET status = 'delivered'
WHERE order_id = (SELECT MAX(order_id) FROM orders);

-- Step 6: Verify customer's updated lifetime value
SELECT 
    c.first_name || ' ' || c.last_name AS customer_name,
    fn_get_customer_total_spent(c.customer_id) AS updated_lifetime_value
FROM customers c
WHERE c.customer_id = 3;

