-- CarvedRock Database Initialization Script
-- Creates tables and initial data for PostgreSQL performance and security lab

-- Drop existing tables if they exist
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- Create customers table
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'USA',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create products table
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    description TEXT,
    sku VARCHAR(50) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create orders table
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',
    total_amount DECIMAL(10,2),
    shipping_address TEXT,
    billing_address TEXT,
    payment_method VARCHAR(50),
    shipping_method VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create order_items table
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount DECIMAL(5,2) DEFAULT 0,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Insert sample customers (100,000 records)
INSERT INTO customers (customer_name, email, phone, address, city, state, zip_code)
SELECT 
    'Customer ' || generate_series,
    'customer' || generate_series || '@carvedrock.com',
    '555-' || LPAD(generate_series::text, 4, '0'),
    generate_series || ' Main Street',
    CASE WHEN random() < 0.3 THEN 'Denver'
         WHEN random() < 0.6 THEN 'Portland'
         WHEN random() < 0.8 THEN 'Seattle'
         ELSE 'Austin'
    END,
    CASE WHEN random() < 0.3 THEN 'CO'
         WHEN random() < 0.6 THEN 'OR'
         WHEN random() < 0.8 THEN 'WA'
         ELSE 'TX'
    END,
    LPAD((random() * 99999)::integer::text, 5, '0')
FROM generate_series(1, 100000);

-- Insert sample products (1,000 records)
INSERT INTO products (product_name, category, price, stock_quantity, sku)
SELECT 
    'Product ' || generate_series,
    CASE WHEN random() < 0.25 THEN 'Climbing'
         WHEN random() < 0.5 THEN 'Hiking'
         WHEN random() < 0.75 THEN 'Camping'
         ELSE 'Accessories'
    END,
    (random() * 500 + 10)::decimal(10,2),
    (random() * 1000)::integer,
    'SKU-' || LPAD(generate_series::text, 6, '0')
FROM generate_series(1, 1000);

-- Insert sample orders (500,000 records)
INSERT INTO orders (customer_id, order_date, status, total_amount, payment_method, shipping_method)
SELECT 
    (random() * 99999 + 1)::integer,
    CURRENT_DATE - (random() * 365)::integer * INTERVAL '1 day',
    CASE WHEN random() < 0.7 THEN 'completed'
         WHEN random() < 0.9 THEN 'shipped'
         WHEN random() < 0.95 THEN 'pending'
         ELSE 'cancelled'
    END,
    (random() * 1000 + 10)::decimal(10,2),
    CASE WHEN random() < 0.5 THEN 'credit_card'
         WHEN random() < 0.8 THEN 'paypal'
         ELSE 'bank_transfer'
    END,
    CASE WHEN random() < 0.6 THEN 'standard'
         WHEN random() < 0.9 THEN 'express'
         ELSE 'overnight'
    END
FROM generate_series(1, 500000);

-- Insert sample order items (1,500,000 records)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT 
    (random() * 499999 + 1)::integer,
    (random() * 999 + 1)::integer,
    (random() * 5 + 1)::integer,
    (random() * 500 + 10)::decimal(10,2)
FROM generate_series(1, 1500000);

-- Update order totals based on order items
UPDATE orders o
SET total_amount = (
    SELECT SUM(quantity * unit_price * (1 - discount/100))
    FROM order_items oi
    WHERE oi.order_id = o.order_id
)
WHERE EXISTS (
    SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id
);

-- Add some duplicate rows to create bloat (these will be deleted)
INSERT INTO orders (customer_id, order_date, status, total_amount)
SELECT customer_id, order_date, 'deleted', total_amount
FROM orders
WHERE order_id <= 250000;

-- Create some gaps in the data to simulate fragmentation
DELETE FROM orders WHERE status = 'deleted';

-- Add more duplicate rows for customers
INSERT INTO customers (customer_name, email, phone, address, city, state, zip_code)
SELECT 
    customer_name || '_dup',
    'dup_' || email,
    phone,
    address,
    city,
    state,
    zip_code
FROM customers
WHERE customer_id <= 75000;

-- Delete duplicates to create bloat
DELETE FROM customers WHERE customer_name LIKE '%_dup';

-- Force some statistics updates
ANALYZE customers;
ANALYZE products;
ANALYZE orders;
ANALYZE order_items;
