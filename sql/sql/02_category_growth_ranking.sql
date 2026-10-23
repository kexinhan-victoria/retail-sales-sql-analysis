/* =====================================================================
   Case 2 | Category growth and ranking
   案例 2 | 类目增长与排名
   ---------------------------------------------------------------------
   Business questions:
     1. Which product categories are growing fastest?
     2. Which categories sell a lot but are growing weakly?
     3. What are the top 3 categories in each state?
   业务问题：1. 哪些类目增长最快？
            2. 哪些类目销售额高但增长弱？
            3. 每个州排名前 3 的类目是什么？

   Definitions / 口径
     - Growth      = Jan–Jul 2018 vs Jan–Jul 2017 (same months, so
                     seasonality cancels out)
     - Category    = English name; untranslated or blank names fall back
                     to the Portuguese name or 'unknown'
     - Minimum     = categories with >= 20,000 BRL in Jan–Jul 2017,
                     so tiny categories do not dominate growth %
     - High sales  = Jan–Jul 2018 sales >= 200,000 BRL
     - High growth = growth >= 100% (the whole marketplace grew ~158%
                     over the same period, so below 100% = losing share)

   Skills: 4-table JOIN, conditional aggregation, HAVING, CASE WHEN,
           RANK() window function
   ===================================================================== */

-- Query A: category growth and quadrant label
WITH item_sales AS (
    SELECT
        COALESCE(t.product_category_name_english,
                 NULLIF(p.product_category_name, ''),
                 'unknown')                              AS category,
        strftime('%Y', o.order_purchase_timestamp)       AS yr,
        i.price
    FROM olist_orders_dataset              AS o
    JOIN olist_order_items_dataset         AS i ON o.order_id   = i.order_id
    JOIN olist_products_dataset            AS p ON i.product_id = p.product_id
    LEFT JOIN product_category_name_translation AS t
           ON p.product_category_name = t.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND strftime('%m', o.order_purchase_timestamp) BETWEEN '01' AND '07'
      AND strftime('%Y', o.order_purchase_timestamp) IN ('2017', '2018')
),
category_growth AS (
    SELECT
        category,
        SUM(CASE WHEN yr = '2017' THEN price ELSE 0 END) AS sales_2017,
        SUM(CASE WHEN yr = '2018' THEN price ELSE 0 END) AS sales_2018
    FROM item_sales
    GROUP BY category
    HAVING SUM(CASE WHEN yr = '2017' THEN price ELSE 0 END) >= 20000
)
SELECT
    category,
    ROUND(sales_2017, 2)                                        AS sales_jan_jul_2017,
    ROUND(sales_2018, 2)                                        AS sales_jan_jul_2018,
    ROUND((sales_2018 - sales_2017) * 100.0 / sales_2017, 1)    AS growth_pct,
    CASE
        WHEN sales_2018 >= 200000 AND (sales_2018 - sales_2017) * 1.0 / sales_2017 >= 1.0
            THEN 'High sales, high growth (star)'
        WHEN sales_2018 >= 200000
            THEN 'High sales, weak growth (defend)'
        WHEN (sales_2018 - sales_2017) * 1.0 / sales_2017 >= 1.0
            THEN 'Low sales, high growth (invest)'
        ELSE 'Low sales, weak growth (review)'
    END                                                         AS segment
FROM category_growth
ORDER BY growth_pct DESC;


-- Query B: top 3 categories in each state (Jan–Jul 2018)
WITH state_category AS (
    SELECT
        c.customer_state                                 AS state,
        COALESCE(t.product_category_name_english,
                 NULLIF(p.product_category_name, ''),
                 'unknown')                              AS category,
        SUM(i.price)                                     AS sales
    FROM olist_orders_dataset              AS o
    JOIN olist_customers_dataset           AS c ON o.customer_id = c.customer_id
    JOIN olist_order_items_dataset         AS i ON o.order_id    = i.order_id
    JOIN olist_products_dataset            AS p ON i.product_id  = p.product_id
    LEFT JOIN product_category_name_translation AS t
           ON p.product_category_name = t.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND strftime('%Y-%m', o.order_purchase_timestamp) BETWEEN '2018-01' AND '2018-07'
    GROUP BY state, category
),
ranked AS (
    SELECT
        state,
        category,
        sales,
        RANK() OVER (PARTITION BY state ORDER BY sales DESC) AS category_rank
    FROM state_category
)
SELECT state, category_rank, category, ROUND(sales, 2) AS sales
FROM ranked
WHERE category_rank <= 3
ORDER BY state, category_rank;

/* Result / 结果: see results/02_category_growth_ranking.png

   Recommendation / 建议:
   The whole marketplace grew about +158% (Jan–Jul 2018 vs 2017).
   watches_gifts (+274%), health_beauty (+229%) and housewares (+215%)
   are large AND beating the market: keep investing. cool_stuff (+24%)
   is large but clearly losing share: defend it with assortment and
   price checks. toys (+50%) and perfumery (+38%) are also falling
   behind. watches_gifts and health_beauty rank top 2 in most states,
   so they are the national hero categories.
   全平台同期增长约 158%。watches_gifts、health_beauty、housewares 规模大且跑赢大盘，
   继续投入；cool_stuff 规模大但明显跑输大盘，需要防守（选品和价格）；
   watches_gifts 和 health_beauty 在大多数州排前 2，是全国性主力类目。
*/
