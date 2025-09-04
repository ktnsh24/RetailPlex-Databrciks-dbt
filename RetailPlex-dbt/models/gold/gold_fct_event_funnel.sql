
SELECT
    e.customer_id,
    e.session_id,
    SUM(CASE WHEN e.event_type = 'view' THEN 1 ELSE 0 END) AS views,
    SUM(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS cart_adds,
    SUM(CASE WHEN e.event_type = 'checkout_started' THEN 1 ELSE 0 END) AS checkouts,
    SUM(CASE WHEN e.event_type = 'purchase' THEN 1 ELSE 0 END) AS purchases
FROM {{source('silver', 'event')}} e
GROUP BY e.customer_id, e.session_id;
