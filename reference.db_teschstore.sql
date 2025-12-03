
-- Tables:
-- 1. categories (category_id, category_name, description, created_at)
-- 2. customers (customer_id, first_name, last_name, email, phone, address, ...)
-- 3. products (product_id, product_name, category_id, price, stock_quantity, ...)
-- 4. orders (order_id, customer_id, order_date, total_amount, status, ...)
-- 5. order_items (order_item_id, order_id, product_id, quantity, unit_price, ...)
-- 6. price_audit (audit_id, product_id, old_price, new_price, changed_at, ...)

-- Function: fn_get_customer_total_spent(customer_id)
-- Returns: DECIMAL - Total amount spent by customer
-- Example:
SELECT fn_get_customer_total_spent(1);

-- Procedure: sp_process_new_order(customer_id, product_id, quantity)
-- Creates new order, adds item, updates stock atomically
-- Example:
CALL sp_process_new_order(1, 9, 1);

-- Trigger: trg_audit_product_price_change
-- Automatically logs price changes to price_audit table
-- Triggered by: UPDATE on products table

-- Get all products with category
SELECT p.product_name, c.category_name, p.price, p.stock_quantity
FROM products p
JOIN categories c ON p.category_id = c.category_id;

-- Get customer orders
SELECT o.order_id, o.order_date, o.total_amount, o.status
FROM orders o
WHERE o.customer_id = 1;

-- Get order items for an order
SELECT p.product_name, oi.quantity, oi.unit_price, oi.subtotal
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
WHERE oi.order_id = 1;

-- Check low stock products
SELECT product_name, stock_quantity
FROM products
WHERE stock_quantity < 10;

-- View price audit log
SELECT p.product_name, pa.old_price, pa.new_price, pa.changed_at
FROM price_audit pa
JOIN products p ON pa.product_id = p.product_id
ORDER BY pa.changed_at DESC;

-- v_customer_summary - Customer details with order summary
SELECT * FROM v_customer_summary;

-- v_product_inventory - Product inventory overview with stock status
SELECT * FROM v_product_inventory WHERE stock_status = 'LOW';

-- v_order_details - Complete order information
SELECT * FROM v_order_details WHERE order_id = 1;

-- Roles:
-- - gerente: SELECT, INSERT, UPDATE, EXECUTE (no DELETE, ALTER, DROP, CREATE)
-- - desenvolvedor: Full access to all objects
-- Products:
--   - price > 0 (CHECK)
--   - stock_quantity >= 0 (CHECK)
--   - FK to categories

-- Customers:
--   - email UNIQUE
--   - email format validation (CHECK)

-- Orders:
--   - total_amount >= 0 (CHECK)
--   - status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')
--   - FK to customers

-- Order Items:
--   - quantity > 0 (CHECK)
--   - unit_price > 0 (CHECK)
--   - subtotal > 0 (CHECK)
--   - FK to orders and products

-- Add new product:
INSERT INTO products (product_name, category_id, price, stock_quantity, sku)
VALUES ('New Product', 1, 99.99, 10, 'SKU-001');

-- Update product price (triggers audit):
UPDATE products SET price = 109.99 WHERE product_id = 1;

-- Update order status:
UPDATE orders SET status = 'shipped' WHERE order_id = 1;

-- Restock product:
UPDATE products 
SET stock_quantity = stock_quantity + 50 
WHERE product_id = 1;

