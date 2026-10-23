/* =====================================================================
   Case 1 | State monthly performance and month-over-month growth
   案例 1 | 各州月度表现与环比增长
   ---------------------------------------------------------------------
   Business question:
     How much does each Brazilian state sell per month, and which
     5 states grew fastest month over month (Jul 2018 vs Jun 2018)?
   业务问题：每个州每月销售额是多少？2018 年 7 月对比 6 月，
            哪 5 个州环比增长最快？

   Definitions / 口径
     - Sales       = SUM(order_items.price), freight excluded
     - State       = customer_state of the buyer
     - Month       = month of order_purchase_timestamp
     - Excluded    = orders with status 'canceled' or 'unavailable'
     - Period      = 2017-01 to 2018-07. 2016 is near-empty, and August
                     2018 is cut off (orders stop around 29 Aug), so it
                     is not a complete month and is left out.
                     2018 年 8 月数据不完整（月底截断），所以不纳入。
     - Threshold   = prior-month sales >= 10,000 BRL, so tiny states
                     with a small base do not top the growth ranking

   Skills: multi-table JOIN, strftime, CTE, LAG() window function
   ===================================================================== */

-- Query A: monthly sales per state, with the previous month and MoM growth
WITH state_month AS (
    SELECT
        c.customer_state                                AS state,
        strftime('%Y-%m', o.order_purchase_timestamp)   AS order_month,
        SUM(i.price)                                    AS sales
    FROM olist_orders_dataset       AS o
    JOIN olist_customers_dataset    AS c ON o.customer_id = c.customer_id
    JOIN olist_order_items_dataset  AS i ON o.order_id    = i.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND strftime('%Y-%m', o.order_purchase_timestamp) BETWEEN '2017-01' AND '2018-07'
    GROUP BY c.customer_state, order_month
),
with_prev AS (
    SELECT
        state,
        order_month,
        sales,
        LAG(sales) OVER (PARTITION BY state ORDER BY order_month) AS prev_sales
    FROM state_month
)
SELECT
    state,
    order_month,
    ROUND(sales, 2)                                              AS sales,
    ROUND(prev_sales, 2)                                         AS prev_month_sales,
    ROUND((sales - prev_sales) * 100.0 / NULLIF(prev_sales, 0), 1) AS mom_growth_pct
FROM with_prev
ORDER BY state, order_month;


-- Query B: top 5 states by MoM growth in the latest complete month (2018-07 vs 2018-06)
WITH state_month AS (
    SELECT
        c.customer_state                                AS state,
        strftime('%Y-%m', o.order_purchase_timestamp)   AS order_month,
        SUM(i.price)                                    AS sales
    FROM olist_orders_dataset       AS o
    JOIN olist_customers_dataset    AS c ON o.customer_id = c.customer_id
    JOIN olist_order_items_dataset  AS i ON o.order_id    = i.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND strftime('%Y-%m', o.order_purchase_timestamp) BETWEEN '2017-01' AND '2018-07'
    GROUP BY c.customer_state, order_month
),
with_prev AS (
    SELECT
        state,
        order_month,
        sales,
        LAG(sales) OVER (PARTITION BY state ORDER BY order_month) AS prev_sales
    FROM state_month
)
SELECT
    state,
    ROUND(prev_sales, 2)                                         AS jun_2018_sales,
    ROUND(sales, 2)                                              AS jul_2018_sales,
    ROUND(sales - prev_sales, 2)                                 AS growth_brl,
    ROUND((sales - prev_sales) * 100.0 / NULLIF(prev_sales, 0), 1) AS mom_growth_pct
FROM with_prev
WHERE order_month = '2018-07'
  AND prev_sales >= 10000
ORDER BY mom_growth_pct DESC
LIMIT 5;

/* Recommendation / 建议:
   Total sales were almost flat in Jul 2018 (+1.7%), but the mix shifted.
   Mid-sized states grew fast: ES +76%, PE +66%, GO +44%, BA +21%,
   while the two biggest markets fell (SP -5%, MG -12%). Next step:
   check whether the ES/PE jump repeats in the following months before
   moving budget there, and investigate the SP and MG decline first,
   because together they are about half of all sales.
   7 月总销售额基本持平，但结构在变：ES、PE、GO、BA 等中型州增长很快，
   而最大的 SP 和 MG 在下滑。先确认中型州的增长能否持续再加预算，
   同时优先排查 SP 和 MG 的下滑，因为这两个州占全部销售额约一半。
*/
