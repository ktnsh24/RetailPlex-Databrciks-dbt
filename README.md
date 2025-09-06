# RetailPlex-Databrciks-dbt

This project simulates a **retail analytics platform** where data is ingested from multiple sources (streaming, batch, and reference data) and staged in **Databricks Unity Catalog** under the catalog `retailplex_platform` and schema `landing`.  

---

## 📌 Data Sources

### 1. Streaming Multiplex Data
- Arrives as **JSONL** files under:  

/Volumes/retailplex_platform/landing/raw_files/incoming_multiplex_data/retailplex_multiplex_stream_<timestamp>.jsonl

- Each file contains multiple **topics**:
- `customers` → customer profile data  
- `products` → product master data  
- `orders` → customer orders  
- `events` → customer browsing and interaction events  

---

### 2. Reference Data (Broadcast Tables)
- Small, relatively static lookup/enrichment datasets in **CSV format**.  
- Stored under:  

/Volumes/retailplex_platform/landing/raw_files/refdata/

- Includes:
- `Customer_segments.csv`
- `Geography.csv`
- `Product_categories.csv`
- `Product_subcategories.csv`
- `Suppliers.csv`

---

### 3. Batch Data (Singleplex Full Load)
- Large transactional dataset refreshed **daily as a full load**.  
- Stored under:  

/Volumes/retailplex_platform/landing/raw_files/batch_data/batch_order_items.csv

- Loaded as managed table: landing.batch_order_items.
- Provides **order line–level transactions** linking customers, orders, products, and events.  

---
So far, the landing schema acts as the raw ingestion zone:

- Streaming JSON lines (multiplex)
- Referential CSVs (refdata)
- Bulk batch CSV (batch_order_items)

These datasets are the foundation for downstream bronze → silver → gold processing in the medallion architecture.

## 📂 Data Flow till Landing Schema


```plaintext
retailplex_platform/
├── landing/
│   ├── raw_files/
│   │   ├── incoming_multiplex_data/
│   │   │   └── retailplex_multiplex_stream_<timestamp>.jsonl   # Streaming data
│   │   ├── refdata/                                            # Reference / broadcast data
│   │   │   ├── Customer_segments.csv
│   │   │   ├── Geography.csv
│   │   │   ├── Product_categories.csv
│   │   │   ├── Product_subcategories.csv
│   │   │   └── Suppliers.csv
│   │   └── batch_data/
│   │       └── batch_order_items.csv                           # Daily full load
│   └── tables/
│       └── batch_order_items                                   # Landing managed table
```
---

## ✅ Key Understanding
- **Multiplex streaming JSONL** → multiple topics intermixed, need to be split into separate raw Bronze tables.  
- **Broadcast/reference CSVs** → lookup dimensions for enrichment and joins.  
- **Batch CSV (order items)** → fact-level transactional data, refreshed daily.  
- Together, these represent the **raw landing zone** of the Medallion Architecture before transformation into Bronze → Silver → Gold layers.  

## 🥉 Bronze Layer (Medallion Architecture)

In the **Bronze schema**, data from the Landing layer is ingested into structured tables while still retaining raw characteristics.  
The key principle here is to **preserve the original data** but add minimal metadata such as ingestion timestamps.

### 🔹 Data Ingestion Strategy

- **Streaming Data (Multiplex Stream)**  
  - Data from `retailplex_multiplex_stream_<timestamp>.jsonl` is ingested into the Bronze table `multiplex_stream`.  
  - Implemented using **Spark Structured Streaming** (`spark.readStream` + `spark.writeStream`).  
  - A column `_ingestion_timestamp` is added (`current_timestamp()` at ingestion).  
  - Streaming checkpoints are managed in `/Volumes/checkpoints/retailplex_stream`.

- **Batch Data (DBT ⚡)**  
  - `batch_order_items.csv` (large full load dataset) is processed via **dbt**.  
  - Materialized into the Bronze schema as `bronze_batch_order_items`.

- **Broadcast Reference Tables (CSV-based)**  
  - `Customer_segments`, `Product_categories`, `Product_subcategories`, and `Suppliers` are ingested via **COPY INTO** commands in Databricks.  
  - These are relatively small lookup/reference datasets.

- **Broadcast_Geography Data (DBT Seed ⚡)**  
  - The `broadcast_geography.csv` dataset is managed as a **dbt seed**.  
  - Materialized directly in the Bronze schema.

---

### 🔹 Bronze Layer Flow

```plaintext
retailplex_platform/
├── landing/
│   └── raw_files/
│       ├── incoming_multiplex_data/ (multiplex JSONL stream)
│       ├── batch_data/ (batch_order_items.csv)
│       └── refdata/ (reference CSVs)
│
├── bronze/
│   ├── multiplex_stream                  (streamed via Spark Structured Streaming + ingestion_timestamp)
│   ├── bronze_batch_order_items ⚡       (materialized via dbt model from batch_order_items.csv)
│   ├── customer_segments                 (COPY INTO from refdata)
│   ├── product_categories                (COPY INTO from refdata)
│   ├── product_subcategories             (COPY INTO from refdata)
│   ├── suppliers                         (COPY INTO from refdata)
│   ├── geography ⚡                       (dbt seed → materialized in Bronze)
│   └── (checkpoints for streaming maintained under Volumes/checkpoints/retailplex_stream)
⚡ = Indicates dbt involvement
```
🎯 Purpose of Bronze Layer

- Bronze Layer: Store structured raw data with ingestion metadata, while preserving fidelity for downstream transformation.
- Prepares a solid foundation for the Silver layer, where cleaning, deduplication, and standardization will take place.

## 🥈 Silver Layer

The **Silver schema** is the **refined layer** in the Medallion Architecture.  
Here, data from Bronze is **cleaned, structured, and modeled** for business use cases.  
Different strategies are applied depending on the type of data (SCD1, SCD2, CDC, or dbt transformations).

---

### 🔹 Transformation Strategy

- **Multiplex Stream Data**  
  Split into dedicated domain tables:
  - **Customers (SCD1)**  
    - Uses Slowly Changing Dimension Type 1.  
    - Updates overwrite existing records (no history tracked).  
  - **Orders (SCD2, PySpark)**  
    - Maintains full history of changes.  
    - Implemented in **PySpark** for flexibility.  
  - **Products (SCD2, SQL)**  
    - Tracks product history over time.  
    - Implemented in **SQL** for simplicity.  
  - **Events (CDC Strategy)**  
    - A `event_cdc` table stores all insert/update/delete changes (full history).  
    - A `event` table stores only the latest snapshot of events.

- **Broadcast Reference Tables**  
  - Views are created in Silver schema from Bronze tables (`customer_segments`, `product_categories`, `product_subcategories`, `suppliers`, `geography`).  
  - Explicit schemas are defined for consistency.

- **Batch & Seed Data (via dbt ⚡)**  
  - **Batch Table (`batch_order_items`)**:  
    - Re-materialized via **dbt** in Silver schema with proper schema definitions.  
  - **Geography Seed Table**:  
    - Materialized as a **view** in Silver schema via **dbt**.

---

### 📂 Silver Layer Flow

```plaintext
retailplex_platform/
├── silver/
│   ├── customer (SCD1, from multiplex_stream)
│   ├── order (SCD2, PySpark, from multiplex_stream)
│   ├── product (SCD2, SQL, from multiplex_stream)
│   ├── event_cdc (full CDC history from multiplex_stream)
│   ├── event (latest snapshot view from event_cdc)
│   ├── broadcast_customer_segments (view from bronze)
│   ├── broadcast_product_categories (view from bronze)
│   ├── broadcast_product_subcategories (view from bronze)
│   ├── broadcast_suppliers (view from bronze)
│   ├── silver_batch_order_items ⚡ (dbt model)
│   └── silver_broadcast_geography ⚡ (dbt seed view)
⚡ = Indicates dbt involvement
```
🎯 Purpose of Silver Layer

- Normalize and split multiplex data into domain tables.
- Apply SCD1, SCD2, and CDC strategies to preserve meaning and maintain history where necessary.
- Use dbt for batch and seed transformations, ensuring CI/CD integration.
- Expose clean, consistent, and business-ready datasets for downstream analytics and the Gold layer.

## 🥇 Gold Layer – Data Modelling

In the **Gold layer**, we apply **data modelling** to transform refined Silver data into **dimensions** and **fact tables**.  
These serve as the foundation for KPIs, analytics, and future data marts (FLT).  

Currently, the following **dimension (`dim_`)** and **fact (`fct_`)** tables have been materialized in **dbt ⚡**.  
FLT (data marts) will be introduced later.

---

### 📊 Dimensions (DIM)

#### 1. `gold_dim_customer`
**Purpose:** Enrich the `customer` table with attributes for segmentation and geography.

**Key Features:**
- Adds customer **segment metadata** (discount %, support level, free shipping threshold).  
- Links customers to **region & country** via geography lookup.  
- Computes **customer tenure days** from registration date.  
- Only active customers (`active_ind = 1`) are included.  

**Business Question Answered:**  
➡️ *“Who are our customers, what segments do they belong to, where are they located, and how long have they been with us?”*

---

#### 2. `gold_dim_product`
**Purpose:** Create a fully enriched **product dimension**.

**Key Features:**
- Joins product with **category, subcategory, and supplier metadata**.  
- Computes **margin per unit** (`price – cost`).  
- Adds supplier quality rating and region.  

**Business Question Answered:**  
➡️ *“What products do we sell, how are they categorized, who supplies them, and what’s their profit margin?”*

---

### 📈 Facts (FCT)

#### 1. `gold_fct_order_items`
**Purpose:** Provide a **granular sales fact table** at the order item level.

**Key Features:**
- Includes revenue breakdowns:  
  - **Gross revenue** = qty × price  
  - **Gross profit** = qty × (price – cost)  
  - **Net revenue** = gross – discount + tax + shipping  
- Joins with product to fetch cost for margin calculations.  

**Business Question Answered:**  
➡️ *“How much revenue and profit are we making at the item level?”*

---

#### 2. `gold_fct_customer_lifetime`
**Purpose:** Aggregate a customer’s **lifetime value metrics**.

**Key Features:**
- Total orders placed.  
- Lifetime revenue (gross, net) and profit.  
- **Last order date** for recency tracking.  
- **Active days span** (time between first and last order).  

**Business Question Answered:**  
➡️ *“What is each customer’s lifetime value and engagement span?”*

---

#### 3. `gold_fct_event_funnel`
**Purpose:** Track customer activity across the **conversion funnel**.

**Key Features:**
- Aggregates event data per customer/session.  
- Counts: `views`, `add_to_cart`, `checkout_started`, `purchases`.  

**Business Question Answered:**  
➡️ *“How do customers progress through the funnel, and where do they drop off?”*

### 📂 Gold Layer Flow

```plaintext
retailplex_platform/
├── gold/
│   ├── gold_dim_customer ⚡ (dbt model)
│   │     - Enriched customer profile
│   │     - Joined with customer segments + geography
│   │     - Includes demographics, tenure, active filter
│   │
│   ├── gold_dim_product ⚡ (dbt model)
│   │     - Enriched product attributes
│   │     - Categories, subcategories, suppliers
│   │     - Includes margin per unit (price - cost)
│   │
│   ├── gold_fct_order_items ⚡ (dbt model)
│   │     - Transaction-level fact table
│   │     - Gross revenue, net revenue, gross profit
│   │
│   ├── gold_fct_customer_lifetime ⚡ (dbt model)
│   │     - Customer-level aggregated metrics
│   │     - Orders, revenue, profit, last activity
│   │
│   └── gold_fct_event_funnel ⚡ (dbt model)
│         - Session-level funnel
│         - Views → Cart Adds → Checkout → Purchases
⚡ = Indicates dbt involvement
```
🎯 Purpose of the Gold Layer

- Business-friendly data → Abstracts away raw/operational complexity and delivers curated, business-ready entities.
- Dimensional modeling → Organizes data into Dimensions (who/what/where) and Facts (transactions/metrics) following star schema principles.
- Single source of truth → Ensures consistent KPIs and metrics across reporting tools.
- Optimized for BI/Analytics → Tables are pre-aggregated, joined with reference data, and designed for fast query performance.
- Governed by dbt ⚡ → All models in this layer are built, materialized, and documented using dbt for transparency, lineage, and testing.
