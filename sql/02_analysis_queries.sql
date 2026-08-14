/* ============================================================================
   Solstice Outfitters — Analytical SQL Queries
   Database: solstice.db (SQLite)
   Author:  Mohammad Waris
   ----------------------------------------------------------------------------
   Written using core SQL only: WHERE, aggregate functions, GROUP BY, HAVING,
   ORDER BY, JOINs (including a self-join), UNION, and subqueries. No CTEs
   (WITH...AS) and no window functions — every query below could be pasted
   into a beginner-friendly SQL course and every clause in it would be
   something covered in a first course on joins/aggregates/subqueries.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   1. Monthly net revenue trend (excludes cancelled lines, nets out returns)
   Topics: JOIN, WHERE (via CASE), aggregate functions, GROUP BY, ORDER BY
---------------------------------------------------------------------------- */
SELECT
    d.year,
    d.month,
    d.month_name,
    ROUND(SUM(CASE WHEN f.order_status = 'Completed' THEN f.quantity * f.unit_price
                    WHEN f.order_status = 'Returned'  THEN -1 * f.quantity * f.unit_price
                    ELSE 0 END), 2)                                   AS net_revenue,
    ROUND(SUM(CASE WHEN f.order_status = 'Completed' THEN f.quantity * (f.unit_price - f.unit_cost)
                    WHEN f.order_status = 'Returned'  THEN -1 * f.quantity * (f.unit_price - f.unit_cost)
                    ELSE 0 END), 2)                                   AS net_profit,
    COUNT(DISTINCT CASE WHEN f.order_status <> 'Cancelled' THEN f.order_id END) AS orders
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;


/* ----------------------------------------------------------------------------
   2. Year-over-year growth by month
   Topics: subquery (derived table), self-join — the same monthly-revenue
   subquery is joined to itself, once as "this year" and once as "last year"
---------------------------------------------------------------------------- */
SELECT
    cur.year, cur.month, cur.revenue AS revenue_current_year,
    prev.revenue AS revenue_prior_year,
    ROUND(100.0 * (cur.revenue - prev.revenue) / NULLIF(prev.revenue, 0), 1) AS yoy_growth_pct
FROM (
    SELECT d.year, d.month,
           SUM(CASE WHEN f.order_status = 'Completed' THEN f.quantity * f.unit_price ELSE 0 END) AS revenue
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month
) cur
LEFT JOIN (
    SELECT d.year, d.month,
           SUM(CASE WHEN f.order_status = 'Completed' THEN f.quantity * f.unit_price ELSE 0 END) AS revenue
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month
) prev ON prev.year = cur.year - 1 AND prev.month = cur.month
ORDER BY cur.year, cur.month;


/* ----------------------------------------------------------------------------
   3. Top 15 products by net revenue, with margin
   Topics: JOIN, WHERE, aggregate functions, GROUP BY, ORDER BY, LIMIT
---------------------------------------------------------------------------- */
SELECT
    p.product_name, p.category, p.brand,
    SUM(f.quantity)                                              AS units_sold,
    ROUND(SUM(f.quantity * f.unit_price), 2)                     AS revenue,
    ROUND(SUM(f.quantity * (f.unit_price - f.unit_cost)), 2)     AS profit,
    ROUND(100.0 * SUM(f.quantity * (f.unit_price - f.unit_cost)) / NULLIF(SUM(f.quantity * f.unit_price), 0), 1) AS margin_pct
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
WHERE f.order_status = 'Completed'
GROUP BY p.product_id, p.product_name, p.category, p.brand
ORDER BY revenue DESC
LIMIT 15;


/* ----------------------------------------------------------------------------
   4. Customer RFM segmentation (Recency, Frequency, Monetary)
   Anchor date = last date in the dataset. Segments use fixed, explainable
   business thresholds (recent = bought in the last 90 days, frequent = 6+
   orders) so the cutoffs are easy to justify in plain English.
   Topics: subquery (scalar, in SELECT), subquery (derived table), CASE, ORDER BY
---------------------------------------------------------------------------- */
SELECT
    co.customer_id,
    CAST(JULIANDAY((SELECT MAX(full_date) FROM dim_date)) - JULIANDAY(co.last_order_date) AS INTEGER) AS recency_days,
    co.frequency,
    ROUND(co.monetary, 2) AS monetary,
    CASE
        WHEN JULIANDAY((SELECT MAX(full_date) FROM dim_date)) - JULIANDAY(co.last_order_date) <= 90
             AND co.frequency >= 6                                              THEN 'Champions'
        WHEN JULIANDAY((SELECT MAX(full_date) FROM dim_date)) - JULIANDAY(co.last_order_date) <= 90
             AND co.frequency < 6                                               THEN 'New / Promising'
        WHEN JULIANDAY((SELECT MAX(full_date) FROM dim_date)) - JULIANDAY(co.last_order_date) > 270
             AND co.frequency >= 6                                              THEN 'At Risk (high value)'
        WHEN JULIANDAY((SELECT MAX(full_date) FROM dim_date)) - JULIANDAY(co.last_order_date) > 270
             AND co.frequency < 6                                               THEN 'Lost / Dormant'
        ELSE 'Regular'
    END AS segment
FROM (
    SELECT
        f.customer_id,
        MAX(d.full_date)                AS last_order_date,
        COUNT(DISTINCT f.order_id)       AS frequency,
        SUM(f.quantity * f.unit_price)   AS monetary
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    WHERE f.order_status = 'Completed'
    GROUP BY f.customer_id
) co
ORDER BY co.monetary DESC;


/* ----------------------------------------------------------------------------
   5. Regional performance (store region x revenue x AOV)
   Topics: JOIN, WHERE, aggregate functions, GROUP BY, ORDER BY
---------------------------------------------------------------------------- */
SELECT
    s.region, s.store_type,
    COUNT(DISTINCT f.order_id)                                              AS orders,
    ROUND(SUM(f.quantity * f.unit_price), 2)                                AS revenue,
    ROUND(SUM(f.quantity * f.unit_price) * 1.0 / COUNT(DISTINCT f.order_id), 2) AS avg_order_value
FROM fact_sales f
JOIN dim_store s ON f.store_id = s.store_id
WHERE f.order_status = 'Completed'
GROUP BY s.region, s.store_type
ORDER BY revenue DESC;


/* ----------------------------------------------------------------------------
   6. Customer activation rate — % of each signup month's customers who
      placed their first order within 90 days of signing up
   Topics: subquery (derived table), LEFT JOIN, GROUP BY, ORDER BY
---------------------------------------------------------------------------- */
SELECT
    STRFTIME('%Y-%m', c.signup_date) AS signup_month,
    COUNT(DISTINCT c.customer_id) AS customers_in_cohort,
    COUNT(DISTINCT o.customer_id) AS activated_within_90_days,
    ROUND(100.0 * COUNT(DISTINCT o.customer_id) / COUNT(DISTINCT c.customer_id), 1) AS pct_activated
FROM dim_customer c
LEFT JOIN (
    SELECT f.customer_id, MIN(d.full_date) AS first_order_date
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    WHERE f.order_status = 'Completed'
    GROUP BY f.customer_id
) o
    ON c.customer_id = o.customer_id
   AND JULIANDAY(o.first_order_date) - JULIANDAY(c.signup_date) <= 90
GROUP BY signup_month
ORDER BY signup_month;


/* ----------------------------------------------------------------------------
   7. Return rate by category (a real merchandising / quality signal)
   Only shows categories with at least 100 order lines, so a thin category
   full of one-off returns can't distort the ranking.
   Topics: JOIN, GROUP BY, HAVING, ORDER BY
---------------------------------------------------------------------------- */
SELECT
    p.category,
    COUNT(*)                                                          AS total_lines,
    SUM(CASE WHEN f.order_status = 'Returned' THEN 1 ELSE 0 END)      AS returned_lines,
    ROUND(100.0 * SUM(CASE WHEN f.order_status = 'Returned' THEN 1 ELSE 0 END) / COUNT(*), 1) AS return_rate_pct
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
GROUP BY p.category
HAVING COUNT(*) >= 100
ORDER BY return_rate_pct DESC;


/* ----------------------------------------------------------------------------
   8. Discount effectiveness — does discounting actually lift volume enough
      to be worth the margin given up?
   Topics: WHERE, CASE, aggregate functions, GROUP BY
---------------------------------------------------------------------------- */
SELECT
    CASE WHEN f.discount_pct > 0 THEN 'Discounted' ELSE 'Full Price' END AS price_type,
    COUNT(*)                                             AS lines,
    SUM(f.quantity)                                      AS units,
    ROUND(AVG(f.quantity), 2)                            AS avg_units_per_line,
    ROUND(SUM(f.quantity * (f.unit_price - f.unit_cost)), 2) AS total_profit,
    ROUND(SUM(f.quantity * (f.unit_price - f.unit_cost)) * 1.0 / SUM(f.quantity), 2) AS profit_per_unit
FROM fact_sales f
WHERE f.order_status = 'Completed'
GROUP BY price_type;


/* ----------------------------------------------------------------------------
   9. Retail staff performance — revenue and basket size per employee
      Only employees who've handled at least 5 orders (HAVING filters on the
      aggregate result, which is why it can't just be another WHERE clause —
      "orders handled" doesn't exist until after GROUP BY has run).
   Topics: JOIN (x2), WHERE, GROUP BY, HAVING, ORDER BY, LIMIT
---------------------------------------------------------------------------- */
SELECT
    e.employee_name, s.store_name, e.role,
    COUNT(DISTINCT f.order_id)                                     AS orders_handled,
    ROUND(SUM(f.quantity * f.unit_price), 2)                       AS revenue,
    ROUND(SUM(f.quantity * f.unit_price) * 1.0 / COUNT(DISTINCT f.order_id), 2) AS avg_basket_value
FROM fact_sales f
JOIN dim_employee e ON f.employee_id = e.employee_id
JOIN dim_store s ON e.store_id = s.store_id
WHERE f.order_status = 'Completed'
GROUP BY e.employee_id, e.employee_name, s.store_name, e.role
HAVING COUNT(DISTINCT f.order_id) >= 5
ORDER BY revenue DESC
LIMIT 20;


/* ----------------------------------------------------------------------------
   10. New vs. returning customer revenue split, by month
       (a customer's "first order month" defines them as new that month only)
   Topics: subquery (derived table), JOIN, CASE, GROUP BY, ORDER BY
---------------------------------------------------------------------------- */
SELECT
    STRFTIME('%Y-%m', d.full_date) AS order_month,
    CASE WHEN STRFTIME('%Y-%m', d.full_date) = fo.first_month THEN 'New' ELSE 'Returning' END AS customer_type,
    ROUND(SUM(f.quantity * f.unit_price), 2) AS revenue
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
JOIN (
    SELECT f2.customer_id, MIN(STRFTIME('%Y-%m', d2.full_date)) AS first_month
    FROM fact_sales f2
    JOIN dim_date d2 ON f2.date_key = d2.date_key
    WHERE f2.order_status = 'Completed'
    GROUP BY f2.customer_id
) fo ON f.customer_id = fo.customer_id
WHERE f.order_status = 'Completed'
GROUP BY order_month, customer_type
ORDER BY order_month, customer_type;


/* ----------------------------------------------------------------------------
   11. "Worth featuring" list — top 5 products by revenue, UNIONed with the
       top 5 by margin. A product can appear in both halves (it'll just show
       up once, since UNION drops duplicates) or only one — either way you get
       a single list of "products worth a homepage feature" for two different
       business reasons.
   Topics: UNION, subquery-free aggregate + ORDER BY + LIMIT on each side
---------------------------------------------------------------------------- */
SELECT product_name, category, 'Top revenue' AS reason, revenue AS metric_value
FROM (
    SELECT p.product_name, p.category, SUM(f.quantity * f.unit_price) AS revenue
    FROM fact_sales f
    JOIN dim_product p ON f.product_id = p.product_id
    WHERE f.order_status = 'Completed'
    GROUP BY p.product_id, p.product_name, p.category
    ORDER BY revenue DESC
    LIMIT 5
)

UNION

SELECT product_name, category, 'Top margin %' AS reason, margin_pct AS metric_value
FROM (
    SELECT p.product_name, p.category,
           ROUND(100.0 * SUM(f.quantity * (f.unit_price - f.unit_cost)) / SUM(f.quantity * f.unit_price), 1) AS margin_pct
    FROM fact_sales f
    JOIN dim_product p ON f.product_id = p.product_id
    WHERE f.order_status = 'Completed'
    GROUP BY p.product_id, p.product_name, p.category
    ORDER BY margin_pct DESC
    LIMIT 5
)
;


/* ----------------------------------------------------------------------------
   12. Products frequently bought together (a genuine self-join: fact_sales
       joined to itself on order_id, so each row pairs two different products
       that appeared on the same order)
   Topics: self-join, WHERE, GROUP BY, HAVING, ORDER BY, LIMIT
---------------------------------------------------------------------------- */
SELECT
    p1.product_name AS product_a,
    p2.product_name AS product_b,
    COUNT(*) AS times_bought_together
FROM fact_sales f1
JOIN fact_sales f2
    ON f1.order_id = f2.order_id
   AND f1.product_id < f2.product_id          -- avoids counting (A,B) and (B,A) as two separate pairs
JOIN dim_product p1 ON f1.product_id = p1.product_id
JOIN dim_product p2 ON f2.product_id = p2.product_id
WHERE f1.order_status = 'Completed' AND f2.order_status = 'Completed'
GROUP BY p1.product_name, p2.product_name
HAVING COUNT(*) >= 5
ORDER BY times_bought_together DESC
LIMIT 15;
