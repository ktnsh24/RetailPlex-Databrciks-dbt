{{ config(
    materialized='view',
    schema='silver'
) }}

SELECT
    TRIM(state_code) AS state_code,
    TRIM(state_name) AS state_name,
    TRIM(region) AS region,
    TRIM(country_code) AS country_code,
    TRIM(country_name ) AS country_name,
    TRIM(timezone ) AS timezone,
    CAST(sales_tax_rate AS DECIMAL(18,2)) AS sales_tax_rate,
    CAST(shipping_zone AS INT ) AS shipping_zone,
    CAST(population_millions AS DECIMAL(18,2)) AS population_millions,
    CURRENT_TIMESTAMP() AS _ingested_at
FROM {{ source('bronze','broadcast_geography') }}


