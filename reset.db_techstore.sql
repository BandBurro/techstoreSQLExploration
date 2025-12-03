-- Drop all objects in reverse dependency order
DROP TRIGGER IF EXISTS trg_audit_product_price_change ON products CASCADE;
DROP FUNCTION IF EXISTS fn_audit_product_price_change() CASCADE;
DROP FUNCTION IF EXISTS fn_get_customer_total_spent(INTEGER) CASCADE;
DROP PROCEDURE IF EXISTS sp_process_new_order(INTEGER, INTEGER, INTEGER) CASCADE;

-- Drop views
DROP VIEW IF EXISTS v_customer_summary CASCADE;
DROP VIEW IF EXISTS v_product_inventory CASCADE;
DROP VIEW IF EXISTS v_order_details CASCADE;

-- Drop tables (CASCADE will handle dependencies)
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS price_audit CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- Drop roles (optional - comment out if you want to keep roles)
-- DROP ROLE IF EXISTS professor;
-- DROP ROLE IF EXISTS techstore_developer;

-- Note: After running this script, execute 4-Scripts_Criacao.sql to recreate everything

