/* =====================================================================
   Case 3 | Peak period analysis (used in place of promotion analysis)
   案例 3 | 高峰期分析（代替促销分析）
   ---------------------------------------------------------------------
   Business question:
     Compared with normal months, which categories got the biggest lift
     in the peak month, November 2017 (Black Friday)?
   业务问题：2017 年 11 月（黑色星期五所在月）和普通月份相比，
            哪些类目被拉动最多？

   Note: the Olist dataset has no promotion data, so the Black Friday
   month is used as the "promotion" period. The logic is the same as a
   promo uplift analysis.
   说明：Olist 没有促销数据，用黑五所在月代替促销期，分析思路相同。

   Definitions / 口径
     - Peak month    = 2017-11
     - Normal months = 2017-08 to 2017-10 (3 months). Earlier 2017 months
                       are left out because the marketplace was growing
                       fast: Jan 2017 sales were < 20% of Oct 2017, which
                       would inflate the lift.
     - Lift          = peak-month sales / average normal-month sales
     - Minimum       = categories with >= 10,000 BRL per normal month

   Skills: date filtering, CASE WHEN labels, conditional aggregation,
           CTE, monthly average vs single month
   ===================================================================== */

WITH base AS (
    SELECT
        COALESCE(t.product_category_name_english,
                 NULLIF(p.product_category_name, ''),
                 'unknown')                              AS category,
        i.order_id,
        i.price,
        CASE
            WHEN strftime('%Y-%m', o.order_purchase_timestamp) = '2017-11'
                THEN 'peak'
            WHEN strftime('%Y-%m', o.order_purchase_timestamp) BETWEEN '2017-08' AND '2017-10'
                THEN 'normal'
        END                                              AS period
    FROM olist_orders_dataset              AS o
    JOIN olist_order_items_dataset         AS i ON o.order_id   = i.order_id
    JOIN olist_products_dataset            AS p ON i.product_id = p.product_id
    LEFT JOIN product_category_name_translation AS t
           ON p.product_category_name = t.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND strftime('%Y-%m', o.order_purchase_timestamp) BETWEEN '2017-08' AND '2017-11'
),
category_period AS (
    SELECT
        category,
        SUM(CASE WHEN period = 'peak'   THEN price ELSE 0 END)       AS peak_sales,
        SUM(CASE WHEN period = 'normal' THEN price ELSE 0 END) / 3.0 AS normal_avg_sales,
        COUNT(DISTINCT CASE WHEN period = 'peak'   THEN order_id END)       AS peak_orders,
        COUNT(DISTINCT CASE WHEN period = 'normal' THEN order_id END) / 3.0 AS normal_avg_orders
    FROM base
    GROUP BY category
)
SELECT
    category,
    ROUND(normal_avg_sales, 2)                            AS normal_month_avg_sales,
    ROUND(peak_sales, 2)                                  AS nov_2017_sales,
    ROUND(peak_sales / NULLIF(normal_avg_sales, 0), 2)    AS sales_lift_x,
    ROUND(peak_orders / NULLIF(normal_avg_orders, 0), 2)  AS order_lift_x,
    ROUND(peak_sales - normal_avg_sales, 2)               AS extra_sales_brl
FROM category_period
WHERE normal_avg_sales >= 10000
ORDER BY sales_lift_x DESC;

/* Result / 结果: see results/03_peak_period_analysis.png

   Recommendation / 建议:
   Black Friday lifted toys (2.3x), perfumery (2.1x) and
   computers_accessories (2.0x) the most, so these categories need extra
   stock and promo budget for the next peak. watches_gifts and
   bed_bath_table add the most extra BRL (+47K and +37K). baby (1.1x)
   barely responded, and computers fell (0.2x), so they should not take
   peak-season promo budget.
   黑五拉动最大的是玩具（2.3 倍）、香水（2.1 倍）和电脑配件（2.0 倍），
   下次大促应优先备货和投放；baby 几乎没有被拉动，computers 反而下滑，
   不应占用大促资源。
*/
