SELECT 
    c.customer_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.gross_revenue) AS lifetime_gross_revenue,
    SUM(oi.net_revenue) AS lifetime_net_revenue,
    SUM(oi.gross_profit) AS lifetime_profit,
    MAX(o.order_date) AS last_order_date,
    DATEDIFF(MAX(o.order_date), MIN(o.order_date)) AS active_days_span
FROM {{ref('gold_fct_order_items')}} oi
JOIN {{source('silver', 'order')}} o ON oi.order_id = o.order_id
JOIN {{source('silver', 'customer')}} c ON oi.customer_id = c.customer_id
WHERE c.active_ind =1
GROUP BY c.customer_id;
