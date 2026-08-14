# Solstice Outfitters — Plain-English Walkthrough & Interview Prep

This doc exists so you can talk about this project confidently without re-deriving the SQL live in an interview. Read it once, and you should be able to explain every query without notes.

## The one-sentence pitch

"I built a synthetic retail sales dataset for a fictional outdoor gear retailer, modeled it as a star schema in SQL, wrote analytical queries covering revenue trends, customer segmentation, and returns, then built the reporting layer on top — either in Power BI or as a standalone web dashboard."

If asked "why fictional data instead of a real dataset like Kaggle's Superstore," your answer: "I wanted control over realism — seasonality, returns, discounting behavior — and I wanted something an interviewer hasn't already seen fifty times."

## The data model, explained simply

Picture a spreadsheet where every row is one product sold on one order. That's `fact_sales` — the "fact" table, the thing you're actually measuring (65,500 rows, one per order line). Everything else is a lookup table that describes *who*, *what*, *where*, *when*:

- `dim_date` — one row per calendar day, so I can group sales by month, quarter, year, or flag weekends/holidays
- `dim_customer` — who bought it
- `dim_product` — what they bought
- `dim_store` — where (online or one of 5 shops)
- `dim_employee` — which staff member helped (retail only)

This is called a **star schema** because if you draw it, `fact_sales` sits in the middle with lines radiating out to each dimension table, like a star. It's the standard pattern in BI/data warehousing because it keeps queries simple (mostly `JOIN` + `GROUP BY`) and keeps each table's data from being repeated everywhere (a product's price lives in one place, `dim_product`, not copied onto every sale row).

**If asked "why not just one big flat table?"** — you could, but then the product name, price, category etc. would be duplicated across every single row that product appears in (thousands of times), which wastes space and makes updates dangerous (change a price in one row, forget the other 500, now your data disagrees with itself). Splitting into fact + dimensions is called *normalization* for the dimensions, while the fact table itself stays at a fine grain on purpose.

## Query-by-query, in plain English

All 12 queries use only WHERE, aggregate functions (`SUM`, `COUNT`, `AVG`, `MIN`, `MAX`), `GROUP BY`, `HAVING`, `ORDER BY`, `JOIN`s, subqueries, and one `UNION` — nothing beyond that. Where a query needs a value computed from another query (like "the most recent date in the dataset"), it uses a **subquery**: either a small standalone query in parentheses that returns one value, or a whole query in the `FROM` clause that acts like a temporary table for the rest of the query to join against.

**Query 1 — Monthly revenue trend.** Groups every order line by year and month, adds up revenue, but *subtracts* revenue for anything marked "Returned" and ignores anything "Cancelled" entirely. That's what "net revenue" means here — money the business actually kept.

**Query 2 — Year-over-year growth.** Builds the same "monthly revenue" query twice as a subquery (once aliased `cur`, once `prev`), then joins them to each other, matching each month to the same month one year earlier. This is a genuine **self-join** — the two subqueries pull from the same underlying tables, just joined back to each other under different aliases so you can compare "this year" to "last year" side by side.

**Query 3 — Top products.** Straightforward grouping by product, sorted by revenue, limited to the top 15. The only non-obvious part is the margin calculation: `(revenue - cost) / revenue`.

**Query 4 — RFM segmentation.** This is the one worth understanding deeply because it's the most "senior analyst" query in the set. RFM stands for **Recency** (how long since they last bought), **Frequency** (how many separate orders), **Monetary** (how much they've spent). A subquery computes all three per customer, then a `CASE` statement sorts them into segments using fixed, explainable thresholds: bought within the last 90 days = "recent," 6+ orders = "frequent." Someone recent *and* frequent → "Champions." Someone who hasn't bought in 270+ days and only ordered a couple of times → "Lost/Dormant." If asked "why these specific cutoffs," the honest answer is they're a business judgment call, not derived from the data — which is exactly why they're easy to defend: you can just say "90 days felt like a reasonable window for a retailer with this order frequency" rather than explaining a statistical method.

**Query 5 — Regional performance.** Just a group-by on store region, nothing tricky.

**Query 6 — Customer activation rate.** For each signup month, a subquery finds each customer's very first completed order date, then a `LEFT JOIN` only keeps that match if it happened within 90 days of signing up. Comparing "customers in the cohort" to "customers who activated" with `COUNT(DISTINCT ...)` on each gives a straightforward activation percentage. Worth knowing: the very last few months in the output will look artificially low — they simply haven't had 90 days pass yet since the dataset ends, so some of those customers just haven't had the *chance* to activate within the window yet. That's a real analytics concept called **right-censoring**, and it's worth mentioning unprompted if this chart comes up — it shows you understand why the tail of a time-based chart is often unreliable.

**Query 7 — Return rate by category.** Simple ratio: returned lines / total lines, grouped by category. Uses `HAVING COUNT(*) >= 100` to drop any category too thin to trust the percentage — `HAVING` filters *after* grouping (on the aggregated result), which is different from `WHERE` (filters rows *before* grouping); you couldn't write this as a `WHERE` clause because "total lines per category" doesn't exist until the grouping has already happened.

**Query 8 — Discount effectiveness.** Compares profit-per-unit between discounted and full-price lines. The point of this query is that "discounting increases total revenue" can be true while "discounting hurts profit per unit" is *also* true — both things can be true at once, and this query is designed to surface the second fact, which is easy to miss if you only look at top-line revenue.

**Query 9 — Staff performance.** Group-by on employee, revenue and order count, with `HAVING` again — this time excluding anyone who's handled fewer than 5 orders, so one lucky big sale doesn't make a barely-active employee look like a top performer. Excludes online orders since there's no employee attached to those.

**Query 10 — New vs. returning revenue.** A subquery finds each customer's very first order month; the main query then joins to it and labels every order line "New" (if it's in that first month) or "Returning" (any month after). Shows how the revenue mix shifts as the customer base matures.

**Query 11 — "Worth featuring" list.** Two independent subqueries — top 5 products by revenue, and top 5 by margin — combined with `UNION`, which stacks two result sets into one list and automatically drops exact duplicates (a product that's in both top-5s only appears once). This is the standard way to answer "give me one list that covers two different reasons something matters."

**Query 12 — Products frequently bought together.** A genuine self-join on `fact_sales` itself: joining the table to itself on `order_id` means every resulting row pairs two *different* products that showed up on the same order. The condition `f1.product_id < f2.product_id` is a small trick worth understanding — without it, you'd get every pair twice (once as A-then-B, once as B-then-A); the `<` guarantees each pair only shows up once.

## Likely interview questions

**"Walk me through your data model."** Use the star schema explanation above. Draw it if you can — fact table in the middle, dimensions around it.

**"How would you handle this at real scale — millions of rows?"** Honest answer: SQLite is fine for a portfolio project but wouldn't be the real choice at scale — you'd want a columnar warehouse (BigQuery, Snowflake, Redshift) or at minimum Postgres with proper indexing. The SQL itself barely changes; what changes is partitioning the fact table by date and probably pre-aggregating the heaviest queries (like the monthly rollups) into materialized views so you're not re-scanning 65k+ rows on every dashboard refresh.

**"What was the hardest part?"** Be honest: getting the synthetic data to behave *realistically* — seasonality, a store that opens partway through the dataset, returns concentrated in the right categories — was harder than writing the SQL. Naive random data doesn't produce insights worth finding; you have to deliberately build in patterns for the analysis to have something real to discover.

**"What would you add if you had another week?"** Good honest answers: inventory/stock-out data (to distinguish "no one wanted it" from "we didn't have it"), a proper customer lifetime value model, or marketing spend by channel so you could compute actual CAC instead of just looking at revenue by acquisition channel.

**"Why SQLite instead of Postgres/MySQL/SQL Server?"** Zero setup — no server to install or credentials to manage, the whole database is one file, which makes the project fully self-contained and reproducible by anyone who clones it. The SQL is close enough to standard that porting the queries to Postgres would mean minor syntax changes (mainly around date functions), not a rewrite.

## Vocabulary to have cold

- **Star schema** — fact table + surrounding dimension tables
- **Grain** — what one row of a table represents (here, one product on one order)
- **Subquery / derived table** — a `SELECT` nested inside another query, either producing a single value (used like a number) or a whole result set (used like a temporary table in the `FROM` clause)
- **Self-join** — joining a table (or a subquery pulling from a table) to itself, so you can compare rows in that table to *other* rows in the same table — prior year vs. current year, or one product against another on the same order
- **WHERE vs. HAVING** — `WHERE` filters individual rows before grouping; `HAVING` filters groups after aggregation, so it's the only place you can filter on something like `COUNT(*)` or `SUM(...)`
- **UNION** — stacks two result sets with the same columns into one list, dropping exact duplicate rows (`UNION ALL` keeps duplicates, if you ever need that instead)
- **Cohort analysis** — measuring a group of customers who started at the same time, tracked forward

## Also in this project

`sql/04_views_and_maintenance.sql` covers the rest of the core SQL toolkit that doesn't naturally fit into "analysis" queries: primary/foreign keys (pointing at the schema), a `CREATE VIEW` example, and `UPDATE`/`DELETE`/`ALTER TABLE`/the SQLite equivalent of `TRUNCATE`. Worth a skim before an interview since these are exactly the kind of "can you write basic DDL/DML" questions that come up.
