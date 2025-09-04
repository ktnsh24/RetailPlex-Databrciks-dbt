SELECT
    oi.order_item_id,
    oi.order_id,
    oi.customer_id,
    oi.product_id,
    oi.event_id,
    oi.quantity,
    oi.unit_price,
    oi.discount,
    oi.tax_amount,
    oi.shipping_cost,
    (oi.quantity * oi.unit_price) AS gross_revenue,
    (oi.quantity * (oi.unit_price - p.cost)) AS gross_profit,
    (oi.quantity * oi.unit_price - oi.discount + oi.tax_amount + oi.shipping_cost) AS net_revenue
FROM {{ref('silver_batch_order_items')}} oi
JOIN {{source('silver', 'product')}} p ON oi.product_id = p.product_id;

