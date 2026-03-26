 -- Project: Superstore Sales Analysis
-- Objective: Identify profit leakage and optimize discount strategy
-- Author: Bhuvaneshwari.S

CREATE DATABASE superstore_db ;

use superstore_db ;


-- CREATING TABLE SALES_TRANSACTIONS
CREATE TABLE sales_transactions (
transactionID INT Primary Key,
OrderID VARCHAR (20),
OrderDate DATE,
ShipDate DATE,
ShipMode VARCHAR (50),
CustomerID varchar (20),
CustomerName VARCHAR (100),
Segment VARCHAR (50),
Country VARCHAR (50),
City VARCHAR (50),
State VARCHAR (50),
PostalCode VARCHAR (20),
Region VARCHAR (50),
ProductID VARCHAR (20),
Category VARCHAR (50),
Sub_Category VARCHAR (50),
ProductName VARCHAR (250),
Sales DECIMAL(15,4),
Quantity INT,
Discount DECIMAL(10,4),
Profit DECIMAL(15,4)
) ;

-- importing data from .csv using LOAD DATA INFILE 
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/superstore.csv'
INTO TABLE sales_transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@transactionID, @OrderID, @OrderDate, @ShipDate, @ShipMode,
 @CustomerID, @CustomerName, @Segment, @Country, @City,
 @State, @PostalCode, @Region, @ProductID, @Category,
 @SubCategory, @ProductName, @Sales, @Quantity, @Discount, @Profit)
SET
transactionID = @transactionID,
OrderID = @OrderID,
OrderDate = STR_TO_DATE(@OrderDate, '%d-%m-%Y'),
ShipDate = STR_TO_DATE(@ShipDate, '%d-%m-%Y'),
ShipMode = @ShipMode,
CustomerID = @CustomerID,
CustomerName = @CustomerName,
Segment = @Segment,
Country = @Country,
City = @City,
State = @State,
PostalCode = @PostalCode,
Region = @Region,
ProductID = @ProductID,
Category = @Category,
Sub_Category = @SubCategory,
ProductName = @ProductName,
Sales = @Sales,
Quantity = @Quantity,
Discount = @Discount,
Profit = @Profit;


CREATE TABLE Customers (
    CustomerID VARCHAR(20) PRIMARY KEY,
    CustomerName VARCHAR(100),
    Segment VARCHAR(50)
);

-- inserting data into customers table
INSERT INTO Customers ( CustomerID, CustomerName, Segment )
SELECT DISTINCT CustomerID, CustomerName, Segment
FROM sales_transactions ;


SELECT ProductID, COUNT(*)
FROM Sales_transactions
GROUP BY ProductID
HAVING COUNT(*) > 1 ; -- more than 1000 rows were found with 2, 4, 7, 12 counts

-- as i found the productID is not uniquely identifying the products due to incosistent product name values, i introduced 
-- surrogate key "Product Key" 

CREATE TABLE Products (
ProductKey int auto_increment primary KEY,
ProductID varchar(20) ,
ProductName VARCHAR(150) ,
Category varchar(50) ,
Sub_Category VARCHAR(50)
) ;

INSERT INTO Products ( ProductID, ProductName,Category,Sub_Category)
SELECT distinct ProductID, ProductName,Category,Sub_Category
FROM sales_transactions ; 

-- Creating table location
CREATE TABLE Location  (
LocationID INT auto_increment PRIMARY KEY,
Country varchar(50),
State varchar(50),
City varchar(50),
PostalCode varchar(50),
Region varchar(50)
) ;

-- -- INSERT DATA INTO Location Table
INSERT INTO Location (Country,State,City, PostalCode,Region  )
SELECT DISTINCT Country,State,City, PostalCode,Region
FROM sales_transactions ;

-- creating Orders table
CREATE TABLE Orders (
    OrderID VARCHAR(20) PRIMARY KEY,
    OrderDate DATE,
    ShipDate DATE,
    ShipMode VARCHAR(50),
    CustomerID VARCHAR(20),
    LocationID INT,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    FOREIGN KEY (LocationID) REFERENCES Location(LocationID)
);

-- -- INSERT DATA INTO Orders Table , since locationID is not in sales_transaction table so i joined it with location table
INSERT INTO Orders (OrderID, OrderDate, ShipDate, ShipMode, CustomerID, LocationID )
select DISTINCT S.OrderID, S.OrderDate, S.ShipDate, S.ShipMode, S.CustomerID, L.LocationID 
from sales_transactions AS S
JOIN Location as L
on S.Country = L.Country
AND S.State = L.State
AND S.City = L.City
and S.PostalCode = L.PostalCode
AND S.Region = L.Region;


-- createing order details table
CREATE TABLE Order_Details (
    OrderDetailID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID VARCHAR(20),
    ProductKey int,
    Sales DECIMAL(15,4),
    Quantity INT,
    Discount DECIMAL(10,4),
    Profit DECIMAL(15,4),
    FOREIGN KEY (ProductKey) REFERENCES Products(ProductKey),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID)
);

-- inserting data to Order_Details 
INSERT INTO Order_Details (OrderID, ProductKey, Sales, Quantity, Discount, Profit)
SELECT s.OrderID, p.ProductKey, s.Sales, s.Quantity, s.Discount, s.Profit
FROM sales_transactions as s
JOIN Products
  ON s.ProductID = p.ProductID
 AND s.ProductName = p.ProductName;



-- identifing annual profits 
SELECT 
YEAR(O.OrderDate) as year,
ROUND(SUM(od.Sales),2) as annual_sales,
ROUND(SUM(od.Profit),2) as annual_profits
FROM Order_Details as od
join orders as o
on o.OrderID = od.OrderID
GROUP BY year(o.OrderDate) 
ORDER BY year ;
-- The analysis indicates a steady increase in both sales revenue and profitability over the years

-- analysing the profit effeciency
SELECT 
YEAR(O.OrderDate) as year,
ROUND(SUM(od.Profit)/SUM(od.Sales)*100 , 2) as profit_margin_percent
FROM Order_Details as od
join orders as o
on o.OrderID = od.OrderID
GROUP BY year(o.OrderDate) 
ORDER BY year ;
-- Although profit was strong in 2017, profit efficiency declined compared to the previous year.


-- analysing which category and sub_ category generating more loss
SELECT 
    p.Category, p.Sub_Category,
    COUNT(O.OrderDate) as total_orders,
    ROUND(SUM(od.Sales),2) AS total_sales,
    ROUND(SUM(od.Profit),2) AS total_profit,
    ROUND(SUM(od.Profit)/SUM(od.Sales)*100,2) AS margin
FROM Order_Details od
JOIN Orders o ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductKey = p.ProductKey
WHERE YEAR(o.OrderDate) = 2017
GROUP BY p.Category, p.Sub_Category
ORDER BY total_profit ;
-- category furniture and in that tables are causing more loss in the year 2017


-- Finding the cause of losses in each sub-category by analyzing discount levels using a CASE statement.
SELECT 
CASE 
	WHEN od.Discount = 0 THEN 'No Discount'
	WHEN od.Discount <= 0.2 THEN 'Medium Discount'
	WHEN od.Discount <= 0.5 THEN 'high Discount'
	ELSE 'very High Discount'
    END AS discount_level,
    ROUND(SUM(od.Sales),2) AS total_sales,
    ROUND(SUM(od.Profit),2) AS total_profit
FROM Order_Details od
JOIN Orders o ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductKey = p.ProductKey
WHERE YEAR(o.OrderDate) = 2017
AND p.Sub_Category = 'Tables'
GROUP BY discount_level
ORDER BY total_sales DESC;
-- the loss in the table sub category in 2017 is mainly driven by medium discount(20 to 50%) . while discounts increases sales,
-- they significantly reduce margins and lead to negative profitability. in contrast , orders without discounts remain profitable.

 
-- analyzing the cities which are generating only loss in the table sub category using CTE
with city_analysis as (
SELECT 
    l.City,
    ROUND(SUM(od.Sales),2) AS total_sales,
    ROUND(SUM(od.Profit),2) AS total_profit,
     ROUND(AVG(od.discount),2) AS avg_discount
FROM Order_Details od
JOIN Orders o ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductKey = p.ProductKey
JOIN Location l ON o.LocationID = l.LocationID
join customers c ON c.CustomerID = o.CustomerID
WHERE YEAR(o.OrderDate) = 2017
AND p.Sub_Category = 'Tables'
GROUP BY l.City)

select *
from city_analysis
where total_profit < 0
order by total_profit ;
-- chicago,Philadelphia,Knoxville are the top 3 cities generating most losses with the huge discount rate


-- identifing customers who are getting high discount
select
	c.customerName,
	c.Segment,
    l.City, 
    ROUND(SUM(od.Sales),2) AS total_sales,
    ROUND(AVG(od.Discount),2) AS avg_discount,
    ROUND(SUM(od.Profit),2) AS total_profit
FROM Order_Details od
JOIN Orders o ON od.OrderID = o.OrderID
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Products p ON od.ProductKey = p.ProductKey
JOIN Location l ON o.LocationID = l.LocationID
WHERE YEAR(o.OrderDate) = 2017
AND p.Sub_Category = 'Tables'
AND City in ('Knoxville' , 'Chicago' , 'Philadelphia')
and segment = 'Home Office'
GROUP BY c.customerName, l.City, c.Segment
ORDER BY total_profit asc;
-- identified the top customers reciving high discount

-- Identifying which segment is generating losses in specific cities.
select
	c.Segment,
    ROUND(SUM(od.Sales),2) AS total_sales,
    ROUND(AVG(od.Discount),2) AS avg_discount,
    ROUND(SUM(od.Profit),2) AS total_profit,
    ROUND(SUM(profit) / SUM(Sales) * 100, 2) as profit_margin
FROM Order_Details od
JOIN Orders o ON od.OrderID = o.OrderID
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Products p ON od.ProductKey = p.ProductKey
JOIN Location l ON o.LocationID = l.LocationID
WHERE YEAR(o.OrderDate) = 2017
AND p.Sub_Category = 'Tables'
AND City in ('Knoxville' , 'Chicago' , 'Philadelphia')
GROUP BY c.Segment
ORDER BY total_profit asc;
-- as a regional analysis
-- in home office segment the there is more loss as-2093 and profit margin is -38% but
-- in consumer segment the sales and profit was less comparing to home office  profit margin is very low as-60%


-- analysing how many orders are made by each customer in home office segment for the table sub category
SELECT 
    c.customerID, c.CustomerName,
    COUNT(DISTINCT o.OrderID) AS total_orders,
    ROUND(SUM(od.Sales),2) AS total_sales,
    ROUND(SUM(od.Profit),2) AS total_profit,
	ROUND(AVG(od.Discount),2) as avg_discount
FROM Order_Details od
JOIN Orders o 
    ON od.OrderID = o.OrderID
JOIN Customers c 
    ON o.CustomerID = c.CustomerID
JOIN Products p 
    ON od.ProductKey = p.ProductKey
JOIN Location l
	on l.locationID = O.locationID
WHERE c.Segment = 'Home Office'
AND p.Sub_Category = 'Tables'
GROUP BY C.customerID, c.CustomerName 
HAVING SUM(od.Profit) < 0
ORDER BY total_profit asc
limit 5 ;
-- “The losses in the Tables sub-category are largely driven by a small number of high-value orders
-- where discounts exceed 35–50%. In several cases, a single heavily discounted order resulted in substantial losses


-- exactly which product is making the more loss in table sub category
SELECT 
    p.ProductName,
    COUNT(DISTINCT o.OrderID) AS total_orders,
    ROUND(SUM(od.Sales),2) AS total_sales,
    ROUND(SUM(od.Profit),2) AS total_profit,
    ROUND(AVG(od.Discount),2) AS avg_discount
FROM Order_Details od
JOIN Orders o 
    ON od.OrderID = o.OrderID
JOIN Products p 
    ON od.ProductKey = p.ProductKey
WHERE p.Sub_Category = 'Tables'
AND YEAR(o.OrderDate) = 2017
GROUP BY p.ProductName
HAVING SUM(od.Profit) < 0
ORDER BY total_profit ASC
LIMIT 10;
-- found some products on table sub_category which generates sales revenue but due to the discount it couldnt make the profit so
-- This suggests a need for better pricing and discount control to improve profit margins


-- analysing how profit would change if the maximum discounts were fixed to 30% 
-- while keeping other prices unchanged using CTE and case
WITH pricing_data AS (
    SELECT
        o.OrderDate,
        od.Sales,
        od.Profit,
        od.Discount,
        (od.Sales - od.Profit) AS cost,
        od.Sales / (1 - od.Discount) AS original_price
    FROM order_details od
    JOIN orders o
        ON od.OrderID = o.OrderID
    WHERE YEAR(o.OrderDate) = 2017
)

SELECT
ROUND(SUM(Profit),2) AS current_profit,
ROUND(
SUM(CASE
	WHEN Discount > 0.30
	THEN (original_price * (1 - 0.30)) - cost
	ELSE Profit
END),2) AS estimated_profit,

ROUND(
SUM(CASE
	WHEN Discount > 0.30
	THEN (original_price * (1 - 0.30)) - cost
	ELSE Profit
END) - SUM(Profit)
,2) AS profit_difference
FROM pricing_data;

-- Assuming the product cost remains constant, the analysis indicates that 
-- this strategy could increase total profit by approximately 50K compared to the current pricing structure.


-- Let us go through once which category and sub-category generate the highest profit.
SELECT 
    p.Category, p.Sub_Category,
    COUNT(O.OrderDate) as total_orders,
    ROUND(SUM(od.Sales),2) AS total_sales,
    ROUND(SUM(od.Profit),2) AS total_profit,
    ROUND(SUM(od.Profit)/SUM(od.Sales)*100,2) AS margin,
    ROUND(AVG(Discount)*100, 2) as avg_dis
FROM Order_Details od
JOIN Orders o ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductKey = p.ProductKey
WHERE YEAR(o.OrderDate) = 2017
GROUP BY p.Category, p.Sub_Category
ORDER BY total_profit DESC ;
-- Copiers are the most profitable sub-category in Technology.
-- High profit efficiency, generating strong profits even with fewer orders.
-- Accessories and Phones generate stable profits due to higher order volumes.
-- discount shoul idealy below 20% to retain profit effeciency



