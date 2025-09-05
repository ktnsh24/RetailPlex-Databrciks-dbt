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
