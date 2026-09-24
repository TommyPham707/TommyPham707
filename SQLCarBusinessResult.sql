-- Selecting top 1000 of each data type

SELECT TOP (1000) [Company_Names]
      ,[Cars_Names]
      ,[Engines]
      ,[CC_Battery_Capacity]
      ,[Horse_Power_Final]
      ,[Total_Speed]
      ,[Performance_0_100_KM_H]
      ,[Car_Prices_Final]
      ,[Fuel_Types]
      ,[Seats]
      ,[Torque_Final]
  FROM [CarAnalysisDB].[dbo].[Cars]


-- Showing All Ferrari cars and their model name with their prices
SELECT Company_Names, Cars_Names, Car_Prices_Final
FROM Cars
WHERE Company_Names = 'Ferrari';

-- Selecting company name with their car names with their horse power where their car prices are under 30000
SELECT Company_Names, Cars_names, Horse_Power_Final, Car_Prices_Final
FROM Cars
WHERE Car_Prices_Final < 30000;

-- Shows Company cars where prices are under 30k and are electric
SELECT Company_Names, Cars_names, Horse_Power_Final, Car_Prices_Final
FROM Cars
WHERE Car_Prices_Final < 30000 AND Fuel_Types= 'Electric';

-- How many electric cars are in the dataset, and what's their average price?
SELECT COUNT(*) AS ElectricCarCount, AVG(Car_Prices_Final) AS AvgElectricPrice
FROM Cars
WHERE Fuel_Types = 'Electric';

-- Check for potential outliers skewing the electric car average price
SELECT Company_Names, Cars_Names, Car_Prices_Final
FROM Cars
WHERE Fuel_Types = 'Electric'
ORDER BY Car_Prices_Final DESC;

-- Average price and count of cars per fuel type
SELECT Fuel_Types, COUNT(*) AS CarCount, AVG(Car_Prices_Final) AS AvgPrice
FROM Cars
GROUP BY Fuel_Types
ORDER BY AvgPrice DESC;

-- Investigating what's driving the high average price for Plug-in Hybrid
SELECT Company_Names, Cars_Names, Car_Prices_Final
FROM Cars
WHERE Fuel_Types = 'Plug-in Hybrid'
ORDER BY Car_Prices_Final DESC;

-- Average price per fuel type, excluding categories with fewer than 10 cars (unreliable sample size)
SELECT Fuel_Types, COUNT(*) AS CarCount, AVG(Car_Prices_Final) AS AvgPrice
FROM Cars
GROUP BY Fuel_Types
Having COUNT(*) >= 10
ORDER BY AvgPrice DESC;


-- Creating a lookup table of car brands with country of origin and founding year
CREATE TABLE Brands (
    Company_Names NVARCHAR(50) PRIMARY KEY,
    Country NVARCHAR(50),
    FoundedYear INT
);

-- Populating the Brands table with sample data
INSERT INTO Brands (Company_Names, Country, FoundedYear) VALUES
('Ferrari', 'Italy', 1939),
('Lamborghini', 'Italy', 1963),
('Rolls Royce', 'United Kingdom', 1904),
('Aston Martin', 'United Kingdom', 1913),
('Bugatti', 'France', 1909),
('Toyota', 'Japan', 1937),
('Nissan', 'Japan', 1933),
('Honda', 'Japan', 1948),
('Bmw', 'Germany', 1916),
('Mercedes', 'Germany', 1926),
('Volkswagen', 'Germany', 1937),
('Ford', 'United States', 1903),
('Chevrolet', 'United States', 1911),
('Tesla', 'United States', 2003),
('Kia', 'South Korea', 1944);

SELECT * FROM Brands;

-- Joining Cars with Brands to see country of origin and founding year alongside car details (INNER JOIN), Only shows results where both tables have matching results
SELECT c.Company_Names, c.Cars_Names, c.Car_Prices_Final, b.Country, b.FoundedYear
FROM Cars c
INNER JOIN Brands b ON c.Company_Names = b.Company_Names;

-- Joining Cars with Brands using LEFT JOIN to keep all cars, even those without a brand match
SELECT c.Company_Names, c.Cars_Names, c.Car_Prices_Final, b.Country, b.FoundedYear
FROM Cars c
LEFT JOIN Brands b ON c.Company_Names = b.Company_Names;

-- The overall average of all the cars in the dataset
SELECT AVG(Car_Prices_Final) AS OverallAvgPrice FROM Cars;

-- Cars priced above the overall average price
SELECT Company_Names, Cars_Names, Car_Prices_Final
FROM Cars
WHERE Car_Prices_Final > (
    SELECT AVG(Car_Prices_Final) FROM Cars
)
ORDER BY Car_Prices_Final DESC;

-- Cars priced above the overall average price, using a CTE instead of a subquery
WITH AvgPriceCTE AS (
    SELECT AVG(Car_Prices_Final) AS OverallAvgPrice
    FROM Cars
)
SELECT c.Company_Names, c.Cars_Names, c.Car_Prices_Final
FROM Cars c, AvgPriceCTE
WHERE c.Car_Prices_Final > AvgPriceCTE.OverallAvgPrice
ORDER BY c.Car_Prices_Final DESC;

-- Ranking cars by price within each brand
SELECT Company_Names, Cars_Names, Car_Prices_Final,
       RANK() OVER (PARTITION BY Company_Names ORDER BY Car_Prices_Final DESC) AS PriceRank
FROM Cars;

-- Comparing RANK vs ROW_NUMBER side by side
SELECT Company_Names, Cars_Names, Car_Prices_Final,
       RANK() OVER (PARTITION BY Company_Names ORDER BY Car_Prices_Final DESC) AS PriceRank,
       ROW_NUMBER() OVER (PARTITION BY Company_Names ORDER BY Car_Prices_Final DESC) AS RowNum
FROM Cars
WHERE Company_Names = 'Rolls Royce'
ORDER BY RowNum;

-- Running total of car prices for Ferrari, ordered from cheapest to most expensive
SELECT Company_Names, Cars_Names, Car_Prices_Final,
       SUM(Car_Prices_Final) OVER (PARTITION BY Company_Names ORDER BY Car_Prices_Final ASC) AS RunningTotal
FROM Cars
WHERE Company_Names = 'Ferrari'
ORDER BY Car_Prices_Final ASC;


-- BUSINESS QUESTION 1 (Market Landscape): 
-- How does the market break down by fuel type, including count, average price, and average seats?
-- Excludes fuel types with fewer than 10 cars to avoid unreliable small-sample averages.
SELECT Fuel_Types, 
       COUNT(*) AS CarCount, 
       AVG(Car_Prices_Final) AS AvgPrice,
       AVG(CAST(Seats AS FLOAT)) AS AvgSeats
FROM Cars
GROUP BY Fuel_Types
HAVING COUNT(*) >= 10
ORDER BY CarCount DESC;


-- BUSINESS QUESTION 1 (Market Landscape) - Average and Median price per fuel type:
-- Median resists outlier skew better than Average, giving a more representative "typical" price per fuel type.
SELECT DISTINCT Fuel_Types,
       COUNT(*) OVER (PARTITION BY Fuel_Types) AS CarCount,
       AVG(Car_Prices_Final) OVER (PARTITION BY Fuel_Types) AS AvgPrice,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Car_Prices_Final) OVER (PARTITION BY Fuel_Types) AS MedianPrice,
       AVG(CAST(Seats AS FLOAT)) OVER (PARTITION BY Fuel_Types) AS AvgSeats
FROM Cars
WHERE Fuel_Types IN (
    SELECT Fuel_Types FROM Cars GROUP BY Fuel_Types HAVING COUNT(*) >= 10
)
ORDER BY CarCount DESC;

-- BUSINESS QUESTION 2 (Performance Benchmarking):
-- Identifies the single fastest (0-100) car per brand, using ROW_NUMBER to guarantee one result per brand.
WITH RankedByPerformance AS (
    SELECT Company_Names, Cars_Names, Horse_Power_Final, Total_Speed, Performance_0_100_KM_H,
           ROW_NUMBER() OVER (PARTITION BY Company_Names ORDER BY Performance_0_100_KM_H ASC) AS PerfRank
    FROM Cars
    WHERE Performance_0_100_KM_H IS NOT NULL
)
SELECT Company_Names, Cars_Names, Horse_Power_Final, Total_Speed, Performance_0_100_KM_H
FROM RankedByPerformance
WHERE PerfRank = 1
ORDER BY Performance_0_100_KM_H ASC;

-- BUSINESS QUESTION 3 (Price-to-Performance Value):
-- Calculates a simple horsepower-per-dollar ratio to find the best value cars.
-- Higher ratio = more horsepower for the money.
SELECT Company_Names, Cars_Names, Horse_Power_Final, Car_Prices_Final,
       Horse_Power_Final * 1000.0 / Car_Prices_Final AS HP_Per_1000Dollars
FROM Cars
WHERE Horse_Power_Final IS NOT NULL 
  AND Car_Prices_Final IS NOT NULL
  AND Car_Prices_Final > 0
ORDER BY HP_Per_1000Dollars DESC;

-- Manual check: raw Horsepower and Price side by side, sorted by best HP-per-dollar first
SELECT Company_Names, Cars_Names, Horse_Power_Final, Car_Prices_Final
FROM Cars
WHERE Horse_Power_Final IS NOT NULL 
  AND Car_Prices_Final IS NOT NULL
ORDER BY (Horse_Power_Final * 1000.0 / Car_Prices_Final) DESC;