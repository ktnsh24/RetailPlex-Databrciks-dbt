
SELECT /*+ BROADCAST(pc, sc, s) */
    p.product_id,
    p.product_name,
    pc.category_name,
    sc.subcategory_name,
    p.brand,
    p.price,
    p.cost,
    (p.price - p.cost) AS margin_per_unit,
    s.supplier_name,
    s.supplier_region,
    s.quality_rating
FROM {{source('silver', 'product')}} p
LEFT JOIN {{source('silver', 'broadcast_product_categories')}} pc 
       ON p.category = pc.category_name
LEFT JOIN {{source('silver', 'broadcast_product_subcategories')}} sc 
       ON p.subcategory = sc.subcategory_name
LEFT JOIN {{source('silver', 'broadcast_suppliers')}} s 
       ON p.supplier_id = s.supplier_id;
