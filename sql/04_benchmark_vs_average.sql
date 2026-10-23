/* =====================================================================
   Case 4 | Benchmark against the national average
   案例 4 | 对比全国平均，标出落后者
   ---------------------------------------------------------------------
   Business question:
     How does each state's average order value (AOV) and average
     delivery time compare with the national average? Which states lag?
   业务问题：各州的客单价和平均配送天数，与全国平均相比如何？
            哪些州表现落后？

   Definitions / 口径
     - Order value   = SUM(price) per order (an order can hold several
                       items, so values are summed to order level FIRST,
                       then averaged; averaging item rows would give
                       average item price, not AOV)
     - Delivery days = order_delivered_customer_date - order_purchase_timestamp
     - Orders        = delivered orders only, 2017-01 to 2018-07
     - Labels        = more than 10% worse than national average = 'Lagging',
                       more than 10% better = 'Leading', else 'In line'
                       (for delivery, fewer days is better)
     - Minimum       = states with >= 300 delivered orders

   Skills: subqueries (scalar subquery for the national average),
           CASE WHEN, julianday date difference, aggregation grain
   ===================================================================== */

WITH order_level AS (
    SELECT
        o.order_id,
        c.customer_state                                  AS state,
        SUM(i.price)                                      AS order_value,
        julianday(o.order_delivered_customer_date)
          - julianday(o.order_purchase_timestamp)         AS delivery_days
    FROM olist_orders_dataset       AS o
    JOIN olist_customers_dataset    AS c ON o.customer_id = c.customer_id
    JOIN olist_order_items_dataset  AS i ON o.order_id    = i.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_delivered_customer_date <> ''
      AND strftime('%Y-%m', o.order_purchase_timestamp) BETWEEN '2017-01' AND '2018-07'
    GROUP BY o.order_id, c.customer_state, o.order_delivered_customer_date, o.order_purchase_timestamp
),
state_stats AS (
    SELECT
        state,
        COUNT(*)            AS orders,
        AVG(order_value)    AS aov,
        AVG(delivery_days)  AS avg_delivery_days
    FROM order_level
    GROUP BY state
    HAVING COUNT(*) >= 300
)
SELECT
    state,
    orders,
    ROUND(aov, 2)                                                       AS aov,
    ROUND((SELECT AVG(order_value) FROM order_level), 2)                AS national_aov,
    CASE
        WHEN aov < 0.9 * (SELECT AVG(order_value) FROM order_level) THEN 'Lagging'
        WHEN aov > 1.1 * (SELECT AVG(order_value) FROM order_level) THEN 'Leading'
        ELSE 'In line'
    END                                                                 AS aov_flag,
    ROUND(avg_delivery_days, 1)                                         AS avg_delivery_days,
    ROUND((SELECT AVG(delivery_days) FROM order_level), 1)              AS national_delivery_days,
    CASE
        WHEN avg_delivery_days > 1.1 * (SELECT AVG(delivery_days) FROM order_level) THEN 'Lagging'
        WHEN avg_delivery_days < 0.9 * (SELECT AVG(delivery_days) FROM order_level) THEN 'Leading'
        ELSE 'In line'
    END                                                                 AS delivery_flag
FROM state_stats
ORDER BY avg_delivery_days DESC;

/* Result / 结果: see results/04_benchmark_vs_average.png

   Recommendation / 建议:
   Northeast and North states (AL, PA, SE, MA, CE, PB) have the HIGHEST
   order values (160–215 BRL vs 137 national) but wait 20–25 days for
   delivery vs 12.9 nationally and 9 in SP. These are valuable customers
   with poor service. Improving logistics there (regional sellers or a
   closer warehouse) is the best lever for repeat orders.
   Note: the national average is order-weighted and SP is ~40% of
   orders, which is why most states show as lagging on delivery.
   东北部和北部各州客单价最高，但配送要 20–25 天，接近全国平均的 2 倍；
   改善这些州的物流（区域卖家或就近仓）最有可能提升复购。
*/
