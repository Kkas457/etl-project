-- ClickHouse Table Creation Script

-- Drop tables if they exist
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS daily_product_sales_summary;
DROP TABLE IF EXISTS etl_logs;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;

-- 1. Create 'customers' table
-- Using ReplacingMergeTree to handle potential duplicates on 'id' if inserting multiple times
-- ClickHouse does not have AUTO_INCREMENT; IDs should be managed by the application or a sequence.
CREATE TABLE customers (
    id UInt32,
    name String,
    country String
) ENGINE = ReplacingMergeTree(id)
ORDER BY id;

-- 2. Create 'products' table
CREATE TABLE products (
    id UInt32,
    name String,
    group_name String
) ENGINE = ReplacingMergeTree(id)
ORDER BY id;

-- 3. Create 'daily_product_sales_summary' table for aggregated reports
-- Using SummingMergeTree for aggregations of total_quantity_sold
CREATE TABLE daily_product_sales_summary (
    summary_date Date,
    product_id UInt32,
    total_quantity_sold UInt32
) ENGINE = SummingMergeTree(total_quantity_sold)
ORDER BY (summary_date, product_id);

-- 4. Create 'sales' table (fact table)
-- Using MergeTree with transaction_date for partitioning and sorting.
-- ClickHouse does not enforce FOREIGN KEY constraints at the database level;
-- relationships are handled at the application or query level.
-- PRIMARY KEY in ClickHouse (ORDER BY clause) is for sorting data on disk, not uniqueness.
CREATE TABLE sales (
    customer_id UInt32,
    product_id UInt32,
    qty UInt32,
    transaction_date DateTime
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(transaction_date) -- Example partitioning by month for better performance on time-series data
ORDER BY (customer_id, product_id, transaction_date); -- Primary sorting key
