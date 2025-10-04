#!/bin/bash

# Load sample data with intentional performance issues

sudo -u postgres psql -d carvedrock << 'EOF'
-- Insert categories
INSERT INTO categories (name, description) VALUES
('Electronics', 'Electronic devices and accessories'),
('Clothing', 'Apparel and fashion items'),
('Books', 'Physical and digital books'),
('Sports', 'Sports equipment and accessories'),
('Home & Garden', 'Home improvement and garden supplies'),
('Toys', 'Toys and games for all ages'),
('Automotive', 'Car parts and accessories'),
('Health', 'Health and wellness products');

-- Generate products with varying prices (some over $50 for query testing)
DO $$
DECLARE
    i INTEGER;
    cat_id INTEGER;
BEGIN
    FOR i IN 1..50000 LOOP
        cat_id := (i % 8) + 1;
        INSERT INTO products (name, description, price, category_id)
        VALUES (
            'Product ' || i,
            'Description for product ' || i || ' in category ' || cat_id,
            (RANDOM() * 200)::DECIMAL(10,2),
            cat_id
        );
    END LOOP;
END $$;

-- Generate stock entries
INSERT INTO stock (product_id, quantity, warehouse_location)
SELECT 
    id,
    FLOOR(RANDOM() * 200)::INTEGER,
    CASE 
        WHEN RANDOM() < 0.33 THEN 'Warehouse A'
        WHEN RANDOM() < 0.66 THEN 'Warehouse B'
        ELSE 'Warehouse C'
    END
FROM products;

-- Generate orders with some dead tuples for bloat demonstration
DO $$
DECLARE
    i INTEGER;
    prod_id INTEGER;
BEGIN
    FOR i IN 1..100000 LOOP
        prod_id := FLOOR(RANDOM() * 50000 + 1)::INTEGER;
        INSERT INTO orders (customer_email, product_id, quantity, order_date, status)
        VALUES (
            'customer' || (FLOOR(RANDOM() * 10000)::TEXT) || '@example.com',
            prod_id,
            FLOOR(RANDOM() * 10 + 1)::INTEGER,
            CURRENT_TIMESTAMP - (RANDOM() * INTERVAL '365 days'),
            CASE 
                WHEN RANDOM() < 0.7 THEN 'completed'
                WHEN RANDOM() < 0.9 THEN 'processing'
                ELSE 'pending'
            END
        );
    END LOOP;
END $$;

-- Create bloat by updating records multiple times
UPDATE products SET updated_at = CURRENT_TIMESTAMP WHERE id % 3 = 0;
UPDATE products SET price = price * 1.1 WHERE id % 5 = 0;
UPDATE products SET description = description || ' - Updated' WHERE id % 7 = 0;

UPDATE orders SET status = 'completed' WHERE status = 'processing' AND id % 2 = 0;
UPDATE orders SET quantity = quantity + 1 WHERE id % 4 = 0;

-- Update statistics
ANALYZE;
EOF

echo "Sample data loaded with intentional performance issues"
