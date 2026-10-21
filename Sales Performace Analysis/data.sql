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
    
   

SELECT COUNT(*) AS total_matches
FROM adworks_staging.transactions t
INNER JOIN adworks_staging.products p ON t.ProductKey = p.ProductKey
INNER JOIN adworks_staging.customers c ON c.CustomerKey = t.CustomerKey;

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
        t.OrderQuantity AS Quantity, -- Fixed from t.Quantity to t.OrderQuantity                                   
        c.CustomerKey,                                   
        c.MaritalStatus,                                   
        c.Gender,                                   
        c.AnnualIncome,                                   
        c.TotalChildren,                                   
        c.EducationLevel,                                   
        c.Occupation,                                   
        c.Homeowner,                          
        ROUND(p.ProductPrice * t.OrderQuantity, 2) AS Revenue, -- Fixed to t.OrderQuantity                          
        ROUND(p.ProductCost * t.OrderQuantity, 2) AS TotalCost   -- Fixed to t.OrderQuantity                   
    FROM adworks_staging.transactions t                   
    INNER JOIN adworks_staging.products p                                   
        ON t.ProductKey = p.ProductKey                   
    INNER JOIN adworks_staging.customers c                                   
        ON c.CustomerKey = t.CustomerKey 
) sd;