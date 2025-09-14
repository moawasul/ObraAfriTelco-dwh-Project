ObraAfriTelc Telecom Data Warehouse
📊 Project Overview
This project designs and implements a star-schema data warehouse for a fictional Sudanese telecom company, ObraAfriTelc. The solution ingests data from simulated operational systems (CRM, Billing, Network), transforms it through a staging layer, and loads it into an optimized dimensional model ready for analytics. The entire pipeline is built with custom T-SQL scripts on Microsoft SQL Server.

🎯 Business Objectives
To enable data-driven decision-making by providing a single source of truth for telecom metrics, including:

ARPU (Average Revenue Per User)

Churn Rate Analysis

New Subscriber Acquisition

Revenue by Product and Region

Network Usage Analytics (MOU, Data Usage)
🗃️ Data Architecture
graph LR
A[Source Systems] --> B[Staging Area]
B --> C[Data Warehouse]
C --> D[Power BI Dashboards]

subgraph A [Phase 1 - Source]
    A1[Customer CRM]
    A2[Billing System]
    A3[CDR Network Data]
end

subgraph B [Phase 2 - Staging]
    B1[Staging Tables]
    B2[Data Cleansing]
end

subgraph C [Phase 3 - DW]
    C1[dim_customer SCD2]
    C2[dim_product]
    C3[dim_date]
    C4[fact_billing]
    C5[fact_usage]
end

⚙️ Technical Implementation
Data Stack
Database: Microsoft SQL Server

ETL: Custom T-SQL Scripts (Stored Procedures, MERGE statements)

Data Modeling: Kimball Star Schema

Visualization: Power BI

Key Features
Synthetic Data Generation: Scripts to create realistic, scalable data for 5,000+ customers with billing and usage records.

Incremental Load Design: ETL processes built with watermarking for efficient daily loads.

Slowly Changing Dimensions (SCD): Type 2 implementation for dim_customer to track historical changes.

Data Quality Framework: Built-in checks for NULLs, duplicates, and referential integrity.


🚀 Getting Started
Prerequisites: SQL Server Management Studio (SSMS)

Clone the repo: git clone https://github.com/your-username/telecom-data-warehouse.git

Run Scripts in Order: Execute the SQL scripts in numerical order from the /01_source_system directory.

Generate Data: Execute the synthetic data script to populate the source system.

Run ETL: Execute the staging and data warehouse ETL scripts to build the star schema.

👨‍💻 Skills Demonstrated
Data Modeling: Star Schema Design, SCD2, Surrogate Keys

SQL Expertise: Advanced T-SQL, Stored Procedures, MERGE, CTEs

ETL Development: Incremental Loads, Data Quality Checks, Watermarking

Business Intelligence: KPI Definition, Telecom Domain Knowledge

Data Governance: Source-to-Target Mapping, Data Lineage

🤝 Contributing
This is a portfolio project. Feedback and suggestions are welcome!
