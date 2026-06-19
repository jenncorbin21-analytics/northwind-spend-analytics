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
    o.id,
    dp.product_key,
    dc.customer_key,
    de.employee_key,
    ds.supplier_key,
    dsh.shipper_key,
    CAST(DATE_FORMAT(o.order_date,   '%Y%m%d') AS UNSIGNED) AS order_date_key,
    NULL                                                     AS required_date_key,
    CAST(DATE_FORMAT(o.shipped_date, '%Y%m%d') AS UNSIGNED) AS shipped_date_key,
    o.id                                                     AS order_id_dd,
    od.unit_price,
    od.quantity,
    od.discount,
    o.shipping_fee
FROM northwind.order_details od
JOIN northwind.orders        o   ON od.order_id    = o.id
JOIN dim_product             dp  ON od.product_id  = dp.product_id
JOIN dim_customer            dc  ON o.customer_id  = dc.customer_id
JOIN dim_employee            de  ON o.employee_id  = de.employee_id
JOIN dim_supplier            ds  ON dp.supplier_key = ds.supplier_key
LEFT JOIN dim_shipper        dsh ON o.shipper_id   = dsh.shipper_id
-- Only load dates that exist in dim_date (safety guard)
WHERE DATE_FORMAT(o.order_date, '%Y%m%d') IN (SELECT date_key FROM dim_date);
