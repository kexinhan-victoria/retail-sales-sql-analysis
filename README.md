# Retail Sales SQL Analysis (Olist Brazilian E-Commerce)

Four business cases written in SQL (SQLite) on the public Olist dataset (about 100K orders, 2016–2018). Each case states the business question, the metric definitions, the query, the result, and a one-line recommendation.

| # | Case | Business question | SQL skills |
|---|------|-------------------|-----------|
| 1 | [State monthly growth](sql/01_state_monthly_growth.sql) | Which 5 states grew fastest month over month? | JOIN, `strftime`, CTE, `LAG()` |
| 2 | [Category growth & ranking](sql/02_category_growth_ranking.sql) | Which categories grow fastest, which are big but weak, what are the top 3 per state? | JOIN, conditional aggregation, `HAVING`, `CASE WHEN`, `RANK()` |
| 3 | [Peak period analysis](sql/03_peak_period_analysis.sql) | Which categories did Black Friday (Nov 2017) lift the most? | `CASE WHEN`, date filters, monthly average vs single month |
| 4 | [Benchmark vs average](sql/04_benchmark_vs_average.sql) | Which states lag the national average on order value and delivery time? | Subqueries, `CASE WHEN`, `julianday`, order-level grain |

## Key findings
- **Case 1:** July 2018 sales were flat (+1.7%) but the mix shifted. ES (+76%), PE (+66%) and GO (+44%) grew fast, while SP (-5%) and MG (-12%), about half of all sales, fell.
- **Case 2:** Sales grew about 158% (Jan–Jul 2018 vs 2017). watches_gifts, health_beauty and housewares are large and beating the market. cool_stuff (+24%) is large but losing share.
- **Case 3:** Black Friday lifted toys (2.3x), perfumery (2.1x) and computers_accessories (2.0x) the most. baby barely moved (1.1x).
- **Case 4:** North and Northeast states have the highest order values (160–215 BRL vs 137 national) but wait 20–25 days for delivery vs 9 days in São Paulo.

## Method notes
- Sales = sum of item `price` (freight excluded). Canceled and unavailable orders are excluded.
- Analysis window is 2017-01 to 2018-07. August 2018 is incomplete in the data, so it is left out.
- Olist has no promotion data, so the Black Friday month stands in for a promotion period.
- Order value is summed to order level before averaging, so the result is average order value, not average item price.

## Reproduce
1. Download the dataset from [Kaggle: Brazilian E-Commerce by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
2. In DB Browser for SQLite, import these CSVs with default table names: orders, order_items, products, customers, product_category_name_translation.
3. Run the files in `sql/`.

## Structure
```
sql/       one .sql file per case
results/   query result screenshots
```
