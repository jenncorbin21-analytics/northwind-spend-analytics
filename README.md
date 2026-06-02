# Northwind Spend Analysis
### End-to-End Procurement Analytics | SQL · Star Schema · Power BI

---

## Overview

This project demonstrates a complete analytics engineering workflow applied to procurement and vendor spend data. Using the Northwind Traders dataset — a fictional specialty food distributor — I designed and built a dimensional data model from a normalized OLTP source, loaded it via ETL scripts, and developed a set of business-focused analytical queries that answer real procurement operations questions.

The goal wasn't to make a pretty dashboard. It was to build the back-end data structure that makes any reporting layer trustworthy, flexible, and maintainable.

---

## Business Questions Answered

| # | Question | Technique |
|---|----------|-----------|
| 1 | Which suppliers represent the highest concentration of spend? | Window functions, cumulative % |
| 2 | How does category spend trend quarter over quarter? | QoQ growth with LAG() |
| 3 | Which suppliers have the highest late shipment rate? | Date arithmetic, SLA comparison |
| 4 | Which products are at or below reorder level, by supplier? | Conditional logic, inventory risk |
| 5 | Where is discount leakage occurring by product and category? | Gross vs. net revenue delta |
| 6 | How do customers segment by spend and order frequency? | RFM-style CTE segmentation |
| 7 | How does sales rep performance compare year over year? | YoY growth with window functions |

---

## Architecture

```
Northwind OLTP (Source)
        │
        ▼
   ETL / Transform
  (02_etl scripts)
        │
        ▼
┌─────────────────────────────────────────────┐
│              Star Schema                    │
│                                             │
│  dim_supplier   dim_product   dim_customer  │
│  dim_employee   dim_date      dim_shipper   │
│                                             │
│         fact_order_lines (grain:            │
│          one row per order line item)       │
└─────────────────────────────────────────────┘
        │
        ▼
  Analytical SQL
  (03_analysis)
        │
        ▼
  Power BI Report
  (see /assets)
```

**Fact table grain:** One row per order line item. This grain supports flexible aggregation at the order, product, supplier, customer, employee, and time levels without pre-aggregating and losing analytical flexibility.

---

## Dimensional Model Design Decisions

**Why a star schema instead of querying the source directly?**
The Northwind OLTP schema is normalized for transaction performance, not analytical queries. Joining 6–8 tables on every report query is slow, brittle, and hard to maintain. The star schema separates concerns: dimensions hold descriptive attributes, the fact table holds measurable events. Reports written against the star schema are faster, simpler, and more consistent.

**Surrogate keys vs. natural keys**
Every dimension uses an auto-incremented surrogate key as the primary key. Natural keys from the source (e.g., `SupplierID`, `CustomerID`) are preserved as non-key columns for traceability and ETL idempotency. This pattern supports SCD (Slowly Changing Dimension) handling if source data evolves.

**Generated columns in the fact table**
`gross_amount` and `net_amount` are stored computed columns derived from `unit_price`, `quantity`, and `discount`. This ensures calculation consistency across every query — no risk of different reports applying the discount formula differently.

**Date dimension**
The date dimension is generated programmatically from the order date range using a recursive CTE, rather than loaded from a static lookup file. This keeps the ETL self-contained and portable.

---

## File Structure

```
northwind-spend-analysis/
├── sql/
│   ├── 01_schema/
│   │   └── 01_create_star_schema.sql     # DDL for all dimensions + fact table
│   ├── 02_etl/
│   │   ├── 01_load_dimensions.sql        # Transform + load all dimension tables
│   │   └── 02_load_fact.sql              # Resolve surrogate keys + load fact table
│   └── 03_analysis/
│       └── 01_analytical_queries.sql     # 7 business-focused analytical queries
├── assets/
│   └── (Power BI screenshots)
└── README.md
```

---

## How to Run

**Prerequisites:** MySQL 8.0+ with the [Northwind sample database](https://github.com/dalers/mywind) loaded.

```sql
-- Step 1: Create the star schema
SOURCE sql/01_schema/01_create_star_schema.sql;

-- Step 2: Load dimensions (run before fact table)
SOURCE sql/02_etl/01_load_dimensions.sql;

-- Step 3: Load the fact table
SOURCE sql/02_etl/02_load_fact.sql;

-- Step 4: Run analytical queries
SOURCE sql/03_analysis/01_analytical_queries.sql;
```

---

## Power BI Report

The Power BI report is built directly on top of this star schema. Key design choices:

- **Data model:** Imported star schema with relationships defined at the surrogate key level — no relationship on natural keys or measures
- **DAX measures:** All KPIs defined as explicit measures (not implicit aggregations) for consistency and reusability
- **Report pages:** Spend Concentration · Supplier Performance · Inventory Risk · Discount Analysis · Customer Segments

*Screenshots in `/assets`.*

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| MySQL 8.0 | Schema design, ETL, analytical queries |
| MySQL Workbench | Query development and schema visualization |
| Power BI Desktop | Report layer and DAX measures |
| Git / GitHub | Version control and portfolio publishing |

---

## What I'd Add with More Time

- **dbt models** to replace the raw ETL scripts with tested, documented, version-controlled transformations
- **Data quality tests** — null checks, referential integrity assertions, grain validation on the fact table
- **SCD Type 2** on `dim_supplier` and `dim_product` to capture historical price and attribute changes
- **Incremental load logic** in the ETL to support ongoing data refresh rather than full reloads

---

## About

**Jenn Corbin** | Data Analyst & Analytics Engineer  
[LinkedIn](https://linkedin.com/in/jenn-corbin-487a0a19) · [GitHub](https://github.com/jenncorbin21-analytics)  
Louisville, KY

*16 years in operations and procurement leadership. Now building the data infrastructure behind better business decisions.*
