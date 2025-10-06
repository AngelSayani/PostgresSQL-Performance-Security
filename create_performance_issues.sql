-- Create Performance Issues for Lab Exercise
-- This script intentionally creates performance problems for learning purposes

-- Drop all existing indexes except primary keys
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT indexname, tablename 
        FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND indexname NOT LIKE '%_pkey'
    LOOP
        EXECUTE 'DROP INDEX IF EXISTS ' || r.indexname;
    END LOOP;
END $$;

-- Remove foreign key constraints to eliminate their implicit indexes
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_order_id_fkey;
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_product_id_fkey;

-- Create some inefficient views
CREATE OR REPLACE VIEW slow_customer_summary AS
SELECT 
    c.*,
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) as order_count,
    (SELECT SUM(total_amount) FROM orders o WHERE o.customer_id = c.customer_id) as total_spent,
    (SELECT MAX(order_date) FROM orders o WHERE o.customer_id = c.customer_id) as last_order
FROM customers c;

-- Create a problematic function
CREATE OR REPLACE FUNCTION get_customer_stats(cust_id INTEGER)
RETURNS TABLE(
    total_orders BIGINT,
    total_spent NUMERIC,
    avg_order_value NUMERIC,
    favorite_category TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT o.order_id),
        SUM(o.total_amount),
        AVG(o.total_amount),
        (
            SELECT p.category
            FROM order_items oi
            JOIN products p ON oi.product_id = p.product_id
            JOIN orders o2 ON oi.order_id = o2.order_id
            WHERE o2.customer_id = cust_id
            GROUP BY p.category
            ORDER BY COUNT(*) DESC
            LIMIT 1
        )
    FROM orders o
    WHERE o.customer_id = cust_id;
END;
$$ LANGUAGE plpgsql;

-- Add some large text data to make tables bigger
UPDATE customers 
SET notes = repeat('Customer data padding to increase table size and create performance issues. ', 10)
WHERE customer_id <= 50000;

UPDATE orders 
SET notes = repeat('Order data padding to increase table size and create performance issues. ', 10)
WHERE order_id <= 250000;

-- Create a wide table with many columns
CREATE TABLE IF NOT EXISTS audit_log (
    audit_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100),
    operation VARCHAR(50),
    user_name VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    old_data JSONB,
    new_data JSONB,
    extra_col1 TEXT,
    extra_col2 TEXT,
    extra_col3 TEXT,
    extra_col4 TEXT,
    extra_col5 TEXT,
    extra_col6 TEXT,
    extra_col7 TEXT,
    extra_col8 TEXT,
    extra_col9 TEXT,
    extra_col10 TEXT
);

-- Insert audit log data
INSERT INTO audit_log (table_name, operation, user_name, old_data, new_data)
SELECT 
    CASE WHEN random() < 0.5 THEN 'orders' ELSE 'customers' END,
    CASE WHEN random() < 0.3 THEN 'INSERT'
         WHEN random() < 0.6 THEN 'UPDATE'
         WHEN random() < 0.9 THEN 'SELECT'
         ELSE 'DELETE'
    END,
    'app_user',
    '{"id": ' || generate_series || '}',
    '{"id": ' || generate_series || ', "modified": true}'
FROM generate_series(1, 100000);

-- Disable autovacuum temporarily to allow bloat to accumulate
ALTER TABLE orders SET (autovacuum_enabled = false);
ALTER TABLE customers SET (autovacuum_enabled = false);

-- Create some long-running transactions to prevent vacuum
-- (These will be cleaned up when the connection closes)
BEGIN;
SELECT * FROM orders WHERE order_id = 1 FOR UPDATE;
-- Transaction left open intentionally

-- Reset statistics to hide optimization opportunities
SELECT pg_stat_reset();

-- Create circular dependencies through views
CREATE OR REPLACE VIEW order_summary AS
SELECT 
    o.order_id,
    o.customer_id,
    c.customer_name,
    o.total_amount,
    COUNT(oi.order_item_id) as item_count
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.customer_id, c.customer_name, o.total_amount;

-- Set low work_mem to cause disk-based sorting
ALTER SYSTEM SET work_mem = '1MB';

-- Set low shared_buffers to reduce caching
ALTER SYSTEM SET shared_buffers = '32MB';

-- Disable parallel queries to make things slower
ALTER SYSTEM SET max_parallel_workers_per_gather = 0;

-- Create a materialized view that needs refresh
CREATE MATERIALIZED VIEW IF NOT EXISTS sales_summary AS
SELECT 
    DATE_TRUNC('month', order_date) as month,
    COUNT(*) as order_count,
    SUM(total_amount) as total_sales,
    AVG(total_amount) as avg_order_value
FROM orders
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', order_date);

-- Don't refresh it, leaving it stale
-- REFRESH MATERIALIZED VIEW sales_summary;

COMMIT;
