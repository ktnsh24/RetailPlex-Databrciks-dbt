SELECT /*+ BROADCAST(cs, g) */
    c.customer_id,
    c.first_name,
    c.last_name,
    c.age,
    c.gender,
    g.region,
    g.country_name,
    cs.segment_name,
    cs.discount_percentage,
    cs.priority_support,
    cs.free_shipping_threshold,
    c.registration_date,
    DATEDIFF(current_date, c.registration_date) AS customer_tenure_days
FROM {{source('silver', 'customer')}} c
LEFT JOIN {{source('silver', 'broadcast_customer_segments')}} cs 
       ON c.customer_segment = cs.segment_name
LEFT JOIN {{ref('broadcast_geography')}} g
       ON c.state = g.state_code
WHERE c.active_ind =1;
