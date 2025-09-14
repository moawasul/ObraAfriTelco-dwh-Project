/* ===========================================================
   PHASE 1 - DATA SOURCE DESIGN (DDL) & SYNTHETIC DATA GENERATION
   Project: ObraAfriTelc Telecom DW
   Purpose: Create the simulated source system and populate it
            with 5,000 customers and related data for training.
 
   =========================================================== */

-- 1. CREATE THE SOURCE SYSTEM DATABASE
CREATE DATABASE ObraAfriTelc_Source;
GO

USE ObraAfriTelc_Source;
GO

/* ===========================================================
   2. CREATE SOURCE TABLES
   =========================================================== */
CREATE TABLE dbo.Customer (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    MSISDN VARCHAR(15) NOT NULL UNIQUE,
    CustomerName NVARCHAR(100) NOT NULL,
    Region NVARCHAR(50) NOT NULL,
    CustomerType VARCHAR(10) NOT NULL CHECK (CustomerType IN ('Prepaid','Postpaid')),
    ActivationDate DATE NOT NULL,
    DeactivationDate DATE NULL,
    LastUpdated DATETIME2 DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.Product (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductCode VARCHAR(10) NOT NULL UNIQUE,
    ProductName NVARCHAR(100) NOT NULL,
    ProductType VARCHAR(10) NOT NULL CHECK (ProductType IN ('Prepaid','Postpaid')),
    MonthlyFee DECIMAL(10,2) NOT NULL DEFAULT 0
);
GO

-- NEW CRITICAL TABLE: Tracks which product a customer is subscribed to over time
CREATE TABLE dbo.CustomerProduct (
    CustProdID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL FOREIGN KEY REFERENCES dbo.Customer(CustomerID),
    ProductID INT NOT NULL FOREIGN KEY REFERENCES dbo.Product(ProductID),
    StartDate DATE NOT NULL, -- Date they switched to this product
    EndDate DATE NULL, -- NULL means it's their current product
    LastUpdated DATETIME2 DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.Service (
    ServiceID INT IDENTITY(1,1) PRIMARY KEY,
    ServiceName NVARCHAR(50) NOT NULL UNIQUE,
    UnitOfMeasure VARCHAR(10) NOT NULL,
    UnitPrice DECIMAL(10,4) NOT NULL
);
GO

CREATE TABLE dbo.Billing (
    BillingID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL FOREIGN KEY REFERENCES dbo.Customer(CustomerID),
    BillingPeriodStart DATE NOT NULL,
    BillingPeriodEnd DATE NOT NULL,
    TotalCharge DECIMAL(12,2) NOT NULL,
    AmountPaid DECIMAL(12,2) NOT NULL,
    PaymentDate DATE NULL,
    InvoiceIssuedDate DATE NOT NULL
);
GO

CREATE TABLE dbo.CDR (
    CDRID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL FOREIGN KEY REFERENCES dbo.Customer(CustomerID),
    ServiceID INT NOT NULL FOREIGN KEY REFERENCES dbo.Service(ServiceID),
    UsageStart DATETIME2 NOT NULL,
    UsageEnd DATETIME2 NOT NULL,
    Quantity DECIMAL(12,3) NOT NULL,
    Charge DECIMAL(10,4) NOT NULL
);
GO

/* ===========================================================
   3. POPULATE STATIC REFERENCE TABLES (Product & Service)
   =========================================================== */
INSERT INTO dbo.Product (ProductCode, ProductName, ProductType, MonthlyFee)
VALUES
('PRE_BASIC', 'Prepaid Basic', 'Prepaid', 0),
('PRE_PLUS', 'Prepaid Plus', 'Prepaid', 0),
('POST_MINI', 'Postpaid Mini', 'Postpaid', 50.00),
('POST_PRO', 'Postpaid Pro', 'Postpaid', 120.00);

INSERT INTO dbo.Service (ServiceName, UnitOfMeasure, UnitPrice)
VALUES
('Voice', 'MIN', 0.25),
('Data', 'MB', 0.05),
('SMS', 'SMS', 0.10),
('International Roaming', 'MIN', 1.50);
GO

/* ===========================================================
   4. DECLARE FIXED "AS OF" DATE FOR CONSISTENT DATA
   =========================================================== */
DECLARE @AsOfDate DATE = '2025-09-10';
DECLARE @NumCustomers INT = 5000;
DECLARE @i INT = 1;

/* ===========================================================
   5. GENERATE SYNTHETIC CUSTOMER DATA
   =========================================================== */

WHILE @i <= @NumCustomers
BEGIN
    INSERT INTO dbo.Customer (MSISDN, CustomerName, Region, CustomerType, ActivationDate, DeactivationDate)
    VALUES (
        '942' + RIGHT('000000000' + CAST(ABS(CHECKSUM(NEWID())) % 1000000000 AS VARCHAR(9)), 9),
        'Customer_' + RIGHT('0000' + CAST(@i AS VARCHAR(5)), 5),
        CASE (ABS(CHECKSUM(NEWID())) % 10)
            WHEN 0 THEN 'Dar' WHEN 1 THEN 'Kordo' WHEN 2 THEN 'Zirah'
            WHEN 3 THEN 'Ssala' WHEN 4 THEN 'Redea' ELSE 'Khara'
        END,
        CASE WHEN (ABS(CHECKSUM(NEWID())) % 10) < 7 THEN 'Prepaid' ELSE 'Postpaid' END,
        DATEADD(DAY, ABS(CHECKSUM(NEWID())) % DATEDIFF(DAY, '2020-01-01', @AsOfDate), '2020-01-01'),
        CASE WHEN (ABS(CHECKSUM(NEWID())) % 10) = 0 THEN DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 100, DATEADD(DAY, -100, @AsOfDate)) ELSE NULL END
    );
    SET @i = @i + 1;
END;
GO

/* ===========================================================
   6. POPULATE CustomerProduct HISTORY
   This is a CRITICAL STEP for data quality.
   Assigns a product to each customer for their active lifetime.
   =========================================================== */

-- Define key parameters for data generation
DECLARE @AsOfDate DATE = '2025-09-10'; -- Fixed date for consistent data generation
DECLARE @NumCustomers INT = 5000;      -- Total number of customers to generate
DECLARE @i INT = 1;                    -- Loop counter initialization

-- Begin loop to generate each customer record
WHILE @i <= @NumCustomers
BEGIN
    INSERT INTO dbo.Customer (MSISDN, CustomerName, Region, CustomerType, ActivationDate, DeactivationDate)
    VALUES (
        -- Generate a random MSISDN (phone number) with Sudanese country code (942)
        '942' + RIGHT('000000000' + CAST(ABS(CHECKSUM(NEWID())) % 1000000000 AS VARCHAR(9)), 9),
        
        -- Create a sequential customer name (e.g., Customer_0001, Customer_0002)
        'Customer_' + RIGHT('0000' + CAST(@i AS VARCHAR(5)), 5),
        
        -- Randomly assign a region with weighted distribution (50% Khara)
        CASE (ABS(CHECKSUM(NEWID())) % 10)
            WHEN 0 THEN 'Dar' 
            WHEN 1 THEN 'Kordo' 
            WHEN 2 THEN 'Zirah'
            WHEN 3 THEN 'Ssala' 
            WHEN 4 THEN 'Redea' 
            ELSE 'Khara' -- 50% probability (5/10 cases)
        END,
        
        -- Assign customer type: 70% Prepaid, 30% Postpaid
        CASE WHEN (ABS(CHECKSUM(NEWID())) % 10) < 7 THEN 'Prepaid' ELSE 'Postpaid' END,
        
        -- Generate random activation date between 2020-01-01 and @AsOfDate
        DATEADD(DAY, ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % DATEDIFF(DAY, '2020-01-01', @AsOfDate), '2020-01-01'),
        
        -- Randomly deactivate ~10% of customers (with random deactivation date in the past 100 days)
        CASE WHEN (ABS(CHECKSUM(NEWID())) % 10) = 0 
             THEN DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 100, DATEADD(DAY, -100, @AsOfDate)) 
             ELSE NULL 
        END
    );
    
    -- Increment loop counter
    SET @i = @i + 1;
END;
GO
/* ===========================================================
   7. GENERATE BILLING RECORDS (For Postpaid Customers Only)
   =========================================================== */

-- Step 1: Declare and initialize @AsOfDate variable (important!)
-- This represents the "cutoff date" up to which we will generate billing data.
DECLARE @AsOfDate DATE = GETDATE();  
-- ✅ This ensures that your CROSS JOIN has a value for @AsOfDate

INSERT INTO dbo.Billing 
(
    CustomerID, 
    BillingPeriodStart, 
    BillingPeriodEnd, 
    TotalCharge, 
    AmountPaid, 
    PaymentDate, 
    InvoiceIssuedDate
)
SELECT
    cp.CustomerID,
    BPStart.BillingPeriodStart,
    EOMONTH(BPStart.BillingPeriodStart) AS BillingPeriodEnd,

    -- TotalCharge: Monthly fee + random additional usage charge (10–200 range)
    p.MonthlyFee + (10 + (ABS(CHECKSUM(NEWID())) % 190)),

    -- AmountPaid: 10% chance of no payment, 10% chance of partial payment (80%), else full payment
    CASE (ABS(CHECKSUM(NEWID())) % 10)
        WHEN 0 THEN 0
        WHEN 1 THEN (p.MonthlyFee + (10 + (ABS(CHECKSUM(NEWID())) % 190))) * 0.8
        ELSE p.MonthlyFee + (10 + (ABS(CHECKSUM(NEWID())) % 190))
    END,

    -- PaymentDate: Generate random payment date within 15 days after invoice issued date (NULL if unpaid)
    CASE 
        WHEN (ABS(CHECKSUM(NEWID())) % 10) != 0 
            THEN DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 15, BPStart.InvoiceIssuedDate) 
        ELSE NULL 
    END,

    -- InvoiceIssuedDate: From CROSS APPLY subquery
    BPStart.InvoiceIssuedDate

FROM dbo.CustomerProduct cp
INNER JOIN dbo.Product p 
    ON cp.ProductID = p.ProductID
INNER JOIN dbo.Customer c 
    ON cp.CustomerID = c.CustomerID

-- Make @AsOfDate available to the CROSS APPLY as a column
CROSS JOIN (SELECT @AsOfDate AS AOD) AS ref  

-- CROSS APPLY generates a row for each billing period between StartDate and AsOfDate
CROSS APPLY (
    SELECT
        -- BillingPeriodStart = first day of each month from start date
        DATEADD(MONTH, n.n, DATEADD(MONTH, DATEDIFF(MONTH, 0, cp.StartDate), 0)) AS BillingPeriodStart,

        -- InvoiceIssuedDate = day after the end of that month
        DATEADD(DAY, 1, EOMONTH(DATEADD(MONTH, n.n, DATEADD(MONTH, DATEDIFF(MONTH, 0, cp.StartDate), 0)))) AS InvoiceIssuedDate

    FROM (
        -- Generate up to 100 months of data (enough for training)
        SELECT TOP 100 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n 
        FROM sys.objects
    ) n

    -- Only generate rows where:
    -- 1. Billing period start is before AsOfDate
    -- 2. Customer is still active (EndDate is NULL or after this period)
    WHERE DATEADD(MONTH, n.n, DATEADD(MONTH, DATEDIFF(MONTH, 0, cp.StartDate), 0)) < ref.AOD
      AND (cp.EndDate IS NULL OR 
           DATEADD(MONTH, n.n, DATEADD(MONTH, DATEDIFF(MONTH, 0, cp.StartDate), 0)) < cp.EndDate)
) BPStart

-- Only generate billing for Postpaid customers
WHERE p.ProductType = 'Postpaid';
GO



/* ===========================================================
   8. GENERATE USAGE RECORDS (CDRs) FOR ALL CUSTOMERS
     GENERATE SYNTHETIC CDRs (Call Detail Records)
   Purpose: Simulate random network usage events for training.
     =========================================================== */

-- Step 1: Declare control variables
DECLARE @NumCDRs INT = 50000;          -- Total number of CDRs to generate
DECLARE @j INT = 1;                    -- Loop counter
DECLARE @AsOfDate DATETIME = '2020-01-01'; -- Reference date for generating usage timestamps

-- Step 2: Declare per-loop variables to avoid repeated random selects
DECLARE @RandomCustomerID INT;
DECLARE @RandomServiceID INT;
DECLARE @RandomServiceName NVARCHAR(50);
DECLARE @UsageStart DATETIME;
DECLARE @UsageEnd DATETIME;
DECLARE @Quantity DECIMAL(10,3);
DECLARE @UnitPrice DECIMAL(10,4);

-- Step 3: Loop until we generate the desired number of CDRs
WHILE @j <= @NumCDRs
BEGIN
    /* ===========================================================
       1. Pick a random active customer
       =========================================================== */
    SELECT TOP 1 @RandomCustomerID = CustomerID
    FROM dbo.Customer
    WHERE DeactivationDate IS NULL OR DeactivationDate > @AsOfDate
    ORDER BY NEWID();

    /* ===========================================================
       2. Pick a random service (Voice/Data/SMS)
       =========================================================== */
    SELECT TOP 1 
        @RandomServiceID = ServiceID,
        @RandomServiceName = ServiceName,
        @UnitPrice = UnitPrice
    FROM dbo.Service
    WHERE ServiceName IN ('Voice', 'Data', 'SMS')
    ORDER BY NEWID();

    /* ===========================================================
       3. Generate random start & end timestamps (last 90 days)
       =========================================================== */
    SET @UsageStart = DATEADD(SECOND, - (ABS(CHECKSUM(NEWID())) % 7776000), @AsOfDate);
    SET @UsageEnd   = DATEADD(SECOND, (ABS(CHECKSUM(NEWID())) % 7200), @UsageStart);

    /* ===========================================================
       4. Generate random quantity based on service type
       =========================================================== */
    IF @RandomServiceName = 'Voice'
        SET @Quantity = (ABS(CHECKSUM(NEWID())) % 120) + 1;  -- 1-120 minutes
    ELSE IF @RandomServiceName = 'Data'
        SET @Quantity = (ABS(CHECKSUM(NEWID())) % 500) + 1;  -- 1-500 MB
    ELSE
        SET @Quantity = 1;                                  -- 1 SMS per record

    /* ===========================================================
       5. Insert the generated row into dbo.CDR
       =========================================================== */
    INSERT INTO dbo.CDR (CustomerID, ServiceID, UsageStart, UsageEnd, Quantity, Charge)
    VALUES
    (
        @RandomCustomerID,
        @RandomServiceID,
        @UsageStart,
        @UsageEnd,
        @Quantity,
        -- Charge = Quantity * UnitPrice * random factor (0.8–1.2)
        @Quantity * @UnitPrice * (0.8 + (ABS(CHECKSUM(NEWID())) % 41) * 0.01)
    );

    -- Step 6: Increment loop counter
    SET @j = @j + 1;
END;
GO


/* ===========================================================
   9. DATA VALIDATION CHECKS - RUN THESE QUERIES
   =========================================================== */
-- Check 1: Data spread and counts
SELECT 'Total Customers' AS Metric, COUNT(*) AS Value FROM dbo.Customer
UNION ALL SELECT 'Active Customers', COUNT(*) FROM dbo.Customer WHERE DeactivationDate IS NULL
UNION ALL SELECT 'Postpaid Customers', COUNT(*) FROM dbo.Customer WHERE CustomerType = 'Postpaid'
UNION ALL SELECT 'Prepaid Customers', COUNT(*) FROM dbo.Customer WHERE CustomerType = 'Prepaid';

-- Check 2: Count of bills generated
SELECT 'Billing Records' AS Metric, COUNT(*) AS Value FROM dbo.Billing;

-- Check 3: Count of CDRs generated
SELECT 'CDR Records' AS Metric, COUNT(*) AS Value FROM dbo.CDR;

-- Check 4: Critical Check - Ensure every Postpaid customer has a product assignment and billing records
SELECT
    c.CustomerID,
    c.CustomerName,
    p.ProductCode,
    (SELECT COUNT(*) FROM dbo.Billing b WHERE b.CustomerID = c.CustomerID) AS NumberOfBills
FROM dbo.Customer c
INNER JOIN dbo.CustomerProduct cp ON c.CustomerID = cp.CustomerID
INNER JOIN dbo.Product p ON cp.ProductID = p.ProductID
WHERE c.CustomerType = 'Postpaid'
AND cp.EndDate IS NULL; -- Check their current product

PRINT 'Phase 1 Complete: ObraAfriTelc_Source database populated with consistent data up to 2025-09-10.';
PRINT 'Please run the validation queries (Section 9) to verify data quality.';

SELECT 
    CustomerType,
    Region,
    COUNT(*) AS CustomerCount,
    COUNT(CASE WHEN DeactivationDate IS NULL THEN 1 END) AS ActiveCustomers
FROM dbo.Customer 
GROUP BY CustomerType, Region
ORDER BY CustomerCount DESC;
