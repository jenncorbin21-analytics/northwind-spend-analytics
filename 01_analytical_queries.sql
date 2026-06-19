-- ============================================================
-- Northwind Spend Analysis | Analytical Queries
-- Author: Jenn Corbin | github.com/jenncorbin21-analytics
-- Description: Business-focused analytical queries against
--              the star schema. Each query answers a specific
--              procurement or operations question.
-- ============================================================


-- ============================================================
-- SECTION 1: SPEND CONCENTRATION ANALYSIS
-- ============================================================

-- Q1: Total net spend by supplier — ranked
-- Identifies top suppliers by revenue contribution.
-- Supports vendor consolidation decisions.
SELECT
    ds.company_name                                      AS supplier,
    ds.country                                           AS supplier_country,
    SUM(fl.net_amount)                                   AS total_net_spend,
    ROUND(SUM(fl.net_amount) /
          SUM(SUM(fl.net_amount)) OVER () * 100, 2)     AS pct_of_total_spend,
    ROUND(SUM(SUM(fl.net_amount)) OVER
          (ORDER BY SUM(fl.net_amount) DESC
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) /
          SUM(SUM(fl.net_amount)) OVER () * 100, 2)     AS cumulative_pct,
    COUNT(DISTINCT fl.order_id)                          AS order_count,
    COUNT(fl.order_line_key)                             AS line_item_count
FROM fact_order_lines fl
JOIN dim_supplier     ds ON fl.supplier_key = ds.supplier_key
GROUP BY ds.supplier_key, ds.company_name, ds.country
ORDER BY total_net_spend DESC;


-- Q2: Spend by category — quarter over quarter
-- Reveals seasonal demand patterns by product category.
SELECT
    dp.category_name,
    dd.year,
    dd.quarter,
    CONCAT(dd.year, '-Q', dd.quarter)                   AS period,
    SUM(fl.net_amount)                                   AS net_spend,
    SUM(fl.quantity)                                     AS units_ordered,
    LAG(SUM(fl.net_amount)) OVER
        (PARTITION BY dp.category_name
         ORDER BY dd.year, dd.quarter)                  AS prior_quarter_spend,
    ROUND((SUM(fl.net_amount) -
           LAG(SUM(fl.net_amount)) OVER
               (PARTITION BY dp.category_name
                ORDER BY dd.year, dd.quarter)) /
          NULLIF(LAG(SUM(fl.net_amount)) OVER
               (PARTITION BY dp.category_name
                ORDER BY dd.year, dd.quarter), 0) * 100, 2) AS qoq_growth_pct
FROM fact_order_lines fl
JOIN dim_product      dp ON fl.product_key    = dp.product_key
JOIN dim_date         dd ON fl.order_date_key = dd.date_key
GROUP BY dp.category_name, dd.year, dd.quarter
ORDER BY dp.category_name, dd.year, dd.quarter;


-- ============================================================
-- SECTION 2: SUPPLIER PERFORMANCE
-- ============================================================

-- Q3: Supplier on-time shipping performance
-- Calculates average days to ship per supplier.
-- Note: required_date_key is NULL in this dataset (not
-- available in mywind source); late shipment rate omitted.
SELECT
    ds.company_name                                      AS supplier,
    COUNT(fl.order_line_key)                             AS total_lines,
    ROUND(AVG(
        DATEDIFF(
            dd_ship.full_date,
            dd_ord.full_date
        )), 1)                                           AS avg_days_to_ship,
    MIN(DATEDIFF(dd_ship.full_date, dd_ord.full_date))  AS min_days_to_ship,
    MAX(DATEDIFF(dd_ship.full_date, dd_ord.full_date))  AS max_days_to_ship
FROM fact_order_lines fl
JOIN dim_supplier     ds      ON fl.supplier_key      = ds.supplier_key
JOIN dim_date         dd_ord  ON fl.order_date_key    = dd_ord.date_key
JOIN dim_date         dd_ship ON fl.shipped_date_key  = dd_ship.date_key
WHERE fl.shipped_date_key IS NOT NULL
GROUP BY ds.supplier_key, ds.company_name
ORDER BY avg_days_to_ship DESC;


-- Q4: Products at or below reorder level by supplier
-- Proactive reorder risk identification.
-- Note: units_in_stock and units_on_order are not available
-- in the mywind source dataset; reorder_level shown for
-- reference against order volume.
SELECT
    ds.company_name                          AS supplier,
    dp.product_name,
    dp.category_name,
    dp.reorder_level,
    COUNT(fl.order_line_key)                 AS times_ordered,
    SUM(fl.quantity)                         AS total_units_ordered
FROM dim_product dp
JOIN dim_supplier      ds ON dp.supplier_key  = ds.supplier_key
LEFT JOIN fact_order_lines fl ON dp.product_key = fl.product_key
WHERE dp.discontinued = 0
GROUP BY dp.product_key, dp.product_name, dp.category_name,
         ds.company_name, dp.reorder_level
ORDER BY total_units_ordered DESC;


-- ============================================================
-- SECTION 3: PRODUCT REVENUE ANALYSIS
-- ============================================================

-- Q5: Top 10 products by net revenue with supplier context
-- Identifies highest-revenue products and their suppliers.
-- Supports category management and supplier prioritization.
-- Note: mywind dataset contains no discount data;
-- gross_amount equals net_amount across all records.
SELECT
    dp.product_name,
    dp.category_name,
    ds.company_name                          AS supplier,
    COUNT(fl.order_line_key)                 AS times_ordered,
    SUM(fl.quantity)                         AS total_units,
    ROUND(SUM(fl.net_amount), 2)             AS total_revenue,
    ROUND(AVG(fl.unit_price), 2)             AS avg_unit_price
FROM fact_order_lines fl
JOIN dim_product  dp ON fl.product_key  = dp.product_key
JOIN dim_supplier ds ON fl.supplier_key = ds.supplier_key
GROUP BY dp.product_key, dp.product_name, dp.category_name, ds.company_name
ORDER BY total_revenue DESC
LIMIT 10;


-- ============================================================
-- SECTION 4: CUSTOMER PURCHASING PATTERNS
-- ============================================================

-- Q6: Customer order frequency and spend cohorts
-- RFM-lite: segments customers by recency and spend.
WITH customer_metrics AS (
    SELECT
        dc.company_name                                  AS customer,
        dc.country,
        COUNT(DISTINCT fl.order_id)                      AS order_count,
        SUM(fl.net_amount)                               AS lifetime_spend,
        ROUND(SUM(fl.net_amount) /
              COUNT(DISTINCT fl.order_id), 2)            AS avg_order_value,
        MAX(dd.full_date)                                AS last_order_date,
        DATEDIFF(
            (SELECT MAX(full_date) FROM dim_date),
            MAX(dd.full_date))                           AS days_since_last_order
    FROM fact_order_lines fl
    JOIN dim_customer     dc ON fl.customer_key   = dc.customer_key
    JOIN dim_date         dd ON fl.order_date_key = dd.date_key
    GROUP BY dc.customer_key, dc.company_name, dc.country
)
SELECT
    customer,
    country,
    order_count,
    lifetime_spend,
    avg_order_value,
    last_order_date,
    days_since_last_order,
    CASE
        WHEN lifetime_spend >= 10000 AND order_count >= 10 THEN 'High Value – Active'
        WHEN lifetime_spend >= 10000 AND order_count  < 10 THEN 'High Value – Infrequent'
        WHEN lifetime_spend  < 10000 AND order_count >= 10 THEN 'Low Value – Active'
        ELSE 'Low Value – Infrequent'
    END                                                  AS customer_segment
FROM customer_metrics
ORDER BY lifetime_spend DESC;


-- ============================================================
-- SECTION 5: EMPLOYEE SALES PERFORMANCE
-- ============================================================

-- Q7: Sales rep performance with YoY comparison
SELECT
    de.full_name                                         AS employee,
    de.title,
    dd.year,
    SUM(fl.net_amount)                                   AS annual_net_sales,
    COUNT(DISTINCT fl.order_id)                          AS orders_handled,
    ROUND(SUM(fl.net_amount) /
          COUNT(DISTINCT fl.order_id), 2)                AS avg_order_value,
    LAG(SUM(fl.net_amount)) OVER
        (PARTITION BY de.employee_key
         ORDER BY dd.year)                              AS prior_year_sales,
    ROUND((SUM(fl.net_amount) -
           LAG(SUM(fl.net_amount)) OVER
               (PARTITION BY de.employee_key
                ORDER BY dd.year)) /
          NULLIF(LAG(SUM(fl.net_amount)) OVER
               (PARTITION BY de.employee_key
                ORDER BY dd.year), 0) * 100, 2)         AS yoy_growth_pct
FROM fact_order_lines fl
JOIN dim_employee      de ON fl.employee_key  = de.employee_key
JOIN dim_date          dd ON fl.order_date_key = dd.date_key
GROUP BY de.employee_key, de.full_name, de.title, dd.year
ORDER BY de.full_name, dd.year;
