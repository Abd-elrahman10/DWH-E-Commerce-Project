USE OnlineShop_Source;
GO

DECLARE @DatasetPath NVARCHAR(4000) = N'C:\IS-Level_3-Secound_Term\Data WareHouse\A2\DWH-E-Commerce-Project\Dataset\';
DECLARE @sql NVARCHAR(MAX);

-- Customer
SET IDENTITY_INSERT Customer ON;

SET @sql = N'
BULK INSERT Customer
FROM ''' + @DatasetPath + N'customers.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    KEEPIDENTITY,
    TABLOCK
);';

EXEC sp_executesql @sql;

SET IDENTITY_INSERT Customer OFF;


-- Supplier
SET IDENTITY_INSERT Supplier ON;

SET @sql = N'
BULK INSERT Supplier
FROM ''' + @DatasetPath + N'suppliers.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    KEEPIDENTITY,
    TABLOCK
);';

EXEC sp_executesql @sql;

SET IDENTITY_INSERT Supplier OFF;


-- Product
SET IDENTITY_INSERT Product ON;

SET @sql = N'
BULK INSERT Product
FROM ''' + @DatasetPath + N'products.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    KEEPIDENTITY,
    TABLOCK
);';

EXEC sp_executesql @sql;

SET IDENTITY_INSERT Product OFF;


-- Order: load first into temp table because order_date is dd/MM/yyyy
DROP TABLE IF EXISTS #OrderCSV;

CREATE TABLE #OrderCSV (
    order_id INT,
    order_date NVARCHAR(20),
    customer_id INT,
    total_price DECIMAL(18,2)
);

SET @sql = N'
BULK INSERT #OrderCSV
FROM ''' + @DatasetPath + N'orders.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    TABLOCK
);';

EXEC sp_executesql @sql;

SET IDENTITY_INSERT [Order] ON;

INSERT INTO [Order] (OrderID, [Order Date], CustomerID, [Total Price])
SELECT
    order_id,
    CONVERT(DATE, order_date, 103),
    customer_id,
    total_price
FROM #OrderCSV;

SET IDENTITY_INSERT [Order] OFF;


-- OrderItem
SET IDENTITY_INSERT OrderItem ON;

SET @sql = N'
BULK INSERT OrderItem
FROM ''' + @DatasetPath + N'order_items.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    KEEPIDENTITY,
    TABLOCK
);';

EXEC sp_executesql @sql;

SET IDENTITY_INSERT OrderItem OFF;


-- Payment CSV has payment_id, but source Payment table does not have PaymentID
DROP TABLE IF EXISTS #PaymentCSV;

CREATE TABLE #PaymentCSV (
    payment_id INT,
    order_id INT,
    payment_method NVARCHAR(50),
    amount DECIMAL(18,2),
    transaction_status NVARCHAR(50)
);

SET @sql = N'
BULK INSERT #PaymentCSV
FROM ''' + @DatasetPath + N'payment.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    TABLOCK
);';

EXEC sp_executesql @sql;

INSERT INTO Payment (OrderID, Payment_method, Amount, Transaction_status)
SELECT 
    order_id,
    payment_method,
    amount,
    transaction_status
FROM #PaymentCSV;


-- Shipment
SET IDENTITY_INSERT Shipment ON;

SET @sql = N'
BULK INSERT Shipment
FROM ''' + @DatasetPath + N'shipments.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    KEEPIDENTITY,
    TABLOCK
);';

EXEC sp_executesql @sql;

SET IDENTITY_INSERT Shipment OFF;


-- Review
SET IDENTITY_INSERT Review ON;

SET @sql = N'
BULK INSERT Review
FROM ''' + @DatasetPath + N'reviews.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    KEEPIDENTITY,
    TABLOCK
);';

EXEC sp_executesql @sql;

SET IDENTITY_INSERT Review OFF;


-- Check counts
SELECT COUNT(*) AS CustomersCount FROM Customer;
SELECT COUNT(*) AS SuppliersCount FROM Supplier;
SELECT COUNT(*) AS ProductsCount FROM Product;
SELECT COUNT(*) AS OrdersCount FROM [Order];
SELECT COUNT(*) AS OrderItemsCount FROM OrderItem;
SELECT COUNT(*) AS PaymentsCount FROM Payment;
SELECT COUNT(*) AS ShipmentsCount FROM Shipment;
SELECT COUNT(*) AS ReviewsCount FROM Review;