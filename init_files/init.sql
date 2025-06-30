-- Удалить таблицы, если они существуют, для обеспечения чистого старта
DROP TABLE IF EXISTS etl_logs;
DROP TABLE IF EXISTS daily_product_sales_summary;
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;

-- 1. Создать таблицу 'customers' (клиенты)
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    country VARCHAR(50) NOT NULL
);

-- 2. Создать таблицу 'products' (продукты)
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    group_name VARCHAR(100) NOT NULL
);

-- 3. Создать таблицу 'sales' (продажи)
CREATE TABLE sales (
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    qty INT NOT NULL,
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- дата транзакции для поддержки дельта-загрузки
    PRIMARY KEY (customer_id, product_id, transaction_date), -- Композитный первичный ключ
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- 4. Создать таблицу 'etl_logs' для записи логов
CREATE TABLE etl_logs (
    log_id SERIAL PRIMARY KEY,
    procedure_name VARCHAR(100) NOT NULL,
    log_type VARCHAR(20) NOT NULL, -- например, 'INFO', 'WARNING', 'ERROR'
    message TEXT NOT NULL,
    log_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Создать таблицу 'daily_product_sales_summary' для агрегированных отчетов
CREATE TABLE daily_product_sales_summary (
    summary_date DATE NOT NULL,
    product_id INT NOT NULL,
    total_quantity_sold INT NOT NULL,
    PRIMARY KEY (summary_date, product_id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);


-- Заполнение таблицы 'customers' случайными данными
INSERT INTO customers (name, country)
SELECT
    'Customer ' || LPAD(s::text, 3, '0'),
    CASE (s % 5)
        WHEN 0 THEN 'USA'
        WHEN 1 THEN 'Canada'
        WHEN 2 THEN 'Germany'
        WHEN 3 THEN 'France'
        ELSE 'Australia'
    END
FROM GENERATE_SERIES(1, 100) s; -- Генерировать 100 случайных клиентов

-- Заполнение таблицы 'products' случайными данными
INSERT INTO products (name, group_name)
SELECT
    'Product ' || LPAD(s::text, 3, '0'),
    CASE (s % 4)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Books'
        WHEN 2 THEN 'Home Goods'
        ELSE 'Apparel'
    END
FROM GENERATE_SERIES(1, 200) s; -- Генерировать 200 случайных продуктов

-- Заполнение таблицы 'sales' случайными данными
INSERT INTO sales (customer_id, product_id, qty, transaction_date)
SELECT
    c.id, -- Случайный customer_id из таблицы customers
    p.id, -- Случайный product_id из таблицы products
    (RANDOM() * 10 + 1)::INT, -- Случайное количество от 1 до 10
    CURRENT_TIMESTAMP - (random() * 365 || ' days')::interval -- Случайная дата транзакции за последний год
FROM
    (SELECT id FROM customers ORDER BY RANDOM() LIMIT 500) c, -- Выбрать 500 случайных клиентов
    (SELECT id FROM products ORDER BY RANDOM() LIMIT 500) p
WHERE RANDOM() < 0.5 -- Сделать некоторые комбинации клиентов/продуктов более вероятными для пересечения
LIMIT 1000; -- Генерировать 1000 случайных записей о продажах


-- 6. Определение хранимой процедуры 'generate_and_log_sales_summary'
CREATE OR REPLACE PROCEDURE generate_and_log_sales_summary()
LANGUAGE plpgsql
AS $$
DECLARE
    report_row RECORD;
    -- Курсор для демонстрации итерации по агрегированным данным (например, по топ-5 продуктам)
    report_cursor CURSOR FOR
        SELECT summary_date, product_id, total_quantity_sold
        FROM daily_product_sales_summary
        ORDER BY total_quantity_sold DESC
        LIMIT 5;
BEGIN
    -- Запись в лог: начало процедуры
    INSERT INTO etl_logs (procedure_name, log_type, message)
    VALUES ('generate_and_log_sales_summary', 'INFO', 'Процедура агрегации продаж запущена.');

    -- Очистка существующих сводных данных (или реализовать инкрементальную логику)
    TRUNCATE TABLE daily_product_sales_summary;

    -- Агрегация данных из таблицы sales в daily_product_sales_summary
    INSERT INTO daily_product_sales_summary (summary_date, product_id, total_quantity_sold)
    SELECT
        transaction_date::date AS summary_date,
        product_id,
        SUM(qty) AS total_quantity_sold
    FROM sales
    GROUP BY transaction_date::date, product_id;

    -- Запись в лог: успешная агрегация
    INSERT INTO etl_logs (procedure_name, log_type, message)
    VALUES ('generate_and_log_sales_summary', 'INFO', 'Данные успешно агрегированы в daily_product_sales_summary.');

    -- Демонстрация использования курсора: Итерация по топ-5 агрегированным продуктам и логирование их
    OPEN report_cursor;
    LOOP
        FETCH report_cursor INTO report_row;
        EXIT WHEN NOT FOUND;
        INSERT INTO etl_logs (procedure_name, log_type, message)
        VALUES ('generate_and_log_sales_summary', 'INFO',
                'Отчет: Дата=' || report_row.summary_date || ', Продукт ID=' || report_row.product_id ||
                ', Общее количество=' || report_row.total_quantity_sold);
    END LOOP;
    CLOSE report_cursor;

    -- Запись в лог: успешное завершение процедуры
    INSERT INTO etl_logs (procedure_name, log_type, message)
    VALUES ('generate_and_log_sales_summary', 'INFO', 'Процедура агрегации продаж завершена успешно.');

EXCEPTION
    WHEN OTHERS THEN
        -- Запись в лог: ошибка
        INSERT INTO etl_logs (procedure_name, log_type, message)
        VALUES ('generate_and_log_sales_summary', 'ERROR', 'Ошибка: ' || SQLERRM || ' (SQLSTATE: ' || SQLSTATE || ')');
        RAISE NOTICE 'Процедура завершена с ошибкой. См. таблицу etl_logs.';
END;
$$;


-- 7. Определение функции 'get_average_sales_quantity'
CREATE OR REPLACE FUNCTION get_average_sales_quantity(p_product_id INT DEFAULT NULL)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    avg_qty NUMERIC;
BEGIN
    IF p_product_id IS NOT NULL THEN
        SELECT AVG(qty) INTO avg_qty
        FROM sales
        WHERE product_id = p_product_id;
    ELSE
        SELECT AVG(qty) INTO avg_qty
        FROM sales;
    END IF;

    IF avg_qty IS NULL THEN
        RETURN 0; -- Возвращаем 0, если не найдено продаж для данного продукта или в целом
    END IF;

    RETURN avg_qty;
EXCEPTION
    WHEN OTHERS THEN
        -- Запись в лог (необязательно, функции обычно просто возвращают или выдают ошибку)
        INSERT INTO etl_logs (procedure_name, log_type, message)
        VALUES ('get_average_sales_quantity', 'ERROR', 'Ошибка при расчете средней продажи: ' || SQLERRM);
        RAISE EXCEPTION 'Ошибка при расчете средней продажи.';
END;
$$;
