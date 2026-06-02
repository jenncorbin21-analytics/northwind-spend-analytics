-- ============================================================
-- Northwind Spend Analysis | ETL — Load Fact Table
-- Author: Jenn Corbin | github.com/jenncorbin21-analytics
-- Description: Loads the fact_order_lines table by joining
--              Northwind OLTP source tables and resolving
--              surrogate keys from loaded dimensions.
--              Run AFTER 01_load_dimensions.sql
-- ============================================================

INSERT INTO fact_order_lines (
    order_id,
    product_key,
    customer_key,
    employee_key,
    supplier_key,
    shipper_key,
    order_date_key,
    required_date_key,
    shipped_date_key,
    order_id_dd,
    unit_price,
    quantity,
    discount,
    freight
)
SELECT
    o.OrderID,
    dp.product_key,
    dc.customer_key,
    de.employee_key,
    ds.supplier_key,
    dsh.shipper_key,
    -- Date keys: cast to YYYYMMDD integer
    CAST(DATE_FORMAT(o.OrderDate,    '%Y%m%d') AS UNSIGNED) AS order_date_key,
    CAST(DATE_FORMAT(o.RequiredDate, '%Y%m%d') AS UNSIGNED) AS required_date_key,
    CAST(DATE_FORMAT(o.ShippedDate,  '%Y%m%d') AS UNSIGNED) AS shipped_date_key,
    o.OrderID                                               AS order_id_dd,
    od.UnitPrice,
    od.Quantity,
    od.Discount,
    o.Freight
FROM [Order Details] od                          -- Northwind bracket-escaped name
JOIN Orders           o   ON od.OrderID    = o.OrderID
JOIN dim_product      dp  ON od.ProductID  = dp.product_id
JOIN dim_customer     dc  ON o.CustomerID  = dc.customer_id
JOIN dim_employee     de  ON o.EmployeeID  = de.employee_id
JOIN dim_supplier     ds  ON dp.supplier_key = ds.supplier_key
JOIN dim_shipper      dsh ON o.ShipVia     = dsh.shipper_id
-- Only load dates that exist in dim_date (safety guard)
WHERE DATE_FORMAT(o.OrderDate, '%Y%m%d') IN (SELECT date_key FROM dim_date);
