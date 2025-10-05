#!/bin/bash

# Generate slow queries to populate pg_stat_statements
echo "Generating slow queries for demonstration..."

psql -d carvedrock << 'EOF'
-- Reset statistics to start fresh
SELECT pg_stat_statements_reset();

-- Generate some deliberately slow queries

-- Query 1: Complex join without indexes (this will be slow)
SELECT p.*, c.name as category_name, s.quantity 
FROM products p 
JOIN categories c ON p.category_id = c.id 
JOIN stock s ON p.id = s.product_id 
WHERE p.price > 50 AND s.quantity < 100 
ORDER BY p.created_at DESC
LIMIT 100;

-- Query 2: Another slow query with multiple joins
SELECT 
    o.customer_email,
    COUNT(DISTINCT oi.product_id) as unique_products,
    SUM(oi.quantity * oi.unit_price) as total_value,
    AVG(p.price) as avg_product_price
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
JOIN categories c ON p.category_id = c.id
WHERE o.order_date > CURRENT_DATE - INTERVAL '90 days'
    AND p.price > 100
GROUP BY o.customer_email
HAVING COUNT(DISTINCT oi.product_id) > 3
ORDER BY total_value DESC
LIMIT 50;

-- Query 3: Subquery without proper indexes
SELECT p.name, p.price,
    (SELECT COUNT(*) FROM orders WHERE product_id = p.id) as order_count,
    (SELECT AVG(quantity) FROM stock WHERE product_id = p.id) as avg_stock
FROM products p
WHERE p.price > (SELECT AVG(price) FROM products)
    AND EXISTS (SELECT 1 FROM order_items oi WHERE oi.product_id = p.id)
ORDER BY p.price DESC
LIMIT 100;

-- Query 4: Large aggregation query
SELECT 
    DATE_TRUNC('month', o.order_date) as month,
    c.name as category,
    COUNT(DISTINCT o.id) as order_count,
    SUM(o.quantity) as total_quantity,
    AVG(p.price) as avg_price,
    MAX(p.price) as max_price,
    MIN(p.price) as min_price
FROM orders o
JOIN products p ON o.product_id = p.id
JOIN categories c ON p.category_id = c.id
WHERE o.status = 'completed'
GROUP BY DATE_TRUNC('month', o.order_date), c.name
ORDER BY month DESC, order_count DESC;

-- Query 5: Cross join (intentionally bad)
SELECT COUNT(*)
FROM products p1
CROSS JOIN products p2
WHERE p1.price > p2.price
    AND p1.category_id != p2.category_id
LIMIT 1;

-- Run each slow query multiple times to generate statistics
DO $$
DECLARE
    i INTEGER;
BEGIN
    FOR i IN 1..5 LOOP
        -- Repeat the slowest query
        PERFORM p.*, c.name as category_name, s.quantity 
        FROM products p 
        JOIN categories c ON p.category_id = c.id 
        JOIN stock s ON p.id = s.product_id 
        WHERE p.price > 50 AND s.quantity < 100 
        ORDER BY p.created_at DESC
        LIMIT 100;
        
        -- Another slow operation
        PERFORM COUNT(*) 
        FROM products p1, products p2 
        WHERE p1.price > 100 
            AND p2.price < 50 
            AND p1.category_id = p2.category_id
        LIMIT 1;
    END LOOP;
END $$;

-- Show current slow queries
SELECT 
    SUBSTRING(query, 1, 60) as query_preview,
    calls,
    ROUND(mean_exec_time::numeric, 2) as mean_ms,
    ROUND(total_exec_time::numeric, 2) as total_ms
FROM pg_stat_statements 
WHERE mean_exec_time > 10
ORDER BY mean_exec_time DESC 
LIMIT 10;
EOF

echo "Slow queries generated and captured in pg_stat_statements"
