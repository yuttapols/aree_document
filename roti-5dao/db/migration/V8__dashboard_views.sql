-- =====================================================================
-- Phase 4 : Views สำหรับ Dashboard (นับเฉพาะออเดอร์ที่ COMPLETED)
-- =====================================================================

CREATE VIEW v_daily_sales AS
SELECT (o.completed_at AT TIME ZONE 'Asia/Bangkok')::date      AS sales_date,
       count(*)                                                 AS order_count,
       count(*) FILTER (WHERE o.customer_id IS NOT NULL)        AS member_order_count,
       count(*) FILTER (WHERE o.channel = 'WALK_IN')            AS walk_in_count,
       count(*) FILTER (WHERE o.channel = 'ONLINE')             AS online_count,
       sum(o.subtotal)                                          AS gross_sales,
       sum(o.promotion_discount + o.point_discount)             AS total_discount,
       sum(o.total_amount)                                      AS net_sales
FROM orders o
WHERE o.status = 'COMPLETED'
GROUP BY 1;

CREATE VIEW v_product_sales AS
SELECT (o.completed_at AT TIME ZONE 'Asia/Bangkok')::date AS sales_date,
       oi.product_id,
       p.name                                             AS product_name,
       p.category_id,
       sum(oi.quantity)                                   AS quantity,
       sum(oi.line_total)                                 AS amount
FROM order_item oi
JOIN orders  o ON o.id = oi.order_id
JOIN product p ON p.id = oi.product_id
WHERE o.status = 'COMPLETED'
GROUP BY 1, 2, 3, 4;

CREATE VIEW v_payment_method_sales AS
SELECT (py.paid_at AT TIME ZONE 'Asia/Bangkok')::date AS sales_date,
       pm.code                                        AS method_code,
       pm.name                                        AS method_name,
       count(*)                                       AS payment_count,
       sum(py.amount)                                 AS amount
FROM payment py
JOIN payment_method pm ON pm.id = py.payment_method_id
JOIN orders o          ON o.id = py.order_id
WHERE py.status = 'PAID' AND o.status = 'COMPLETED'
GROUP BY 1, 2, 3;

CREATE INDEX ix_orders_completed ON orders (completed_at) WHERE status = 'COMPLETED';
