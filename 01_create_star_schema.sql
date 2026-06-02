-- ============================================================
-- Northwind Spend Analysis | Star Schema
-- Author: Jenn Corbin | github.com/jenncorbin21-analytics
-- Description: Dimensional model built on top of Northwind
--              source data to support procurement and vendor
--              spend analytics.
-- ============================================================

-- --------------------------------------------------------
-- DIMENSION: Suppliers
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_supplier (
    supplier_key      INT           AUTO_INCREMENT PRIMARY KEY,
    supplier_id       INT           NOT NULL,           -- NK from source
    company_name      VARCHAR(100)  NOT NULL,
    contact_name      VARCHAR(100),
    contact_title     VARCHAR(50),
    country           VARCHAR(50),
    region            VARCHAR(50),
    city              VARCHAR(50),
    phone             VARCHAR(30),
    fax               VARCHAR(30),
    home_page         VARCHAR(255),
    -- SCD Type 1 audit columns
    created_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- --------------------------------------------------------
-- DIMENSION: Products / Categories
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_product (
    product_key       INT           AUTO_INCREMENT PRIMARY KEY,
    product_id        INT           NOT NULL,           -- NK from source
    product_name      VARCHAR(100)  NOT NULL,
    category_id       INT,
    category_name     VARCHAR(50),
    category_description TEXT,
    quantity_per_unit VARCHAR(50),
    unit_price        DECIMAL(10,2),
    units_in_stock    INT,
    units_on_order    INT,
    reorder_level     INT,
    discontinued      TINYINT(1)    DEFAULT 0,
    supplier_key      INT,                              -- FK to dim_supplier
    created_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_product_supplier FOREIGN KEY (supplier_key)
        REFERENCES dim_supplier(supplier_key)
);

-- --------------------------------------------------------
-- DIMENSION: Customers
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_customer (
    customer_key      INT           AUTO_INCREMENT PRIMARY KEY,
    customer_id       CHAR(5)       NOT NULL,           -- NK from source
    company_name      VARCHAR(100)  NOT NULL,
    contact_name      VARCHAR(100),
    contact_title     VARCHAR(50),
    country           VARCHAR(50),
    region            VARCHAR(50),
    city              VARCHAR(50),
    postal_code       VARCHAR(20),
    phone             VARCHAR(30),
    fax               VARCHAR(30),
    created_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- --------------------------------------------------------
-- DIMENSION: Employees
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_employee (
    employee_key      INT           AUTO_INCREMENT PRIMARY KEY,
    employee_id       INT           NOT NULL,           -- NK from source
    full_name         VARCHAR(100)  NOT NULL,
    title             VARCHAR(50),
    title_of_courtesy VARCHAR(10),
    hire_date         DATE,
    city              VARCHAR(50),
    country           VARCHAR(50),
    reports_to_id     INT,
    created_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- --------------------------------------------------------
-- DIMENSION: Date
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_date (
    date_key          INT           PRIMARY KEY,        -- YYYYMMDD integer key
    full_date         DATE          NOT NULL,
    year              INT           NOT NULL,
    quarter           INT           NOT NULL,
    month_num         INT           NOT NULL,
    month_name        VARCHAR(20)   NOT NULL,
    week_of_year      INT           NOT NULL,
    day_of_week       INT           NOT NULL,
    day_name          VARCHAR(20)   NOT NULL,
    is_weekend        TINYINT(1)    DEFAULT 0,
    fiscal_year       INT,                              -- extend as needed
    fiscal_quarter    INT
);

-- --------------------------------------------------------
-- DIMENSION: Shippers
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_shipper (
    shipper_key       INT           AUTO_INCREMENT PRIMARY KEY,
    shipper_id        INT           NOT NULL,           -- NK from source
    company_name      VARCHAR(50)   NOT NULL,
    phone             VARCHAR(30),
    created_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- --------------------------------------------------------
-- FACT: Order Line Items (grain = one row per order line)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact_order_lines (
    order_line_key    BIGINT        AUTO_INCREMENT PRIMARY KEY,
    -- Foreign Keys
    order_id          INT           NOT NULL,
    product_key       INT           NOT NULL,
    customer_key      INT           NOT NULL,
    employee_key      INT           NOT NULL,
    supplier_key      INT           NOT NULL,
    shipper_key       INT           NOT NULL,
    order_date_key    INT           NOT NULL,
    required_date_key INT,
    shipped_date_key  INT,
    -- Degenerate Dimensions
    order_id_dd       INT           NOT NULL,           -- order number as DD
    -- Measures
    unit_price        DECIMAL(10,2) NOT NULL,
    quantity          SMALLINT      NOT NULL,
    discount          FLOAT         NOT NULL DEFAULT 0,
    gross_amount      DECIMAL(12,2) GENERATED ALWAYS AS
                          (unit_price * quantity) STORED,
    net_amount        DECIMAL(12,2) GENERATED ALWAYS AS
                          (unit_price * quantity * (1 - discount)) STORED,
    freight           DECIMAL(10,2),
    -- Constraints
    CONSTRAINT fk_fl_product  FOREIGN KEY (product_key)  REFERENCES dim_product(product_key),
    CONSTRAINT fk_fl_customer FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    CONSTRAINT fk_fl_employee FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    CONSTRAINT fk_fl_supplier FOREIGN KEY (supplier_key) REFERENCES dim_supplier(supplier_key),
    CONSTRAINT fk_fl_shipper  FOREIGN KEY (shipper_key)  REFERENCES dim_shipper(shipper_key),
    CONSTRAINT fk_fl_odate    FOREIGN KEY (order_date_key)    REFERENCES dim_date(date_key),
    CONSTRAINT fk_fl_rdate    FOREIGN KEY (required_date_key) REFERENCES dim_date(date_key),
    CONSTRAINT fk_fl_sdate    FOREIGN KEY (shipped_date_key)  REFERENCES dim_date(date_key)
);

-- --------------------------------------------------------
-- INDEXES for query performance
-- --------------------------------------------------------
CREATE INDEX idx_fl_order_date    ON fact_order_lines (order_date_key);
CREATE INDEX idx_fl_customer      ON fact_order_lines (customer_key);
CREATE INDEX idx_fl_supplier      ON fact_order_lines (supplier_key);
CREATE INDEX idx_fl_product       ON fact_order_lines (product_key);
CREATE INDEX idx_product_category ON dim_product (category_id);
CREATE INDEX idx_supplier_country ON dim_supplier (country);
