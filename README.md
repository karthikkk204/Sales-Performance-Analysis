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
