--Create the DWH Layer with fact and dim

-- Create schemas for organization
CREATE SCHEMA dw;    -- For dimension and fact tables

CREATE SCHEMA etl;   -- For stored procedures

-- Dimension: Customer (Using SCD Type 2 for history)
CREATE TABLE dw.dim_customer (
    cust_sk INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    customer_id INT NOT NULL,               -- Natural Key (from source)
    msisdn VARCHAR(15) NOT NULL,
    region NVARCHAR(50) NOT NULL,
    customer_type VARCHAR(10) NOT NULL,
    effective_from DATE NOT NULL,
    effective_to DATE NOT NULL DEFAULT '9999-12-31',
    is_current BIT NOT NULL DEFAULT 1
);

-- Dimension: Product
CREATE TABLE dw.dim_product (
    product_sk INT IDENTITY(1,1) PRIMARY KEY,
    product_id INT NOT NULL,                -- Natural Key
    product_code VARCHAR(10) NOT NULL,
    product_name NVARCHAR(100) NOT NULL,
    product_type VARCHAR(10) NOT NULL,
    monthly_fee DECIMAL(10,2) NOT NULL
);

-- Dimension: Service
CREATE TABLE dw.dim_service (
    service_sk INT IDENTITY(1,1) PRIMARY KEY,
    service_id INT NOT NULL,                -- Natural Key
    service_name NVARCHAR(50) NOT NULL,
    unit_of_measure VARCHAR(10) NOT NULL,
    unit_price DECIMAL(10,4) NOT NULL
);

-- Dimension: Service stomer_product

CREATE TABLE dw.dim_customer_product (
    cust_prod_sk INT IDENTITY(1,1) PRIMARY KEY, -- New surrogate key for this table
    cust_sk INT NOT NULL FOREIGN KEY REFERENCES dw.dim_customer(cust_sk), -- Link to customer
    product_sk INT NOT NULL FOREIGN KEY REFERENCES dw.dim_product(product_sk), -- Link to product
    start_date_sk INT NOT NULL FOREIGN KEY REFERENCES dw.dim_date(date_sk), -- Start of assignment
    end_date_sk INT NULL FOREIGN KEY REFERENCES dw.dim_date(date_sk), -- End of assignment (NULL if current)
    is_current BIT NOT NULL DEFAULT 0 -- Flag for easy filtering
);


--Create the dim_date Table

CREATE TABLE dw.dim_date (
    date_sk INT PRIMARY KEY, -- Surrogate Key, formatted as YYYYMMDD
    cal_date DATE NOT NULL,  -- Actual date
    day INT NOT NULL,        -- Day of month (1-31)
    day_name VARCHAR(9) NOT NULL, -- Full day name (e.g., Monday)
    day_short_name CHAR(3) NOT NULL, -- Short day name (e.g., Mon)
    day_of_week INT NOT NULL, -- Number for day of week (1=Sunday, 7=Saturday)
    day_of_year INT NOT NULL, -- Number for day of year (1-366)
    is_weekend BIT NOT NULL, -- Flag for weekend (1=Weekend, 0=Weekday)
    week_of_year INT NOT NULL, -- Week number (1-53)
    month INT NOT NULL,      -- Month number (1-12)
    month_name VARCHAR(9) NOT NULL, -- Full month name (e.g., January)
    month_short_name CHAR(3) NOT NULL, -- Short month name (e.g., Jan)
    quarter INT NOT NULL,    -- Quarter number (1-4)
    quarter_name CHAR(2) NOT NULL, -- Quarter name (e.g., Q1)
    year INT NOT NULL,       -- Year (e.g., 2025)
    first_day_of_month DATE NOT NULL, -- First date of the month
    last_day_of_month DATE NOT NULL, -- Last date of the month
    -- Fiscal period columns (example: fiscal year starts in April)
    fiscal_month INT NULL,
    fiscal_quarter INT NULL,
    fiscal_year INT NULL
);
GO
-- Populate the date dimension
DECLARE @StartDate DATE = '2020-01-01'; -- Start of your historical data
DECLARE @EndDate DATE = '2026-12-31';   -- Well into the future

PRINT 'Starting population of dim_date...';

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO dw.dim_date (
        date_sk,
        cal_date,
        day,
        day_name,
        day_short_name,
        day_of_week,
        day_of_year,
        is_weekend,
        week_of_year,
        month,
        month_name,
        month_short_name,
        quarter,
        quarter_name,
        year,
        first_day_of_month,
        last_day_of_month,
        fiscal_month,
        fiscal_quarter,
        fiscal_year
    )
    VALUES (
        CONVERT(INT, CONVERT(CHAR(8), @StartDate, 112)), -- date_sk (YYYYMMDD)
        @StartDate, -- cal_date
        DATEPART(DAY, @StartDate), -- day
        DATENAME(WEEKDAY, @StartDate), -- day_name
        UPPer(LEFT(DATENAME(WEEKDAY, @StartDate), 3)), -- day_short_name
        DATEPART(WEEKDAY, @StartDate), -- day_of_week
        DATEPART(DAYOFYEAR, @StartDate), -- day_of_year
        -- is_weekend: 1 if Saturday or Sunday, else 0
        CASE WHEN DATENAME(WEEKDAY, @StartDate) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END,
        DATEPART(ISO_WEEK, @StartDate), -- week_of_year (ISO standard)
        DATEPART(MONTH, @StartDate), -- month
        DATENAME(MONTH, @StartDate), -- month_name
        UPPER(LEFT(DATENAME(MONTH, @StartDate), 3)), -- month_short_name
        DATEPART(QUARTER, @StartDate), -- quarter
        'Q' + CAST(DATEPART(QUARTER, @StartDate) AS CHAR(1)), -- quarter_name
        DATEPART(YEAR, @StartDate), -- year
        DATEFROMPARTS(YEAR(@StartDate), MONTH(@StartDate), 1), -- first_day_of_month
        EOMONTH(@StartDate), -- last_day_of_month
        -- Example Fiscal Year: Starting April 1st (Common in many businesses)
        (CASE WHEN MONTH(@StartDate) >= 4 THEN MONTH(@StartDate) - 3 ELSE MONTH(@StartDate) + 9 END), -- fiscal_month
        (CASE 
            WHEN MONTH(@StartDate) BETWEEN 4 AND 6 THEN 1
            WHEN MONTH(@StartDate) BETWEEN 7 AND 9 THEN 2
            WHEN MONTH(@StartDate) BETWEEN 10 AND 12 THEN 3
            ELSE 4
        END), -- fiscal_quarter
        (CASE WHEN MONTH(@StartDate) >= 4 THEN YEAR(@StartDate) + 1 ELSE YEAR(@StartDate) END) -- fiscal_year
    );

    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;

PRINT 'Population of dim_date completed successfully.';
GO

-- Creat The Facts Step
-- Fact: Billing (Grain: One row per invoice)
CREATE TABLE dw.fact_billing (
    billing_sk BIGINT IDENTITY(1,1) PRIMARY KEY,
    cust_sk INT NOT NULL FOREIGN KEY REFERENCES dw.dim_customer(cust_sk),
    -- NEW: Add a link to the customer product history (the bridge table)
    cust_prod_sk INT NOT NULL FOREIGN KEY REFERENCES dw.dim_customer_product(cust_prod_sk), 

    date_sk INT NOT NULL FOREIGN KEY REFERENCES dw.dim_date(date_sk), -- Invoice Date
    total_charge DECIMAL(12,2) NOT NULL,
    amount_paid DECIMAL(12,2) NOT NULL,
    payment_status VARCHAR(10) NOT NULL
);

-- Fact: Usage (Grain: Daily summary per customer/service)
CREATE TABLE dw.fact_usage (
    usage_sk BIGINT IDENTITY(1,1) PRIMARY KEY,
    cust_sk INT NOT NULL FOREIGN KEY REFERENCES dw.dim_customer(cust_sk),
    service_sk INT NOT NULL FOREIGN KEY REFERENCES dw.dim_service(service_sk),
    date_sk INT NOT NULL FOREIGN KEY REFERENCES dw.dim_date(date_sk), -- Usage Date
    total_quantity DECIMAL(12,3) NOT NULL,
    total_revenue DECIMAL(12,4) NOT NULL
);
