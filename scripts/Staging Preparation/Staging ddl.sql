/*******************************************************************************
* Project: ObraAfriTelc Telecom Data Warehouse
* Module: Phase 2 - Staging Layer Setup
* Script: 01_create_staging_tables.sql
* Author: [Mohammed Sulieman]
* Description: This script creates the staging database and schema, then
*              
*******************************************************************************/


USE ObraAfriTelc_Staging;
GO

-- 2. CREATE A SCHEMA FOR STAGING OBJECTS (BEST PRACTICE FOR ORGANIZATION)
CREATE SCHEMA stg;
GO

-- 3. CREATE STAGING TABLES
-- Each table mirrors the source table but adds audit columns for ETL control.

-- Staging Table for Customer
CREATE TABLE stg.Customer (
    CustomerID INT NOT NULL,
    MSISDN VARCHAR(15) NOT NULL,
    CustomerName NVARCHAR(100) NOT NULL,
    Region NVARCHAR(50) NOT NULL,
    CustomerType VARCHAR(10) NOT NULL,
    ActivationDate DATE NOT NULL,
    DeactivationDate DATE NULL,
    -- Audit Columns
    LoadDate DATETIME2 NOT NULL DEFAULT GETDATE(), -- Timestamp of when the row was loaded to staging
    SourceSystem NVARCHAR(50) NOT NULL DEFAULT 'ObraAfriTelc_Source' -- Name of the source system
);
GO

-- Staging Table for Product
CREATE TABLE stg.Product (
    ProductID INT NOT NULL,
    ProductCode VARCHAR(10) NOT NULL,
    ProductName NVARCHAR(100) NOT NULL,
    ProductType VARCHAR(10) NOT NULL,
    MonthlyFee DECIMAL(10,2) NOT NULL,
    -- Audit Columns
    LoadDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    SourceSystem NVARCHAR(50) NOT NULL DEFAULT 'ObraAfriTelc_Source'
);
GO

-- Staging Table for CustomerProduct
CREATE TABLE stg.CustomerProduct (
    CustProdID INT NOT NULL,
    CustomerID INT NOT NULL,
    ProductID INT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NULL,
    -- Audit Columns
    LoadDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    SourceSystem NVARCHAR(50) NOT NULL DEFAULT 'ObraAfriTelc_Source'
);
GO

-- Staging Table for Billing
CREATE TABLE stg.Billing (
    BillingID BIGINT NOT NULL,
    CustomerID INT NOT NULL,
    BillingPeriodStart DATE NOT NULL,
    BillingPeriodEnd DATE NOT NULL,
    TotalCharge DECIMAL(12,2) NOT NULL,
    AmountPaid DECIMAL(12,2) NOT NULL,
    PaymentDate DATE NULL,
    InvoiceIssuedDate DATE NOT NULL,
    -- Audit Columns
    LoadDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    SourceSystem NVARCHAR(50) NOT NULL DEFAULT 'ObraAfriTelc_Source'
);
GO

-- Staging Table for CDR
CREATE TABLE stg.CDR (
    CDRID BIGINT NOT NULL,
    CustomerID INT NOT NULL,
    ServiceID INT NOT NULL,
    UsageStart DATETIME2 NOT NULL,
    UsageEnd DATETIME2 NOT NULL,
    Quantity DECIMAL(12,3) NOT NULL,
    Charge DECIMAL(10,4) NOT NULL,
    -- Audit Columns
    LoadDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    SourceSystem NVARCHAR(50) NOT NULL DEFAULT 'ObraAfriTelc_Source'
);
GO
-- Staging Table Service
CREATE TABLE stg.Service (
    ServiceID INT IDENTITY(1,1) PRIMARY KEY,
    ServiceName NVARCHAR(50) NOT NULL UNIQUE,
    UnitOfMeasure VARCHAR(10) NOT NULL,
    UnitPrice DECIMAL(10,4) NOT NULL
);
GO
