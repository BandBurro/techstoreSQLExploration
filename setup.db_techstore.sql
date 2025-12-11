-- Create schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS db_techstore;

-- Drop existing objects if they exist (for clean setup)
DROP TRIGGER IF EXISTS trg_audit_product_price_change ON db_techstore.products;
DROP FUNCTION IF EXISTS db_techstore.fn_audit_product_price_change() CASCADE;
DROP FUNCTION IF EXISTS db_techstore.fn_get_customer_total_spent(INTEGER) CASCADE;
DROP PROCEDURE IF EXISTS db_techstore.sp_process_new_order(INTEGER, INTEGER, INTEGER) CASCADE;

DROP TABLE IF EXISTS db_techstore.order_items CASCADE;
DROP TABLE IF EXISTS db_techstore.orders CASCADE;
DROP TABLE IF EXISTS db_techstore.price_audit CASCADE;
DROP TABLE IF EXISTS db_techstore.products CASCADE;
DROP TABLE IF EXISTS db_techstore.categories CASCADE;
DROP TABLE IF EXISTS db_techstore.customers CASCADE;

-- ----------------------------------------------------------------------------
-- Table: categories
-- Description: Product classifications (CPU, GPU, Peripherals, etc.)
-- ----------------------------------------------------------------------------
CREATE TABLE db_techstore.categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- Table: customers
-- Description: Registered users information
-- Constraints: UNIQUE email
-- ----------------------------------------------------------------------------
CREATE TABLE db_techstore.customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- ----------------------------------------------------------------------------
-- Table: products
-- Description: Inventory items with stock and pricing
-- Constraints: CHECK price > 0, FK to categories
-- ----------------------------------------------------------------------------
CREATE TABLE db_techstore.products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    description TEXT,
    category_id INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    sku VARCHAR(50) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_product_category FOREIGN KEY (category_id) 
        REFERENCES db_techstore.categories(category_id) ON DELETE RESTRICT,
    CONSTRAINT chk_price_positive CHECK (price > 0),
    CONSTRAINT chk_stock_non_negative CHECK (stock_quantity >= 0)
);

-- ----------------------------------------------------------------------------
-- Table: orders
-- Description: Purchase headers linked to customers
-- ----------------------------------------------------------------------------
CREATE TABLE db_techstore.orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    shipping_address TEXT,
    notes TEXT,
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) 
        REFERENCES db_techstore.customers(customer_id) ON DELETE RESTRICT,
    CONSTRAINT chk_order_total_non_negative CHECK (total_amount >= 0),
    CONSTRAINT chk_order_status CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled'))
);

-- ----------------------------------------------------------------------------
-- Table: order_items
-- Description: Purchase details linking orders to products
-- ----------------------------------------------------------------------------
CREATE TABLE db_techstore.order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    CONSTRAINT fk_order_item_order FOREIGN KEY (order_id) 
        REFERENCES db_techstore.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_item_product FOREIGN KEY (product_id) 
        REFERENCES db_techstore.products(product_id) ON DELETE RESTRICT,
    CONSTRAINT chk_quantity_positive CHECK (quantity > 0),
    CONSTRAINT chk_unit_price_positive CHECK (unit_price > 0),
    CONSTRAINT chk_subtotal_positive CHECK (subtotal > 0)
);

-- ----------------------------------------------------------------------------
-- Table: price_audit
-- Description: Audit trail for product price changes (used by trigger)
-- ----------------------------------------------------------------------------
CREATE TABLE db_techstore.price_audit (
    audit_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    old_price DECIMAL(10, 2) NOT NULL,
    new_price DECIMAL(10, 2) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100),
    CONSTRAINT fk_audit_product FOREIGN KEY (product_id) 
        REFERENCES db_techstore.products(product_id) ON DELETE CASCADE,
    CONSTRAINT chk_price_change CHECK (old_price != new_price)
);

-- Create indexes for better performance
CREATE INDEX idx_products_category ON db_techstore.products(category_id);
CREATE INDEX idx_orders_customer ON db_techstore.orders(customer_id);
CREATE INDEX idx_order_items_order ON db_techstore.order_items(order_id);
CREATE INDEX idx_order_items_product ON db_techstore.order_items(product_id);
CREATE INDEX idx_price_audit_product ON db_techstore.price_audit(product_id);
CREATE INDEX idx_price_audit_date ON db_techstore.price_audit(changed_at);

-- Insert Categories
INSERT INTO db_techstore.categories (category_name, description) VALUES
('CPU', 'Central Processing Units - High-performance processors for computing'),
('GPU', 'Graphics Processing Units - Video cards for gaming and rendering'),
('Memory', 'RAM modules for system memory expansion'),
('Storage', 'SSD and HDD drives for data storage'),
('Motherboard', 'Main system boards connecting all components'),
('Peripherals', 'Keyboards, mice, monitors, and other accessories'),
('Cooling', 'CPU coolers, case fans, and liquid cooling solutions'),
('Power Supply', 'PSU units providing power to the system');

-- Insert Customers
INSERT INTO db_techstore.customers (first_name, last_name, email, phone, address, city, state, zip_code) VALUES
('John', 'Smith', 'john.smith@email.com', '(555) 123-4567', '123 Main St', 'New York', 'NY', '10001'),
('Maria', 'Garcia', 'maria.garcia@email.com', '(555) 234-5678', '456 Oak Ave', 'Los Angeles', 'CA', '90001'),
('David', 'Johnson', 'david.johnson@email.com', '(555) 345-6789', '789 Pine Rd', 'Chicago', 'IL', '60601'),
('Sarah', 'Williams', 'sarah.williams@email.com', '(555) 456-7890', '321 Elm St', 'Houston', 'TX', '77001'),
('Michael', 'Brown', 'michael.brown@email.com', '(555) 567-8901', '654 Maple Dr', 'Phoenix', 'AZ', '85001'),
('Emily', 'Davis', 'emily.davis@email.com', '(555) 678-9012', '987 Cedar Ln', 'Philadelphia', 'PA', '19101'),
('James', 'Miller', 'james.miller@email.com', '(555) 789-0123', '147 Birch Way', 'San Antonio', 'TX', '78201'),
('Jessica', 'Wilson', 'jessica.wilson@email.com', '(555) 890-1234', '258 Spruce Ct', 'San Diego', 'CA', '92101'),
('Robert', 'Moore', 'robert.moore@email.com', '(555) 901-2345', '369 Willow Blvd', 'Dallas', 'TX', '75201'),
('Amanda', 'Taylor', 'amanda.taylor@email.com', '(555) 012-3456', '741 Ash St', 'San Jose', 'CA', '95101');

-- Insert Products
INSERT INTO db_techstore.products (product_name, description, category_id, price, stock_quantity, sku) VALUES
-- CPUs
('Intel Core i9-13900K', '13th Gen Intel Core i9, 24 cores, 5.8GHz boost', 1, 589.99, 15, 'CPU-INTEL-I9-13900K'),
('AMD Ryzen 9 7950X', 'AMD Ryzen 9, 16 cores, 5.7GHz boost, AM5 socket', 1, 699.99, 12, 'CPU-AMD-R9-7950X'),
('Intel Core i7-13700K', '13th Gen Intel Core i7, 16 cores, 5.4GHz boost', 1, 419.99, 20, 'CPU-INTEL-I7-13700K'),
('AMD Ryzen 7 7800X3D', 'AMD Ryzen 7 with 3D V-Cache, 8 cores, optimized for gaming', 1, 449.99, 18, 'CPU-AMD-R7-7800X3D'),
('Intel Core i5-13600K', '13th Gen Intel Core i5, 14 cores, 5.1GHz boost', 1, 319.99, 25, 'CPU-INTEL-I5-13600K'),
-- GPUs
('NVIDIA RTX 4090', '24GB GDDR6X, Ada Lovelace architecture, 4K gaming', 2, 1599.99, 8, 'GPU-NVIDIA-RTX-4090'),
('NVIDIA RTX 4080', '16GB GDDR6X, High-end gaming and content creation', 2, 1199.99, 10, 'GPU-NVIDIA-RTX-4080'),
('AMD RX 7900 XTX', '24GB GDDR6, RDNA 3 architecture, 4K gaming', 2, 999.99, 12, 'GPU-AMD-RX-7900-XTX'),
('NVIDIA RTX 4070', '12GB GDDR6X, 1440p gaming powerhouse', 2, 599.99, 15, 'GPU-NVIDIA-RTX-4070'),
('AMD RX 7800 XT', '16GB GDDR6, Excellent 1440p performance', 2, 499.99, 18, 'GPU-AMD-RX-7800-XT'),
-- Memory
('Corsair Vengeance DDR5 32GB', '32GB (2x16GB) DDR5-6000, CL30', 3, 129.99, 30, 'MEM-CORSAIR-32GB-DDR5'),
('G.Skill Trident Z5 32GB', '32GB (2x16GB) DDR5-6400, CL32, RGB', 3, 149.99, 25, 'MEM-GSKILL-32GB-DDR5'),
('Kingston Fury Beast 16GB', '16GB (2x8GB) DDR5-5600, CL36', 3, 79.99, 40, 'MEM-KINGSTON-16GB-DDR5'),
-- Storage
('Samsung 990 PRO 2TB', '2TB NVMe PCIe 4.0 SSD, 7450MB/s read', 4, 179.99, 20, 'SSD-SAMSUNG-990PRO-2TB'),
('WD Black SN850X 1TB', '1TB NVMe PCIe 4.0 SSD, 7300MB/s read', 4, 99.99, 25, 'SSD-WD-SN850X-1TB'),
('Crucial P5 Plus 2TB', '2TB NVMe PCIe 4.0 SSD, 6600MB/s read', 4, 149.99, 22, 'SSD-CRUCIAL-P5-2TB'),
-- Motherboards
('ASUS ROG Strix X670E', 'AMD X670E, AM5 socket, PCIe 5.0, WiFi 6E', 5, 449.99, 10, 'MB-ASUS-X670E'),
('MSI MPG Z790 Carbon', 'Intel Z790, LGA1700, PCIe 5.0, WiFi 6E', 5, 399.99, 12, 'MB-MSI-Z790-CARBON'),
('Gigabyte B650 Aorus Elite', 'AMD B650, AM5 socket, PCIe 4.0, WiFi 6', 5, 199.99, 15, 'MB-GIGABYTE-B650'),
-- Peripherals
('Logitech G Pro X Keyboard', 'Mechanical gaming keyboard, RGB, tenkeyless', 6, 129.99, 30, 'PER-LOGITECH-GPRO-KB'),
('Razer DeathAdder V3', 'Gaming mouse, 30K DPI, wireless', 6, 149.99, 35, 'PER-RAZER-DEATHADDER-V3'),
('ASUS ROG Swift PG279QM', '27" 1440p 240Hz gaming monitor, G-Sync', 6, 699.99, 8, 'MON-ASUS-PG279QM'),
-- Cooling
('Noctua NH-D15', 'Dual-tower CPU air cooler, 140mm fans', 7, 99.99, 20, 'COOL-NOCTUA-NH-D15'),
('Corsair H150i Elite', '360mm AIO liquid cooler, RGB, AM5/LGA1700', 7, 199.99, 15, 'COOL-CORSAIR-H150I'),
-- Power Supply
('Corsair RM1000x', '1000W 80+ Gold, fully modular, ATX 3.0', 8, 189.99, 18, 'PSU-CORSAIR-RM1000X'),
('Seasonic Focus GX-850', '850W 80+ Gold, fully modular', 8, 129.99, 22, 'PSU-SEASONIC-GX850');

-- Insert Orders (with historical data)
INSERT INTO db_techstore.orders (customer_id, order_date, total_amount, status, shipping_address, notes) VALUES
(1, '2024-10-15 10:30:00', 0, 'delivered', '123 Main St, New York, NY 10001', 'First order'),
(2, '2024-10-18 14:20:00', 0, 'shipped', '456 Oak Ave, Los Angeles, CA 90001', 'Gaming build'),
(1, '2024-10-20 09:15:00', 0, 'delivered', '123 Main St, New York, NY 10001', 'Upgrade components'),
(3, '2024-10-22 16:45:00', 0, 'processing', '789 Pine Rd, Chicago, IL 60601', 'New system'),
(4, '2024-10-25 11:00:00', 0, 'delivered', '321 Elm St, Houston, TX 77001', 'Workstation build'),
(2, '2024-10-28 13:30:00', 0, 'shipped', '456 Oak Ave, Los Angeles, CA 90001', 'Additional storage'),
(5, '2024-11-01 10:00:00', 0, 'pending', '654 Maple Dr, Phoenix, AZ 85001', 'Budget build'),
(6, '2024-11-03 15:20:00', 0, 'delivered', '987 Cedar Ln, Philadelphia, PA 19101', 'Gaming setup'),
(7, '2024-11-05 09:45:00', 0, 'processing', '147 Birch Way, San Antonio, TX 78201', 'High-end build'),
(8, '2024-11-08 12:10:00', 0, 'shipped', '258 Spruce Ct, San Diego, CA 92101', 'Content creation');

-- Insert Order Items (updating order totals will be handled by procedures)
INSERT INTO db_techstore.order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES
-- Order 1
(1, 1, 1, 589.99, 589.99),  -- Intel i9-13900K
(1, 6, 1, 1599.99, 1599.99),  -- RTX 4090
(1, 10, 1, 129.99, 129.99),  -- Corsair 32GB DDR5
(1, 13, 1, 179.99, 179.99),  -- Samsung 990 PRO 2TB
-- Order 2
(2, 4, 1, 449.99, 449.99),  -- AMD Ryzen 7 7800X3D
(2, 9, 1, 599.99, 599.99),  -- RTX 4070
(2, 11, 1, 149.99, 149.99),  -- G.Skill 32GB DDR5
(2, 14, 1, 99.99, 99.99),  -- WD Black SN850X 1TB
(2, 16, 1, 199.99, 199.99),  -- Gigabyte B650
(2, 20, 1, 99.99, 99.99),  -- Noctua NH-D15
(2, 22, 1, 129.99, 129.99),  -- Seasonic 850W
-- Order 3
(3, 8, 1, 999.99, 999.99),  -- AMD RX 7900 XTX
(3, 15, 1, 149.99, 149.99),  -- Razer DeathAdder V3
-- Order 4
(4, 2, 1, 699.99, 699.99),  -- AMD Ryzen 9 7950X
(4, 7, 1, 1199.99, 1199.99),  -- RTX 4080
(4, 10, 1, 129.99, 129.99),  -- Corsair 32GB DDR5
(4, 13, 2, 179.99, 359.98),  -- Samsung 990 PRO 2TB (x2)
(4, 15, 1, 449.99, 449.99),  -- ASUS ROG Strix X670E
(4, 21, 1, 199.99, 199.99),  -- Corsair H150i Elite
(4, 22, 1, 189.99, 189.99),  -- Corsair RM1000x
-- Order 5
(5, 3, 1, 419.99, 419.99),  -- Intel i7-13700K
(5, 9, 1, 599.99, 599.99),  -- RTX 4070
(5, 10, 1, 129.99, 129.99),  -- Corsair 32GB DDR5
(5, 14, 1, 99.99, 99.99),  -- WD Black SN850X 1TB
(5, 16, 1, 399.99, 399.99),  -- MSI MPG Z790 Carbon
-- Order 6
(6, 15, 1, 149.99, 149.99),  -- Crucial P5 Plus 2TB
-- Order 7
(7, 5, 1, 319.99, 319.99),  -- Intel i5-13600K
(7, 10, 1, 499.99, 499.99),  -- AMD RX 7800 XT
(7, 12, 1, 79.99, 79.99),  -- Kingston 16GB DDR5
(7, 15, 1, 149.99, 149.99),  -- Crucial P5 Plus 2TB
(7, 17, 1, 199.99, 199.99),  -- Gigabyte B650
(7, 20, 1, 99.99, 99.99),  -- Noctua NH-D15
(7, 22, 1, 129.99, 129.99),  -- Seasonic 850W
-- Order 8
(8, 4, 1, 449.99, 449.99),  -- AMD Ryzen 7 7800X3D
(8, 9, 1, 599.99, 599.99),  -- RTX 4070
(8, 11, 1, 149.99, 149.99),  -- G.Skill 32GB DDR5
(8, 14, 1, 99.99, 99.99),  -- WD Black SN850X 1TB
(8, 19, 1, 129.99, 129.99),  -- Logitech G Pro X Keyboard
(8, 20, 1, 149.99, 149.99),  -- Razer DeathAdder V3
(8, 21, 1, 699.99, 699.99),  -- ASUS ROG Swift monitor
-- Order 9
(9, 1, 1, 589.99, 589.99),  -- Intel i9-13900K
(9, 6, 1, 1599.99, 1599.99),  -- RTX 4090
(9, 10, 2, 129.99, 259.98),  -- Corsair 32GB DDR5 (x2 = 64GB)
(9, 13, 2, 179.99, 359.98),  -- Samsung 990 PRO 2TB (x2)
(9, 16, 1, 449.99, 449.99),  -- ASUS ROG Strix X670E
(9, 21, 1, 199.99, 199.99),  -- Corsair H150i Elite
(9, 22, 1, 189.99, 189.99),  -- Corsair RM1000x
-- Order 10
(10, 2, 1, 699.99, 699.99),  -- AMD Ryzen 9 7950X
(10, 7, 1, 1199.99, 1199.99),  -- RTX 4080
(10, 11, 1, 149.99, 149.99),  -- G.Skill 32GB DDR5
(10, 15, 1, 149.99, 149.99),  -- Crucial P5 Plus 2TB
(10, 15, 1, 449.99, 449.99),  -- ASUS ROG Strix X670E
(10, 21, 1, 199.99, 199.99);  -- Corsair H150i Elite

-- Update order totals based on order_items
UPDATE db_techstore.orders o
SET total_amount = (
    SELECT COALESCE(SUM(subtotal), 0)
    FROM db_techstore.order_items oi
    WHERE oi.order_id = o.order_id
);

-- ----------------------------------------------------------------------------
-- Function: fn_get_customer_total_spent
-- Description: Calculates the total lifetime value of a customer
--              based on their order history
-- Returns: DECIMAL - Total amount spent by the customer
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION db_techstore.fn_get_customer_total_spent(
    p_customer_id INTEGER
)
RETURNS DECIMAL(10, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_spent DECIMAL(10, 2);
BEGIN
    -- Calculate total from all delivered and shipped orders
    SELECT COALESCE(SUM(total_amount), 0)
    INTO v_total_spent
    FROM db_techstore.orders
    WHERE customer_id = p_customer_id
      AND status IN ('delivered', 'shipped', 'processing');
    
    RETURN v_total_spent;
END;
$$;

-- ----------------------------------------------------------------------------
-- Procedure: sp_process_new_order
-- Description: Processes a new order with atomic transaction
--              - Creates order record
--              - Adds order item
--              - Updates product stock
--              - Calculates and updates order total
-- Parameters:
--   p_customer_id: Customer placing the order
--   p_product_id: Product being ordered
--   p_quantity: Quantity of product
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE db_techstore.sp_process_new_order(
    p_customer_id INTEGER,
    p_product_id INTEGER,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_price DECIMAL(10, 2);
    v_product_stock INTEGER;
    v_order_id INTEGER;
    v_subtotal DECIMAL(10, 2);
    v_order_total DECIMAL(10, 2);
BEGIN
    -- Start transaction (implicit in procedures)
    
    -- Validate customer exists
    IF NOT EXISTS (SELECT 1 FROM db_techstore.customers WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'Customer with ID % does not exist', p_customer_id;
    END IF;
    
    -- Get product price and stock
    SELECT price, stock_quantity
    INTO v_product_price, v_product_stock
    FROM db_techstore.products
    WHERE product_id = p_product_id;
    
    -- Validate product exists
    IF v_product_price IS NULL THEN
        RAISE EXCEPTION 'Product with ID % does not exist', p_product_id;
    END IF;
    
    -- Validate stock availability
    IF v_product_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %', 
            v_product_stock, p_quantity;
    END IF;
    
    -- Validate quantity
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than 0';
    END IF;
    
    -- Calculate subtotal
    v_subtotal := v_product_price * p_quantity;
    
    -- Create order record
    INSERT INTO db_techstore.orders (customer_id, total_amount, status)
    VALUES (p_customer_id, 0, 'pending')
    RETURNING order_id INTO v_order_id;
    
    -- Create order item
    INSERT INTO db_techstore.order_items (order_id, product_id, quantity, unit_price, subtotal)
    VALUES (v_order_id, p_product_id, p_quantity, v_product_price, v_subtotal);
    
    -- Update product stock
    UPDATE db_techstore.products
    SET stock_quantity = stock_quantity - p_quantity,
        updated_at = CURRENT_TIMESTAMP
    WHERE product_id = p_product_id;
    
    -- Update order total
    SELECT COALESCE(SUM(subtotal), 0)
    INTO v_order_total
    FROM db_techstore.order_items
    WHERE order_id = v_order_id;
    
    UPDATE db_techstore.orders
    SET total_amount = v_order_total
    WHERE order_id = v_order_id;
    
    -- Transaction is managed by the caller
    -- If all operations succeed, the caller should commit
    -- If any error occurs, PostgreSQL will automatically rollback
    
    RAISE NOTICE 'Order % created successfully. Total: $%', v_order_id, v_order_total;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Re-raise the exception - the caller's transaction will be rolled back automatically
        RAISE;
END;
$$;

-- ----------------------------------------------------------------------------
-- Trigger Function: fn_audit_product_price_change
-- Description: Captures price changes in the price_audit table
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION db_techstore.fn_audit_product_price_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only audit if price actually changed
    IF OLD.price != NEW.price THEN
        INSERT INTO db_techstore.price_audit (
            product_id,
            old_price,
            new_price,
            changed_by
        )
        VALUES (
            NEW.product_id,
            OLD.price,
            NEW.price,
            CURRENT_USER
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- Trigger: trg_audit_product_price_change
-- Description: Automatically audits product price changes
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_audit_product_price_change
    AFTER UPDATE ON db_techstore.products
    FOR EACH ROW
    WHEN (OLD.price IS DISTINCT FROM NEW.price)
    EXECUTE FUNCTION db_techstore.fn_audit_product_price_change();

-- ----------------------------------------------------------------------------
-- Security: Create Login Users
-- Description: Create individual user accounts that will be assigned to roles
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    -- Create login user for developer
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'desenvolvedor_1') THEN
        CREATE ROLE desenvolvedor_1 WITH LOGIN PASSWORD 'change_me';
    END IF;
    
    -- Create login user for manager
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gerente_1') THEN
        CREATE ROLE gerente_1 WITH LOGIN PASSWORD 'change_me';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- Security: Create Group Roles
-- Description: Create role groups that will be assigned permissions
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    -- Create group member roles if they don't exist
    -- These roles will have full access to the database
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'techstore_developer') THEN
        CREATE ROLE techstore_developer;
    END IF;
    
    -- Create gerente role with restricted permissions
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gerente') THEN
        CREATE ROLE gerente;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- Security: Grant Permissions to Group Roles
-- Description: Assign privileges to the group roles
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    -- Grant schema usage and table privileges to developers
    GRANT USAGE ON SCHEMA db_techstore TO techstore_developer;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA db_techstore TO techstore_developer;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA db_techstore TO techstore_developer;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA db_techstore TO techstore_developer;
    GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA db_techstore TO techstore_developer;
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA db_techstore 
        GRANT ALL ON TABLES TO techstore_developer;
    ALTER DEFAULT PRIVILEGES IN SCHEMA db_techstore 
        GRANT ALL ON SEQUENCES TO techstore_developer;
    ALTER DEFAULT PRIVILEGES IN SCHEMA db_techstore 
        GRANT EXECUTE ON ROUTINES TO techstore_developer;
    
    -- Grant SELECT on all tables to gerente
    GRANT USAGE ON SCHEMA db_techstore TO gerente;
    GRANT SELECT ON ALL TABLES IN SCHEMA db_techstore TO gerente;
    
    -- Grant EXECUTE on functions and procedures to gerente
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA db_techstore TO gerente;
    GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA db_techstore TO gerente;
    
    -- Grant INSERT and UPDATE on main tables (for testing)
    GRANT INSERT, UPDATE ON 
        db_techstore.categories,
        db_techstore.products,
        db_techstore.customers,
        db_techstore.orders,
        db_techstore.order_items
    TO gerente;
    
    -- DENY destructive operations (ALTER, DROP, CREATE, DELETE)
    -- Note: PostgreSQL doesn't have explicit DENY, so we simply don't grant these
    -- The gerente role will not have these privileges by default
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA db_techstore 
        GRANT SELECT ON TABLES TO gerente;
    ALTER DEFAULT PRIVILEGES IN SCHEMA db_techstore 
        GRANT INSERT, UPDATE ON TABLES TO gerente;
    ALTER DEFAULT PRIVILEGES IN SCHEMA db_techstore 
        GRANT EXECUTE ON ROUTINES TO gerente;
END $$;

-- ----------------------------------------------------------------------------
-- Security: Assign Groups to Users
-- Description: Grant group roles to individual user accounts
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    -- Assign developer role to developer user
    GRANT techstore_developer TO desenvolvedor_1;
    
    -- Assign manager role to manager user
    GRANT gerente TO gerente_1;
END $$;