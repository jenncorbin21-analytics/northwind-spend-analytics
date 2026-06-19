-- ============================================================
-- Northwind Spend Analysis | ETL — Load Dimensions
-- Author: Jenn Corbin | github.com/jenncorbin21-analytics
-- Description: Transforms and loads Northwind OLTP source
--              tables into the star schema dimensions.
--              Run order: dimensions first, fact table second.
-- ============================================================

-- --------------------------------------------------------
-- dim_supplier
-- Source: northwind.suppliers
-- --------------------------------------------------------
INSERT INTO dim_supplier (
    supplier_id, company_name, contact_name, contact_title,
    country, region, city, phone, fax, home_page
)
SELECT
    id,
    company,
    CONCAT(first_name, ' ', last_name),
    job_title,
    country_region,
    state_province,
    city,
    business_phone,
    fax_number,
    web_page
FROM northwind.suppliers
ON DUPLICATE KEY UPDATE
    company_name   = VALUES(company_name),
    contact_name   = VALUES(contact_name),
    contact_title  = VALUES(contact_title),
    country        = VALUES(country),
    updated_at     = CURRENT_TIMESTAMP;

-- --------------------------------------------------------
-- dim_product
-- Source: northwind.products
-- Notes: - No categories table in mywind; category stored
--          as text field on products table
--        - supplier_ids is semicolon-delimited in mywind;
--          REPLACE converts to comma for FIND_IN_SET
--        - SUBSTRING_INDEX takes first supplier only to
--          prevent duplicate product rows
-- --------------------------------------------------------
INSERT INTO dim_product (
    product_id, product_name, category_id, category_name,
    category_description, quantity_per_unit, unit_price,
    units_in_stock, units_on_order, reorder_level,
    discontinued, supplier_key
)
SELECT
    p.id,
    p.product_name,
    NULL,
    p.category,
    NULL,
    p.quantity_per_unit,
    p.list_price,
    NULL,
    NULL,
    p.reorder_level,
    p.discontinued,
    ds.supplier_key
FROM northwind.products p
JOIN northwind.suppliers s
    ON FIND_IN_SET(s.id, SUBSTRING_INDEX(REPLACE(p.supplier_ids, ';', ','), ',', 1))
JOIN dim_supplier ds
    ON s.id = ds.supplier_id
ON DUPLICATE KEY UPDATE
    unit_price   = VALUES(unit_price),
    discontinued = VALUES(discontinued),
    updated_at   = CURRENT_TIMESTAMP;

-- --------------------------------------------------------
-- dim_customer
-- Source: northwind.customers
-- --------------------------------------------------------
INSERT INTO dim_customer (
    customer_id, company_name, contact_name, contact_title,
    country, region, city, postal_code, phone, fax
)
SELECT
    id,
    company,
    CONCAT(first_name, ' ', last_name),
    job_title,
    country_region,
    state_province,
    city,
    zip_postal_code,
    business_phone,
    fax_number
FROM northwind.customers
ON DUPLICATE KEY UPDATE
    company_name  = VALUES(company_name),
    contact_name  = VALUES(contact_name),
    updated_at    = CURRENT_TIMESTAMP;

-- --------------------------------------------------------
-- dim_employee
-- Source: northwind.employees
-- Notes: title_of_courtesy, hire_date, and reports_to
--        are not available in mywind; set to NULL
-- --------------------------------------------------------
INSERT INTO dim_employee (
    employee_id, full_name, title, title_of_courtesy,
    hire_date, city, country, reports_to_id
)
SELECT
    id,
    CONCAT(first_name, ' ', last_name),
    job_title,
    NULL,
    NULL,
    city,
    country_region,
    NULL
FROM northwind.employees
ON DUPLICATE KEY UPDATE
    full_name  = VALUES(full_name),
    title      = VALUES(title),
    updated_at = CURRENT_TIMESTAMP;

-- --------------------------------------------------------
-- dim_shipper
-- Source: northwind.shippers
-- --------------------------------------------------------
INSERT INTO dim_shipper (
    shipper_id, company_name, phone
)
SELECT
    id,
    company,
    business_phone
FROM northwind.shippers
ON DUPLICATE KEY UPDATE
    company_name = VALUES(company_name),
    updated_at   = CURRENT_TIMESTAMP;

-- --------------------------------------------------------
-- dim_date
-- Source: Generated from northwind.orders date range
-- Populates one calendar row per day across order history
-- Note: DELETE any rows with date_key = 0 before re-running
--       if orders table was empty on first execution
-- --------------------------------------------------------
INSERT IGNORE INTO dim_date (
    date_key, full_date, year, quarter, month_num,
    month_name, week_of_year, day_of_week, day_name, is_weekend
)
WITH RECURSIVE date_series AS (
    SELECT MIN(order_date) AS dt FROM northwind.orders
    UNION ALL
    SELECT DATE_ADD(dt, INTERVAL 1 DAY)
    FROM date_series
    WHERE dt < (SELECT MAX(shipped_date) FROM northwind.orders WHERE shipped_date IS NOT NULL)
)
SELECT
    DATE_FORMAT(dt, '%Y%m%d')                              AS date_key,
    dt                                                      AS full_date,
    YEAR(dt)                                                AS year,
    QUARTER(dt)                                             AS quarter,
    MONTH(dt)                                               AS month_num,
    MONTHNAME(dt)                                           AS month_name,
    WEEK(dt, 3)                                             AS week_of_year,
    DAYOFWEEK(dt)                                           AS day_of_week,
    DAYNAME(dt)                                             AS day_name,
    CASE WHEN DAYOFWEEK(dt) IN (1,7) THEN 1 ELSE 0 END     AS is_weekend
FROM date_series;
