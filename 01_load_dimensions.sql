-- ============================================================
-- Northwind Spend Analysis | ETL — Load Dimensions
-- Author: Jenn Corbin | github.com/jenncorbin21-analytics
-- Description: Transforms and loads Northwind OLTP source
--              tables into the star schema dimensions.
--              Run order: dimensions first, fact table second.
-- ============================================================

-- --------------------------------------------------------
-- dim_supplier
-- Source: Suppliers
-- --------------------------------------------------------
INSERT INTO dim_supplier (
    supplier_id, company_name, contact_name, contact_title,
    country, region, city, phone, fax, home_page
)
SELECT
    SupplierID,
    CompanyName,
    ContactName,
    ContactTitle,
    Country,
    Region,
    City,
    Phone,
    Fax,
    HomePage
FROM Suppliers
ON DUPLICATE KEY UPDATE
    company_name   = VALUES(company_name),
    contact_name   = VALUES(contact_name),
    contact_title  = VALUES(contact_title),
    country        = VALUES(country),
    updated_at     = CURRENT_TIMESTAMP;

-- --------------------------------------------------------
-- dim_product
-- Source: Products JOIN Categories
-- Note: supplier_key resolved via dim_supplier lookup
-- --------------------------------------------------------
INSERT INTO dim_product (
    product_id, product_name, category_id, category_name,
    category_description, quantity_per_unit, unit_price,
    units_in_stock, units_on_order, reorder_level,
    discontinued, supplier_key
)
SELECT
    p.ProductID,
    p.ProductName,
    c.CategoryID,
    c.CategoryName,
    c.Description,
    p.QuantityPerUnit,
    p.UnitPrice,
    p.UnitsInStock,
    p.UnitsOnOrder,
    p.ReorderLevel,
    p.Discontinued,
    ds.supplier_key
FROM Products p
JOIN Categories c
    ON p.CategoryID = c.CategoryID
JOIN dim_supplier ds
    ON p.SupplierID = ds.supplier_id
ON DUPLICATE KEY UPDATE
    unit_price       = VALUES(unit_price),
    units_in_stock   = VALUES(units_in_stock),
    units_on_order   = VALUES(units_on_order),
    discontinued     = VALUES(discontinued),
    updated_at       = CURRENT_TIMESTAMP;

-- --------------------------------------------------------
-- dim_customer
-- Source: Customers
-- --------------------------------------------------------
INSERT INTO dim_customer (
    customer_id, company_name, contact_name, contact_title,
    country, region, city, postal_code, phone, fax
)
SELECT
    CustomerID,
    CompanyName,
    ContactName,
    ContactTitle,
    Country,
    Region,
    City,
    PostalCode,
    Phone,
    Fax
FROM Customers
ON DUPLICATE KEY UPDATE
    company_name  = VALUES(company_name),
    contact_name  = VALUES(contact_name),
    updated_at    = CURRENT_TIMESTAMP;

-- --------------------------------------------------------
-- dim_employee
-- Source: Employees
-- --------------------------------------------------------
INSERT INTO dim_employee (
    employee_id, full_name, title, title_of_courtesy,
    hire_date, city, country, reports_to_id
)
SELECT
    EmployeeID,
    CONCAT(FirstName, ' ', LastName),
    Title,
    TitleOfCourtesy,
    HireDate,
    City,
    Country,
    ReportsTo
FROM Employees
ON DUPLICATE KEY UPDATE
    full_name  = VALUES(full_name),
    title      = VALUES(title),
    updated_at = CURRENT_TIMESTAMP;

-- --------------------------------------------------------
-- dim_shipper
-- Source: Shippers
-- --------------------------------------------------------
INSERT INTO dim_shipper (
    shipper_id, company_name, phone
)
SELECT
    ShipperID,
    CompanyName,
    Phone
FROM Shippers
ON DUPLICATE KEY UPDATE
    company_name = VALUES(company_name),
    updated_at   = CURRENT_TIMESTAMP;

-- --------------------------------------------------------
-- dim_date
-- Source: Generated from Orders date range
-- Populates calendar rows for every date in the order data
-- --------------------------------------------------------
INSERT IGNORE INTO dim_date (
    date_key, full_date, year, quarter, month_num,
    month_name, week_of_year, day_of_week, day_name, is_weekend
)
WITH RECURSIVE date_series AS (
    SELECT MIN(OrderDate) AS dt FROM Orders
    UNION ALL
    SELECT DATE_ADD(dt, INTERVAL 1 DAY)
    FROM date_series
    WHERE dt < (SELECT MAX(ShippedDate) FROM Orders WHERE ShippedDate IS NOT NULL)
)
SELECT
    DATE_FORMAT(dt, '%Y%m%d')  AS date_key,
    dt                          AS full_date,
    YEAR(dt)                    AS year,
    QUARTER(dt)                 AS quarter,
    MONTH(dt)                   AS month_num,
    MONTHNAME(dt)               AS month_name,
    WEEK(dt, 3)                 AS week_of_year,
    DAYOFWEEK(dt)               AS day_of_week,
    DAYNAME(dt)                 AS day_name,
    CASE WHEN DAYOFWEEK(dt) IN (1,7) THEN 1 ELSE 0 END AS is_weekend
FROM date_series;
