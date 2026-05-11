USE OnlineShop_STG;

SELECT COUNT(*) AS CustomersCount FROM Customer_STG;
SELECT COUNT(*) AS SuppliersCount FROM Supplier_STG;
SELECT COUNT(*) AS ProductsCount FROM Product_STG;
SELECT COUNT(*) AS OrdersCount FROM Order_STG;
SELECT COUNT(*) AS OrderItemsCount FROM OrderItem_STG;
SELECT COUNT(*) AS PaymentsCount FROM Payment_STG;
SELECT COUNT(*) AS ShipmentsCount FROM Shipment_STG;
SELECT COUNT(*) AS ReviewsCount FROM Review_STG;