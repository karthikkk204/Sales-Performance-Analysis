# AdventureWorks End-to-End Data Analytics Pipeline

An end-to-end data pipeline project that extracts raw sales, customer, product, and territory data from CSV files, ingests it into MySQL, cleans and transforms the data across multi-tiered schemas (Raw, Staging, Analytics), and Prepares the data for downstream reporting in Power BI.

---

## 📌 Architecture Overview

The pipeline implements a 3-layer architecture inside MySQL:

1. **`adworks_raw` (Landing/Raw Layer)**: Raw data ingested directly from source CSV files using Python (`pandas` + `sqlalchemy`).
2. **`adworks_staging` (Transformation/Staging Layer)**: Cleansed, formatted, and joined intermediate datasets (handling column data types, string standardization, missing values, and subcategory lookups).
3. **`adworks_analytics` (Analytics/Reporting Layer)**: A fully consolidated, production-ready star-schema reporting table (`sales_data`) containing calculated KPIs like Revenue, Cost, and Profit.

```
       +-------------------------+
       |   Source CSV Datasets   |
       +-------------------------+
                    |
                    v (Python / Pandas / SQLAlchemy)
       +-------------------------+
       |       adworks_raw       |  <-- Raw ingested tables
       +-------------------------+
                    |
                    v (SQL Transformation Scripts)
       +-------------------------+
       |     adworks_staging     |  <-- Staging: products, customers, transactions
       +-------------------------+
                    |
                    v (SQL Aggregations & Logic)
       +-------------------------+
       |    adworks_analytics    |  <-- Production table: sales_data
       +-------------------------+
                    |
                    v (MySQL ODBC Connector)
       +-------------------------+
       |        Power BI         |  <-- Business Intelligence Dashboards
       +-------------------------+
```

---

## 🛠️ Data Pipeline Breakdown

### 1. Database & User Administration
Security best practices are established by creating restricted database schemas and standardizing user permissions:
* User `anidu`: Administrative user with full access across raw, staging, and analytics layers.
* User `yakubu`: Read-only reporting user restricted to `adworks_analytics` for secure Power BI connectivity.

### 2. Staging Layer (`adworks_staging`)

* **`products`**: Joins raw product lookups with subcategories and categories to produce clean category mappings.
* **`customers`**: Cleanses demographic details, standardizing flags (`HomeOwner`, `Gender`, `MaritalStatus`) into human-readable strings.
* **`transactions`**: Unifies annual sales logs (2020, 2021, 2022) via CTE (`WITH trans AS ...`), integrates return quantities via `COALESCE`, and links territory details.

### 3. Analytics Layer (`adworks_analytics.sales_data`)

The unified analytics table joins `transactions`, `products`, and `customers` to compute key financial metrics:
* **Revenue**: $\text{ProductPrice} \times \text{OrderQuantity}$
* **Total Cost**: $\text{ProductCost} \times \text{OrderQuantity}$
* **Profit**: $\text{Revenue} - \text{TotalCost}$

---

## 🚀 SQL Implementation Script

Run the following SQL script in MySQL Workbench to execute the entire transformation workflow:

```sql
-- ==========================================
-- 1. DATABASE & USER SETUP (Run as Root)
-- ==========================================
CREATE DATABASE IF NOT EXISTS adworks_raw;
CREATE DATABASE IF NOT EXISTS adworks_staging;
CREATE DATABASE IF NOT EXISTS adworks_analytics;

CREATE USER IF NOT EXISTS 'anidu'@'localhost' IDENTIFIED BY '123456';
CREATE USER IF NOT EXISTS 'yakubu'@'localhost' IDENTIFIED BY '123456';

GRANT ALL PRIVILEGES ON adworks_raw.* TO 'anidu'@'localhost';
GRANT ALL PRIVILEGES ON adworks_staging.* TO 'anidu'@'localhost';
GRANT ALL PRIVILEGES ON adworks_analytics.* TO 'anidu'@'localhost';

GRANT SELECT ON adworks_analytics.* TO 'yakubu'@'localhost';
FLUSH PRIVILEGES;


-- ==========================================
-- 2. STAGING TABLE: PRODUCTS
-- ==========================================
DROP TABLE IF EXISTS adworks_staging.products;

CREATE TABLE adworks_staging.products AS  
SELECT          
    pl.ProductKey,          
    pl.ProductName,          
    pl.ModelName,         
    pl.ProductColor,          
    pl.ProductSize,          
    pl.ProductStyle,          
    pl.ProductCost,          
    pl.ProductPrice,          
    psl.SubcategoryName,    
    pcl.CategoryName     
FROM adworks_raw.product_lookup pl  
INNER JOIN adworks_raw.product_subcategories_lookup psl          
    ON pl.ProductSubcategorykey = psl.ProductSubcategoryKey  
INNER JOIN adworks_raw.product_categories_lookup pcl          
    ON psl.ProductCategoryKey = pcl.ProductCategoryKey;


-- ==========================================
-- 3. STAGING TABLE: CUSTOMERS
-- ==========================================
DROP TABLE IF EXISTS adworks_staging.customers;

CREATE TABLE adworks_staging.customers AS 
SELECT          
    CustomerKey,     
    CASE                  
        WHEN MaritalStatus = 'M' THEN 'Married'                  
        WHEN MaritalStatus = 'S' THEN 'Single'          
    END AS MaritalStatus,     
    CASE                  
        WHEN Gender = 'M' THEN 'Male'                  
        WHEN Gender = 'F' THEN 'Female'                  
        ELSE 'Unknown'          
    END AS Gender,     
    AnnualIncome,          
    TotalChildren,          
    EducationLevel,          
    Occupation,     
    CASE                  
        WHEN HomeOwner = 'Y' THEN 'Yes'                  
        ELSE 'No'          
    END AS Homeowner 
FROM adworks_raw.customer_lookup 
WHERE MaritalStatus IS NOT NULL;


-- ==========================================
-- 4. STAGING TABLE: TRANSACTIONS
-- ==========================================
DROP TABLE IF EXISTS adworks_staging.transactions;

CREATE TABLE adworks_staging.transactions AS    
WITH trans AS (                   
    SELECT * FROM adworks_raw.sales_data_2020                   
    UNION ALL                   
    SELECT * FROM adworks_raw.sales_data_2021                   
    UNION ALL                   
    SELECT * FROM adworks_raw.sales_data_2022   
)   
SELECT               
    trans.OrderDate,                    
    trans.StockDate,                    
    trans.ProductKey,                    
    trans.CustomerKey,                    
    tl.Continent,                    
    tl.Region,                    
    tl.Country,                    
    trans.OrderLineItem,                    
    CAST(trans.OrderQuantity AS UNSIGNED) AS OrderQuantity,                   
    COALESCE(CAST(rd.ReturnQuantity AS UNSIGNED), 0) AS ReturnQuantity   
FROM adworks_raw.calendar_lookup cl   
LEFT JOIN trans                    
    ON trans.OrderDate = cl.Date   
LEFT JOIN adworks_raw.territory_lookup tl                    
    ON trans.TerritoryKey = tl.SalesTerritoryKey  
LEFT JOIN adworks_raw.returns_data rd                    
    ON rd.ReturnDate = cl.Date                
    AND rd.ProductKey = trans.ProductKey;


-- ==========================================
-- 5. FINAL ANALYTICS TABLE: SALES_DATA
-- ==========================================
DROP TABLE IF EXISTS adworks_analytics.sales_data;

CREATE TABLE IF NOT EXISTS adworks_analytics.sales_data AS 
SELECT          
    sd.ProductKey,     
    sd.ProductName,     
    sd.ModelName,     
    sd.ProductColor,     
    sd.ProductSize,     
    sd.ProductStyle,     
    sd.ProductCost,     
    sd.ProductPrice,     
    sd.SubcategoryName,     
    sd.CategoryName,     
    sd.OrderDate,     
    sd.StockDate,     
    sd.Continent,     
    sd.Region,     
    sd.Country,     
    sd.OrderLineItem,     
    sd.Quantity,     
    sd.CustomerKey,     
    sd.MaritalStatus,     
    sd.Gender,     
    sd.AnnualIncome,     
    sd.TotalChildren,     
    sd.EducationLevel,     
    sd.Occupation,     
    sd.Homeowner,     
    sd.Revenue,     
    sd.TotalCost,     
    ROUND(sd.Revenue - sd.TotalCost, 2) AS Profit 
FROM (         
    SELECT                  
        p.ProductKey,                  
        p.ProductName,                  
        p.ModelName,                  
        COALESCE(p.ProductColor, 'Unknown') AS ProductColor,                  
        p.ProductSize,                  
        p.ProductStyle,                  
        p.ProductCost,                  
        p.ProductPrice,                  
        p.SubcategoryName,                  
        p.CategoryName,                  
        t.OrderDate,                  
        t.StockDate,                  
        t.Continent,                  
        t.Region,                  
        t.Country,                  
        t.OrderLineItem,                  
        t.OrderQuantity AS Quantity,                  
        c.CustomerKey,                  
        c.MaritalStatus,                  
        c.Gender,                  
        c.AnnualIncome,                  
        c.TotalChildren,                  
        c.EducationLevel,                  
        c.Occupation,                  
        c.Homeowner,         
        ROUND(p.ProductPrice * t.OrderQuantity, 2) AS Revenue,         
        ROUND(p.ProductCost * t.OrderQuantity, 2) AS TotalCost          
    FROM adworks_staging.transactions t          
    INNER JOIN adworks_staging.products p                  
        ON t.ProductKey = p.ProductKey          
    INNER JOIN adworks_staging.customers c                  
        ON c.CustomerKey = t.CustomerKey
) sd;
```

---

## 🔌 Connecting to Power BI via MySQL ODBC Connector

1. Install the official **MySQL Connector/ODBC** driver (64-bit).
2. Configure a new User DSN using Windows **ODBC Data Sources (64-bit)**:
   * **Server**: `localhost` | **Port**: `3306`
   * **User**: `yakubu` | **Password**: `123456`
   * **Database**: `adworks_analytics`
3. Open Power BI Desktop $\rightarrow$ **Get Data** $\rightarrow$ **ODBC** $\rightarrow$ Select your created DSN to load `adworks_analytics.sales_data`.

---

## 📈 Key Metrics & Results

* **Total Processed Transactions**: ~56,950 records
* **Unique Customers**: ~18,148 records
* **Analytics Fields Available**: Product Category/Subcategory, Financial Metrics (Revenue, Cost, Profit), Geography (Continent, Region, Country), Customer Demographics.
