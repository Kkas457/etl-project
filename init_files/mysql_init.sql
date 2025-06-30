-- mysql-table-creation.sql
-- This script will be executed by the MySQL container on startup.

-- Drop tables if they exist to allow fresh starts
DROP TABLE IF EXISTS stg_sales;
DROP TABLE IF EXISTS stg_daily_product_sales_summary;
DROP TABLE IF EXISTS stg_customers;
DROP TABLE IF EXISTS stg_products;

-- 1. Create 'customers' table
CREATE TABLE stg_customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    country VARCHAR(50) NOT NULL
);

-- 2. Create 'products' table
CREATE TABLE stg_products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    group_name VARCHAR(100) NOT NULL
);

-- 3. Create 'daily_product_sales_summary' table for aggregated reports
CREATE TABLE stg_daily_product_sales_summary (
    summary_date DATE NOT NULL,
    product_id INT NOT NULL,
    total_quantity_sold INT NOT NULL,
    PRIMARY KEY (summary_date, product_id),
    FOREIGN KEY (product_id) REFERENCES stg_products(id)
);

-- 4. Create 'sales' table
CREATE TABLE stg_sales (
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    qty INT NOT NULL,
    transaction_date DATETIME DEFAULT NOW(),
    PRIMARY KEY (customer_id, product_id, transaction_date),
    FOREIGN KEY (customer_id) REFERENCES stg_customers(id),
    FOREIGN KEY (product_id) REFERENCES stg_products(id)
);
