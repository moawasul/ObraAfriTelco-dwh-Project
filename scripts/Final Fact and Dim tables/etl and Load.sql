CREATE PROCEDURE etl.sp_Load_Dim_Product
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Starting load of dim_product...';

   -- TRUNCATE TABLE dw.dim_product; -- Full refresh Op 1
	DELETE FROM dw.dim_product; -- Full refresh Op 2

    INSERT INTO dw.dim_product (product_id, product_code, product_name, product_type, monthly_fee)
    SELECT 
        ProductID, 
        ProductCode, 
        ProductName, 
        ProductType, 
        MonthlyFee
    FROM ObraAfriTelc_Source.stg.Product; -- Direct from staging

    PRINT 'Completed load of dim_product. Loaded ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';
END;
GO

CREATE PROCEDURE etl.sp_Load_Dim_Service
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Starting load of dim_service...';

    --TRUNCATE TABLE dw.dim_service;-- Full refresh Op 2
	DELETE FROM dw.dim_product; -- Full refresh Op 2


    INSERT INTO dw.dim_service (service_id, service_name, unit_of_measure, unit_price)
    SELECT 
        ServiceID, 
        ServiceName, 
        UnitOfMeasure, 
        UnitPrice
    FROM ObraAfriTelc_Source.stg.Service; -- Direct from staging

    PRINT 'Completed load of dim_service. Loaded ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';
END;
GO

--CREATE PROCEDURE etl.sp_Load_Dim_Customer


CREATE PROCEDURE etl.sp_Load_Dim_Customer
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Starting SCD Type 2 load of dim_customer...';

    MERGE dw.dim_customer AS target
    USING ObraAfriTelc_Source.cleansed.v_Customer AS source 
    ON (target.customer_id = source.CustomerID AND target.is_current = 1) -- Match on natural key and current flag

    -- Check if current record has changed
    WHEN MATCHED AND (
        target.msisdn <> source.MSISDN
        OR target.region <> source.Region
        OR target.customer_type <> source.CustomerType
        OR target.effective_to <> '9999-12-31' -- Handle reactivations
    ) 
    THEN 
        UPDATE -- Expire the current record
        SET 
            target.is_current = 0,
            target.effective_to = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)) -- Set end date to yesterday

    -- Insert new records (brand new customers OR changes from above)
    WHEN NOT MATCHED BY TARGET 
    THEN 
        INSERT (customer_id, msisdn, region, customer_type, effective_from, effective_to, is_current)
        VALUES (source.CustomerID, source.MSISDN, source.Region, source.CustomerType, 
                CAST(GETDATE() AS DATE), -- Start from today
                '9999-12-31', -- Default end date (far future)
                1 -- Mark as current
        );

    PRINT 'Completed SCD Type 2 load of dim_customer.';
END;
GO

--CREATE  etl.sp_Load_Dim_Customer_Product


CREATE OR ALTER PROCEDURE etl.sp_Load_Dim_Customer_Product
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Starting load of dim_customer_product...';

    -- Use DELETE for safe reload, respecting any future FKs
    DELETE FROM dw.dim_customer_product;

    -- Insert all historical assignments from the cleansed view
    INSERT INTO dw.dim_customer_product (
        cust_sk, 
        product_sk, 
        start_date_sk, 
        end_date_sk, 
        is_current
    )
    SELECT
        c.cust_sk, -- Get the customer's surrogate key
        p.product_sk, -- Get the product's surrogate key
        d_start.date_sk, -- Convert StartDate to surrogate key
        d_end.date_sk, -- Convert EndDate to surrogate key (can be NULL)
        cp.IsCurrentFlag -- Use the flag from our cleansed view
    FROM ObraAfriTelc_Source.cleansed.v_CustomerProduct cp
    INNER JOIN dw.dim_customer c ON cp.CustomerID = c.customer_id
    INNER JOIN dw.dim_product p ON cp.ProductID = p.product_id
    INNER JOIN dw.dim_date d_start ON cp.StartDate = d_start.cal_date
    LEFT JOIN dw.dim_date d_end ON cp.EndDate = d_end.cal_date; -- LEFT JOIN because EndDate can be NULL

    PRINT 'Completed load of dim_customer_product. Loaded ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';
END;
GO

--CREATE  etl.sp_Load_Fact_Billing


CREATE OR ALTER PROCEDURE etl.sp_Load_Fact_Billing
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Starting load of fact_billing...';

    TRUNCATE TABLE dw.fact_billing; 

    INSERT INTO dw.fact_billing (
        cust_sk, 
        cust_prod_sk, -- NOW USING THE BRIDGE TABLE KEY
        date_sk, 
        total_charge, 
        amount_paid, 
        payment_status
    )
    SELECT
        c.cust_sk, 
        cp.cust_prod_sk, -- This is the correct key for the historical product assignment
        d.date_sk, 
        b.TotalCharge,
        b.AmountPaid,
        b.PaymentStatus
    FROM ObraAfriTelc_Source.cleansed.v_Billing b
    INNER JOIN dw.dim_customer c ON b.CustomerID = c.customer_id 
        AND b.InvoiceIssuedDate >= c.effective_from 
        AND b.InvoiceIssuedDate <= c.effective_to
    -- NEW LOGIC: Find the product assignment that was active on the invoice date
    INNER JOIN dw.dim_customer_product cp ON c.cust_sk = cp.cust_sk
        AND b.InvoiceIssuedDate >= d_start.cal_date -- Use date logic from dim_customer_product
        AND (b.InvoiceIssuedDate <= d_end.cal_date OR cp.is_current = 1)
    INNER JOIN dw.dim_date d ON b.InvoiceIssuedDate = d.cal_date;

    PRINT 'Completed load of fact_billing. Loaded ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';
END;
GO

-- SIMPLIFIED FACT_USAGE LOAD (FIXED)
CREATE OR ALTER PROCEDURE etl.sp_Load_Fact_Usage
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Starting load of fact_usage...';

    TRUNCATE TABLE dw.fact_usage;

    INSERT INTO dw.fact_usage (cust_sk, service_sk, date_sk, total_quantity, total_revenue)
    SELECT
        c.cust_sk, -- Get customer key
        s.service_sk, -- Get service key
        d.date_sk, -- Get date key
        SUM(cdr.Quantity) AS total_quantity,
        SUM(cdr.Revenue) AS total_revenue
    FROM ObraAfriTelc_Source.cleansed.v_CDR cdr
    -- SIMPLIFIED JOIN: Remove complex date logic for now
    INNER JOIN dw.dim_customer c ON cdr.CustomerID = c.customer_id
    INNER JOIN dw.dim_service s ON cdr.ServiceID = s.service_id
    INNER JOIN dw.dim_date d ON CAST(cdr.UsageStart AS DATE) = d.cal_date
    GROUP BY c.cust_sk, s.service_sk, d.date_sk;

    PRINT 'Completed load of fact_usage. Loaded ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';
END;
GO

--CREATE  etl.sp_Master_ETL_Load


CREATE OR ALTER PROCEDURE etl.sp_Master_ETL_Load
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        PRINT '==================================================================';
        PRINT 'STARTING MASTER ETL LOAD';
        PRINT '==================================================================';

        -- STEP 1: TRUNCATE ALL FACT TABLES FIRST (to avoid FK conflicts)
        PRINT '1. Truncating fact tables...';
        TRUNCATE TABLE dw.fact_billing;
        TRUNCATE TABLE dw.fact_usage;
        PRINT '   Fact tables truncated.';
		DELETE FROM dw.dim_customer_product;; 
        PRINT '   Fact and bridge tables truncated.';

        -- STEP 2: LOAD DIMENSIONS (must be loaded before facts)
        PRINT '2. Loading dimensions...';
        EXEC etl.sp_Load_Dim_Product;
        EXEC etl.sp_Load_Dim_Service;
        EXEC etl.sp_Load_Dim_Customer; 
        EXEC etl.sp_Load_Dim_Customer_Product;
        PRINT '   Dimensions loaded successfully.';

        -- STEP 3: LOAD FACT TABLES (after dimensions are ready)
        PRINT '3. Loading fact tables...';
        EXEC etl.sp_Load_Fact_Billing;
        EXEC etl.sp_Load_Fact_Usage;
        PRINT '   Fact tables loaded successfully.';

        PRINT '==================================================================';
        PRINT 'MASTER ETL LOAD COMPLETED SUCCESSFULLY!';
        PRINT '==================================================================';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR in Master ETL Load: ' + ERROR_MESSAGE();
        THROW; -- Re-raise the error
    END CATCH
END;
GO

--For valdition and check
EXEC etl.sp_Master_ETL_Load;

SELECT TOP(3) * FROM dw.fact_billing;
SELECT TOP(3) * FROM dw.fact_usage;
SELECT TOP(3) * FROM dw.dim_service;
SELECT TOP(3) * FROM dw.dim_product;
SELECT TOP(3) * FROM dw.dim_customer;
SELECT TOP(3) * FROM dw.dim_customer_product;
SELECT TOP(3) * FROM cleansed.v_CustomerProduct
SELECT TOP(3) * FROM stg.CustomerProduct
