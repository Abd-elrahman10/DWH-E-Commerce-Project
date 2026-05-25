# Online Shop Data Warehouse Project

## Project Overview

This project implements a full end-to-end Data Warehouse solution for an Online Shop source system. The solution covers dimensional modeling, ETL pipeline development using SSIS, analytical querying, and interactive dashboard visualization using Power BI.

The source system is an OLTP database named **OnlineShop_Source** that tracks customers, products, suppliers, orders, payments, shipments, and product reviews. The goal is to transform this operational data into a structured data warehouse optimized for analytical reporting and business intelligence.

---



## Technology Stack

| Tool | Purpose |
|------|---------|
| Microsoft SQL Server 2022 | Source, Staging, and DWH databases |
| SQL Server Integration Services (SSIS) | ETL pipeline development |
| SQL Server Management Studio (SSMS) | Database management and query execution |
| Visual Studio 2022 | SSIS package development |
| Microsoft Power BI Desktop | Interactive dashboard and visualization |

---

## Project Architecture

```
OnlineShop_Source (OLTP)
        ↓
   SSIS Package 1
   (Source → Staging)
        ↓
OnlineShop_STG (Staging)
        ↓
   SSIS Package 2
   (Staging → DWH)
        ↓
OnlineShop_DWH (Data Warehouse)
        ↓
   Power BI Dashboard
```

---

## Source System — OnlineShop_Source

The source system contains the following tables:

| Table | Description |
|-------|-------------|
| Customer | Stores customer personal information |
| Supplier | Stores supplier details and contact information |
| Product | Stores product catalog with pricing and category |
| Order | Stores customer orders with dates and total price |
| OrderItem | Stores individual line items within each order |
| Payment | Stores payment method and transaction status per order |
| Shipment | Stores shipment details including carrier and delivery dates |
| Review | Stores customer product reviews and ratings |

---

## Staging Area — OnlineShop_STG

The staging area is a raw copy of the source system with no transformations applied. Each table mirrors its source counterpart with the suffix `_STG`.

| Staging Table | Source Table |
|---------------|-------------|
| Customer_STG | Customer |
| Supplier_STG | Supplier |
| Product_STG | Product |
| Order_STG | Order |
| OrderItem_STG | OrderItem |
| Payment_STG | Payment |
| Shipment_STG | Shipment |
| Review_STG | Review |

**Load Order (respecting foreign key constraints):**

1. Supplier_STG
2. Customer_STG
3. Product_STG
4. Order_STG
5. OrderItem_STG
6. Payment_STG
7. Shipment_STG
8. Review_STG

---

## Data Warehouse — OnlineShop_DWH

### Dimensional Model Type
Galaxy Schema (multiple fact tables sharing conformed dimensions)

---

### Dimension Tables

#### DimDate — Conformed 
Dates never change once created. Populated once with all dates from 2020 to 2030.

| Column | Data Type | Description |
|--------|-----------|-------------|
| DateKey | INT | Surrogate key in YYYYMMDD format |
| FullDate | DATE | Complete date value |
| Day | INT | Day number of the month |
| Month | INT | Month number |
| Year | INT | Year number |
| Month_Name | NVARCHAR(20) | Full month name |
| Quarter | INT | Quarter number (1–4) |

---

#### DimCustomer — Type 2 (Track History)
Customer address and contact details can change over time. Full history is preserved using SCD Type 2.

| Column | Data Type | Description |
|--------|-----------|-------------|
| CustomerKey | INT IDENTITY | Surrogate key |
| CustomerID | INT | Natural key from source |
| First_Name | NVARCHAR(10) | Customer first name |
| Last_Name | NVARCHAR(10) | Customer last name |
| Address | NVARCHAR(100) | Customer address |
| Email | NVARCHAR(70) | Customer email |
| Phone_Number | NVARCHAR(20) | Customer phone |
| Start_Date | DATE | Date record became active |
| End_Date | DATE | Date record was expired (NULL if current) |
| IsCurrent | BIT | 1 = current record, 0 = historical |

---

#### DimProduct — Type 2 (Track History)
Product prices and categories can change. Historical pricing is preserved to ensure sales records reflect the correct price at time of purchase.

| Column | Data Type | Description |
|--------|-----------|-------------|
| ProductKey | INT IDENTITY | Surrogate key |
| ProductID | INT | Natural key from source |
| Product_Name | NVARCHAR(100) | Product name |
| Category | NVARCHAR(100) | Product category |
| Price | DECIMAL(18,2) | Product price |
| Start_Date | DATE | Date record became active |
| End_Date | DATE | Date record was expired (NULL if current) |
| IsCurrent | BIT | 1 = current record, 0 = historical |

---

#### DimSupplier — Type 1 (Overwrite)
Supplier information is overwritten on change. No historical tracking required.

| Column | Data Type | Description |
|--------|-----------|-------------|
| SupplierKey | INT IDENTITY | Surrogate key |
| SupplierID | INT | Natural key from source |
| Supplier_Name | NVARCHAR(100) | Supplier company name |
| Contact_Name | NVARCHAR(100) | Contact person name |
| Address | NVARCHAR(100) | Supplier address |
| Phone_Number | NVARCHAR(20) | Supplier phone |
| Email | NVARCHAR(100) | Supplier email |

---

#### DimPayment — Type 1 (Overwrite)
Payment method and status are overwritten on change.

| Column | Data Type | Description |
|--------|-----------|-------------|
| PaymentKey | INT IDENTITY | Surrogate key |
| OrderID | INT | Natural key from source |
| Payment_Method | NVARCHAR(50) | Payment method used |
| Transaction_Status | NVARCHAR(50) | Completed, Pending, or Failed |

---

#### DimShipment — Type 1 (Overwrite)
Carrier and tracking information is overwritten on change.

| Column | Data Type | Description |
|--------|-----------|-------------|
| ShipmentKey | INT IDENTITY | Surrogate key |
| ShipmentID | INT | Natural key from source |
| Carrier | NVARCHAR(100) | Shipping carrier name |
| Tracking_Number | NVARCHAR(100) | Shipment tracking number |

---

#### DimJunkStatus — Junk 
A junk dimension combining shipment status flags. All combinations are pre-populated and never change.

| Column | Data Type | Description |
|--------|-----------|-------------|
| ShipmentStatusKey | INT IDENTITY | Surrogate key |
| Is_Delivered | INT | 1 = Delivered, 0 = Not Delivered |
| Is_Late | INT | 1 = Late, 0 = On Time |
| Late_Reason | NVARCHAR(100) | Reason for late delivery |

**Pre-populated combinations:**

| Is_Delivered | Is_Late | Late_Reason |
|---|---|---|
| 1 | 0 | N/A |
| 1 | 1 | Carrier Delay |
| 1 | 1 | Weather |
| 1 | 1 | Customs |
| 1 | 1 | Address Issue |
| 0 | 0 | N/A |
| 0 | 1 | Carrier Delay |
| 0 | 1 | Weather |
| 0 | 1 | Lost Package |

---

### Fact Tables

#### Fact_Sales — Transactional
**Grain:** One row per product line item within one customer order.

| Column | Data Type | Type | Description |
|--------|-----------|------|-------------|
| SalesKey | INT IDENTITY | PK | Surrogate key |
| CustomerKey | INT | FK | Links to DimCustomer |
| ProductKey | INT | FK | Links to DimProduct |
| SupplierKey | INT | FK | Links to DimSupplier |
| OrderDateKey | INT | FK | Links to DimDate |
| PaymentKey | INT | FK | Links to DimPayment |
| OrderID | INT | Degenerate | Order natural key |
| OrderItemID | INT | Degenerate | Order item natural key |
| Quantity | INT | Additive | Units ordered |
| Price_At_Purchase | DECIMAL(18,2) | Semi-additive | Price at time of purchase |
| Total_Amount | DECIMAL(18,2) | Additive | Quantity × Price |

---

#### Fact_Shipment — Accumulating Snapshot
**Grain:** One row per shipment tracking a single order from dispatch to delivery.

| Column | Data Type | Type | Description |
|--------|-----------|------|-------------|
| ShipmentFactKey | INT IDENTITY | PK | Surrogate key |
| CustomerKey | INT | FK | Links to DimCustomer |
| ShipmentDateKey | INT | FK | Links to DimDate (shipped) |
| DeliveryDateKey | INT | FK | Links to DimDate (delivered) |
| ShipmentKey | INT | FK | Links to DimShipment |
| ShipmentStatusKey | INT | FK | Links to DimJunkStatus |
| OrderID | INT | Degenerate | Order natural key |
| Delivery_Duration_Days | INT | Additive | Days from shipment to delivery |
| Shipment_Count | INT | Additive | Always 1, used for counting |

---

#### Fact_Review — Transactional
**Grain:** One row per customer review submitted for one product.

| Column | Data Type | Type | Description |
|--------|-----------|------|-------------|
| ReviewFactKey | INT IDENTITY | PK | Surrogate key |
| CustomerKey | INT | FK | Links to DimCustomer |
| ProductKey | INT | FK | Links to DimProduct |
| ReviewDateKey | INT | FK | Links to DimDate |
| ReviewID | INT | Degenerate | Review natural key |
| Rating | INT | Semi-additive | Rating 1–5, use AVG not SUM |

---

## ETL Pipeline — SSIS Packages

Two SSIS packages were built to load data from the source system into the data warehouse.

---

### Package 1 — ETL_Source_To_STG

**Purpose:** Extract raw data from the source OLTP database and load it into the staging area without any transformation.

**Control Flow:**

| Step | Task Type | Description |
|------|-----------|-------------|
| 1 | Execute SQL Task | Truncate all STG tables in correct order |
| 2 | Data Flow Task | Load Supplier_STG |
| 3 | Data Flow Task | Load Customer_STG |
| 4 | Data Flow Task | Load Product_STG |
| 5 | Data Flow Task | Load Order_STG |
| 6 | Data Flow Task | Load OrderItem_STG |
| 7 | Data Flow Task | Load Payment_STG |
| 8 | Data Flow Task | Load Shipment_STG |
| 9 | Data Flow Task | Load Review_STG |

**Data Flow Design (per table):**
```
OLE DB Source (OnlineShop_Source)
        ↓
OLE DB Destination (OnlineShop_STG)
```

---

### Package 2 — ETL_STG_To_DWH

**Purpose:** Transform and load data from the staging area into the data warehouse, applying SCD logic for Type 1 and Type 2 dimensions, surrogate key lookups, and derived measure calculations.

**Control Flow — Sequence Container 1 (Dimensions):**

| Step | Task | SCD Type | Logic |
|------|------|----------|-------|
| 1 | Execute SQL: Populate DimDate | Type 0 | CTE generates all dates 2020–2030 |
| 2 | Data Flow: Load DimSupplier | Type 1 | Lookup → Insert new / Update existing |
| 3 | Data Flow: Load DimCustomer | Type 2 | Lookup → Insert new / Expire old + Insert new version |
| 4 | Data Flow: Load DimProduct | Type 2 | Lookup → Insert new / Expire old + Insert new version |
| 5 | Data Flow: Load DimPayment | Type 1 | Lookup → Insert new / Update existing |
| 6 | Data Flow: Load DimShipment | Type 1 | Lookup → Insert new / Update existing |

**Control Flow — Sequence Container 2 (Facts):**

| Step | Task | Source Tables |
|------|------|--------------|
| 7 | Data Flow: Load Fact_Sales | OrderItem_STG + Order_STG + Payment_STG + Product_STG |
| 8 | Data Flow: Load Fact_Shipment | Shipment_STG + Order_STG |
| 9 | Data Flow: Load Fact_Review | Review_STG |

**Data Flow Design — Type 1 Dimension (DimSupplier example):**
```
OLE DB Source (STG)
        ↓
    Lookup (DimDWH)
        ↓               ↓
  No Match           Match Found
(New Record)       (Existing Record)
        ↓               ↓
OLE DB Destination  OLE DB Command
    (INSERT)           (UPDATE)
```

**Data Flow Design — Type 2 Dimension (DimCustomer example):**
```
OLE DB Source (STG)
        ↓
    Lookup (IsCurrent = 1)
        ↓                    ↓
   No Match              Match Found
 (New Customer)        (Check if Changed)
        ↓                    ↓
  Derived Column      Conditional Split
  (Start_Date,              ↓           ↓
   IsCurrent=1)         Changed      Not Changed
        ↓                  ↓              ↓
        ↓           OLE DB Command     Ignore
        ↓           (Expire old record:
        ↓            IsCurrent=0,
        ↓            End_Date=GETDATE())
        ↓                  ↓
        └──────→ OLE DB Destination
                  (INSERT new version)
```

**Data Flow Design — Fact Tables (Fact_Sales example):**
```
OLE DB Source (OrderItem_STG + Order_STG + Payment_STG)
        ↓
Lookup: CustomerID   → CustomerKey  (DimCustomer)
        ↓
Lookup: ProductID    → ProductKey   (DimProduct)
        ↓
Lookup: SupplierID   → SupplierKey  (DimSupplier)
        ↓
Lookup: Order_Date   → DateKey      (DimDate)
        ↓
Lookup: OrderID      → PaymentKey   (DimPayment)
        ↓
OLE DB Destination (Fact_Sales)
```

---

## Package Deployment and Scheduling

Both packages were deployed via File System and scheduled using SQL Server Agent.

## Power BI Dashboard

An interactive dashboard was built using Power BI Desktop connected to the **OnlineShop_DWH** database. The dashboard consists of three pages:

### Page 1 — Sales Overview
- Total Revenue card
- Total Orders card
- Units Sold card
- Revenue by Month line chart
- Top 10 Products bar chart
- Revenue by Category donut chart
- Top Customers table

### Page 2 — Shipment Analysis
- Average Delivery Days card
- Late Shipments % card
- Total Shipments card
- Average Delivery by Carrier bar chart
- On Time vs Late pie chart
- Late Reasons bar chart
- Shipments by Month line chart

### Page 3 — Product Reviews
- Average Rating card
- Total Reviews card
- Positive Reviews % card
- Top Rated Products bar chart
- Rating Trend by Month line chart
- Rating Distribution bar chart
- Product Ratings table

### DAX Measures Used
```dax
Total Revenue =
CALCULATE(
    SUM(Fact_Sales[Total_Amount]),
    DimPayment[Transaction_Status] = "Completed"
)

Avg Delivery Days =
AVERAGE(Fact_Shipment[Delivery_Duration_Days])

Avg Rating =
AVERAGE(Fact_Review[Rating])

Late Shipments % =
DIVIDE(
    CALCULATE(
        COUNT(Fact_Shipment[ShipmentFactKey]),
        DimJunkStatus[Is_Late] = 1
    ),
    COUNT(Fact_Shipment[ShipmentFactKey])
) * 100
```

---

## Key Performance Indicators (KPIs)

| KPI | Source Fact | Measure |
|-----|-------------|---------|
| Total Revenue | Fact_Sales | SUM(Total_Amount) where Completed |
| Revenue by Month/Year | Fact_Sales | SUM(Total_Amount) grouped by DimDate |
| Revenue by Product | Fact_Sales | SUM(Total_Amount) grouped by DimProduct |
| Top Selling Products | Fact_Sales | SUM(Quantity) grouped by DimProduct |
| Revenue Growth % | Fact_Sales | LAG comparison by Year |
| Sales Trend Over Time | Fact_Sales | SUM(Total_Amount) by Quarter |
| Top Customers by Spending | Fact_Sales | SUM(Total_Amount) by DimCustomer |
| Average Delivery Time | Fact_Shipment | AVG(Delivery_Duration_Days) |
| Product Rating Average | Fact_Review | AVG(Rating) |
| Best Rated Products | Fact_Review | AVG(Rating) by DimProduct |

---

## How to Run the Project

### 1. Restore Source Database
```sql
-- Run Source_Database_Script.sql in SSMS
-- Creates OnlineShop_Source with all tables and data
```

### 2. Create Staging Database
```sql
-- Run STG_Database_Script.sql in SSMS
-- Creates OnlineShop_STG with all staging tables
```

### 3. Create DWH Database
```sql
-- Run DWH_Database_Script.sql in SSMS
-- Creates OnlineShop_DWH with all dimension and fact tables
```

### 4. Run SSIS Package 1 (Source → STG)
```
Open Visual Studio
Open ETL_Source_To_STG project
Press F5 to run
Verify all tables loaded successfully
```

### 5. Run SSIS Package 2 (STG → DWH)
```
Open Visual Studio
Open ETL_STG_To_DWH project
Press F5 to run
Verify all dimensions and facts loaded
```

### 6. Open Power BI Dashboard
```
Open OnlineShop_Dashboard.pbix
Refresh data source connection
Explore all three dashboard pages
```

---

## Project Structure

```
DWH_Project/
├── Scripts/
│   ├── Source_Database_Script.sql
│   ├── STG_Database_Script.sql
│   └── DWH_Database_Script.sql
├── SSIS/
│   ├── ETL_Source_To_STG/
│   │   └── ETL_Source_To_STG.dtsx
│   └── ETL_STG_To_DWH/
│       └── ETL_STG_To_DWH.dtsx
├── PowerBI/
│   └── OnlineShop_Dashboard.pbix
└── README.md
```
