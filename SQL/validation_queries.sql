USE AdventureWorksDW2025;

-- 1. Row counts
SELECT 'DimCustomer' AS TableName, COUNT(*) AS Rows FROM DimCustomer
UNION ALL SELECT 'DimDate', COUNT(*) FROM DimDate
UNION ALL SELECT 'DimGeography', COUNT(*) FROM DimGeography
UNION ALL SELECT 'DimProduct', COUNT(*) FROM DimProduct
UNION ALL SELECT 'FactInternetSales', COUNT(*) FROM FactInternetSales;

-- 2. No NULL / blank keys in the fact table
SELECT COUNT(*) AS NullKeys
FROM FactInternetSales
WHERE CustomerKey IS NULL OR ProductKey IS NULL
   OR OrderDateKey IS NULL OR SalesOrderNumber IS NULL;

-- 3. No duplicate keys in dimensions
SELECT CustomerKey, COUNT(*) AS n FROM DimCustomer  GROUP BY CustomerKey  HAVING COUNT(*) > 1;
SELECT ProductKey,  COUNT(*) AS n FROM DimProduct   GROUP BY ProductKey   HAVING COUNT(*) > 1;
SELECT GeographyKey,COUNT(*) AS n FROM DimGeography GROUP BY GeographyKey HAVING COUNT(*) > 1;

-- 4. Orphan keys: sales rows with no matching dimension row 
SELECT COUNT(*) AS OrphanCustomers FROM FactInternetSales f
LEFT JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey WHERE c.CustomerKey IS NULL;

SELECT COUNT(*) AS OrphanProducts FROM FactInternetSales f
LEFT JOIN DimProduct p ON f.ProductKey = p.ProductKey WHERE p.ProductKey IS NULL;

SELECT COUNT(*) AS CustomersWithoutGeography FROM DimCustomer c
LEFT JOIN DimGeography g ON c.GeographyKey = g.GeographyKey WHERE g.GeographyKey IS NULL;

-- 5. Date range and validity
SELECT MIN(OrderDate) AS FirstOrder, MAX(OrderDate) AS LastOrder FROM FactInternetSales;
SELECT COUNT(*) AS BadDates FROM FactInternetSales WHERE OrderDate IS NULL;

-- 6. Sales amount sanity (expecting no NULLs or negatives)
SELECT COUNT(*) AS BadAmounts FROM FactInternetSales
WHERE SalesAmount IS NULL OR SalesAmount < 0;

-- 7. Customer attributes: NULL birth dates, odd ages
SELECT COUNT(*) AS NullBirthDates FROM DimCustomer WHERE BirthDate IS NULL;
SELECT MIN(BirthDate) AS Oldest, MAX(BirthDate) AS Youngest FROM DimCustomer;

-- 8. Reference totals to match Power BI later
SELECT COUNT(DISTINCT CustomerKey)      AS CustomersWhoBought,
       COUNT(DISTINCT SalesOrderNumber) AS TotalOrders,
       SUM(SalesAmount)                 AS TotalSales
FROM FactInternetSales;

--9. Check the Frequency distribution

WITH rfm AS (
    SELECT CustomerKey,
           DATEDIFF(DAY, MAX(OrderDate), '2014-01-29') AS Recency,
           COUNT(DISTINCT SalesOrderNumber)            AS Frequency,
           SUM(SalesAmount)                            AS Monetary
    FROM FactInternetSales
    GROUP BY CustomerKey
)
SELECT Frequency, COUNT(*) AS Customers
FROM rfm
GROUP BY Frequency
ORDER BY Frequency;


--10. Get the raw values and thresholds

WITH rfm AS (
    SELECT CustomerKey,
           DATEDIFF(DAY, MAX(OrderDate), '2014-01-29') AS Recency,
           COUNT(DISTINCT SalesOrderNumber)            AS Frequency,
           SUM(SalesAmount)                            AS Monetary
    FROM FactInternetSales
    GROUP BY CustomerKey
)
-- Customer values
SELECT * FROM rfm WHERE CustomerKey = 11000;

-- Thresholds (same method as DAX PERCENTILE.INC)
WITH rfm AS (
    SELECT CustomerKey,
           DATEDIFF(DAY, MAX(OrderDate), '2014-01-29') AS Recency,
           SUM(SalesAmount)                            AS Monetary
    FROM FactInternetSales
    GROUP BY CustomerKey
)
SELECT DISTINCT
    PERCENTILE_CONT(0.2) WITHIN GROUP (ORDER BY Recency)  OVER () AS R_p20,
    PERCENTILE_CONT(0.4) WITHIN GROUP (ORDER BY Recency)  OVER () AS R_p40,
    PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY Recency)  OVER () AS R_p60,
    PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY Recency)  OVER () AS R_p80,
    PERCENTILE_CONT(0.2) WITHIN GROUP (ORDER BY Monetary) OVER () AS M_p20,
    PERCENTILE_CONT(0.4) WITHIN GROUP (ORDER BY Monetary) OVER () AS M_p40,
    PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY Monetary) OVER () AS M_p60,
    PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY Monetary) OVER () AS M_p80
FROM rfm;


--11. Determin the accuraccy of the map
USE AdventureWorksDW2025;

SELECT SUM(f.SalesAmount) AS Sales,
       COUNT(DISTINCT f.CustomerKey) AS Customers,
       COUNT(DISTINCT f.SalesOrderNumber) AS Orders
FROM FactInternetSales f
JOIN DimCustomer c  ON f.CustomerKey = c.CustomerKey
JOIN DimGeography g ON c.GeographyKey = g.GeographyKey
WHERE g.EnglishCountryRegionName = 'Australia';