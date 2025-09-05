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

- Provides **order line–level transactions** linking customers, orders, products, and events.  

---

## 📂 Data Flow till Landing Schema

<img width="571" height="331" alt="image" src="https://github.com/user-attachments/assets/a2898144-ae67-4454-9a21-cae8c21c5183" />





---

## ✅ Key Understanding
- **Multiplex streaming JSONL** → multiple topics intermixed, need to be split into separate raw Bronze tables.  
- **Broadcast/reference CSVs** → lookup dimensions for enrichment and joins.  
- **Batch CSV (order items)** → fact-level transactional data, refreshed daily.  
- Together, these represent the **raw landing zone** of the Medallion Architecture before transformation into Bronze → Silver → Gold layers.  

