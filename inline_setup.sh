#!/bin/bash

# Single inline setup script that combines all operations
# This script runs as postgres user and sets up everything in one go

echo "Starting CarvedRock database setup..."

# Create the database
createdb carvedrock 2>/dev/null || echo "Database may already exist"

# Run all setup in a single psql session
psql -d carvedrock << 'EOSQL'

-- Enable extension
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create all tables
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category_id INTEGER REFERENCES categories(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS stock (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    warehouse_location VARCHAR(50),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    customer_email VARCHAR(200),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL
);

-- Create user
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'app_user') THEN
        CREATE USER app_user WITH PASSWORD 'changeme123';
    END IF;
END$$;

-- Grant privileges
GRANT CONNECT ON DATABASE carvedrock TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Load categories
INSERT INTO categories (name, description) 
SELECT * FROM (VALUES
    ('Electronics', 'Electronic devices and accessories'),
    ('Clothing', 'Apparel and fashion items'),
    ('Books', 'Physical and digital books'),
    ('Sports', 'Sports equipment and accessories'),
    ('Home & Garden', 'Home improvement and garden supplies'),
    ('Toys', 'Toys and games for all ages'),
    ('Automotive', 'Car parts and accessories'),
    ('Health', 'Health and wellness products'),
    ('Outdoor', 'Outdoor and climbing gear'),
    ('Footwear', 'Shoes and boots for all activities')
) AS v(name, description)
WHERE NOT EXISTS (SELECT 1 FROM categories);

-- Generate products only if table is empty
DO $$
DECLARE
    i INTEGER;
    cat_id INTEGER;
    price_val DECIMAL(10,2);
BEGIN
    IF (SELECT COUNT(*) FROM products) = 0 THEN
        RAISE NOTICE 'Generating products...';
        FOR i IN 1..250000 LOOP
            cat_id := (i % 10) + 1;
            price_val := (RANDOM() * 500 + 10)::DECIMAL(10,2);
            
            INSERT INTO products (name, description, price, category_id, created_at)
            VALUES (
                'Product ' || i,
                'Detailed description for product ' || i || ' in category ' || cat_id,
                price_val,
                cat_id,
                CURRENT_TIMESTAMP - (RANDOM() * INTERVAL '730 days')
            );
            
            IF i % 25000 = 0 THEN
                RAISE NOTICE 'Loaded % products', i;
            END IF;
        END LOOP;
    END IF;
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
FROM products
WHERE NOT EXISTS (SELECT 1 FROM stock WHERE stock.product_id = products.id);

-- Generate orders
DO $$
DECLARE
    i INTEGER;
    ord_id INTEGER;
BEGIN
    IF (SELECT COUNT(*) FROM orders) = 0 THEN
        RAISE NOTICE 'Generating orders...';
        FOR i IN 1..200000 LOOP
            INSERT INTO orders (customer_email, product_id, quantity, order_date, status)
            VALUES (
                'customer' || (FLOOR(RANDOM() * 50000)::TEXT) || '@example.com',
                FLOOR(RANDOM() * 250000 + 1)::INTEGER,
                FLOOR(RANDOM() * 10 + 1)::INTEGER,
                CURRENT_TIMESTAMP - (RANDOM() * INTERVAL '365 days'),
                CASE 
                    WHEN RANDOM() < 0.7 THEN 'completed'
                    WHEN RANDOM() < 0.9 THEN 'processing'
                    ELSE 'pending'
                END
            );
            
            IF i % 20000 = 0 THEN
                RAISE NOTICE 'Created % orders', i;
            END IF;
        END LOOP;
    END IF;
END $$;

-- Create bloat
UPDATE products SET updated_at = CURRENT_TIMESTAMP WHERE id % 3 = 0;
UPDATE products SET price = price * 1.05 WHERE id % 5 = 0;
UPDATE orders SET status = 'completed' WHERE status = 'processing' AND id % 2 = 0;

-- Generate slow queries for pg_stat_statements
SELECT pg_stat_statements_reset();

-- Run some deliberately slow queries
SELECT p.*, c.name as category_name, s.quantity 
FROM products p 
JOIN categories c ON p.category_id = c.id 
JOIN stock s ON p.id = s.product_id 
WHERE p.price > 50 AND s.quantity < 100 
ORDER BY p.created_at DESC
LIMIT 100;

SELECT COUNT(*) FROM products WHERE price > 100;
SELECT COUNT(*) FROM orders WHERE status = 'completed';

-- Analyze tables
ANALYZE;

-- Show final status
SELECT 'Database size: ' || pg_size_pretty(pg_database_size('carvedrock'));
SELECT 'Products count: ' || COUNT(*) FROM products;
SELECT 'Orders count: ' || COUNT(*) FROM orders;

EOSQL

echo "CarvedRock database setup complete!"
