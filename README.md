# Solstice Outfitters — Retail Sales Analytics

SQL + Power BI project analyzing sales performance for a fictional UK outdoor apparel and gear retailer with one online store and five physical locations, covering January 2023 through July 2026.

## Why this project

I wanted something closer to a real retail analytics brief than a generic "clean CSV, make a chart" exercise — so instead of pulling a dataset off Kaggle, I built the whole thing from scratch: a star-schema database, a synthetic-but-realistic transaction history (seasonality, returns, discounting, a store that opens mid-dataset and has to ramp up), and then the SQL and Power BI layer on top of it. The scenario is invented, but the data behaves the way real retail data behaves — messy in believable ways, not too clean.

## The business questions

- How is revenue trending, and is growth accelerating or slowing?
- Which categories and products are actually driving profit, not just revenue?
- Are online and retail store performance diverging?
- Which customers are worth protecting (RFM segmentation), and how much of revenue comes from repeat buyers vs. new ones?
- Where is the return rate a problem, and is discounting actually paying for itself?

## Data model

Star schema, one fact table and five dimensions:

```
dim_date ──┐
dim_store ─┤
dim_employee ├── fact_sales ──┤
dim_product ─┤
dim_customer ┘
```

`fact_sales` is order-line grain (~65,500 rows) — one row per product per order. `dim_customer` has ~3,200 customers, `dim_product` has 120 SKUs across 5 categories, and `dim_store` covers the online channel plus 5 UK retail locations that opened on different dates (Leeds only opened in Sept 2024, which shows up clearly in the region comparisons).

Full schema is in `sql/01_schema.sql`.

A deliberate choice on the SQL itself: every analysis query sticks to core SQL — `WHERE`, aggregate functions, `GROUP BY`, `HAVING`, `ORDER BY`, joins (including a couple of genuine self-joins), `UNION`, and subqueries. No CTEs, no window functions. Not because those are bad — they're standard tools — but because I wanted every line in this project to be something I can actually explain and defend, not copy-pasted syntax I'd fumble if asked to walk through it live.

## What's in this folder

```
data/generate_data.py     — the data generator (numpy-vectorized, runs in ~3s)
data/solstice.db          — the SQLite database
sql/01_schema.sql         — table definitions
sql/02_analysis_queries.sql — 12 analytical queries (RFM, cohorts, YoY, self-joins, etc.)
sql/03_export_csv.py      — fallback CSV export if you don't want to set up a SQLite ODBC driver
sql/04_views_and_maintenance.sql — keys, a CREATE VIEW example, and UPDATE/DELETE/ALTER/TRUNCATE
docs/powerbi_build_guide.md — step-by-step to assemble the actual Power BI report
docs/walkthrough_and_interview_prep.md — plain-English explanation of every query + likely
                                           interview questions
docs/theme.json            — custom Power BI theme (not the default blue/orange)
dashboard/dashboard.html   — a standalone interactive dashboard covering the same analysis, viewable without Power BI installed
```

## Findings worth calling out

Camping & Hiking became the top-revenue category by mid-2023, ahead of both apparel lines combined — the summer sales bump (May–Sept) is doing a lot of work there, and it's disproportionately driven by a handful of tent and cook-set SKUs from one supplier (Northfell). That's a supplier-concentration risk worth flagging in a real business.

Return rates are not evenly spread: footwear sits at ~14%, apparel around 11-12%, but camping gear and accessories are both under 6%. Sizing-dependent categories return more — not surprising once you see it, but it's the kind of thing that's easy to miss if you only look at blended return rate.

Discounted lines have meaningfully lower profit-per-unit than full-price lines even after accounting for the volume they move — the SQL for that comparison is query #8, and it's a good example of a metric that looks fine in isolation (revenue goes up when you discount) but isn't fine once you look at margin.

New customer revenue as a share of the total shrinks steadily over the dataset's timeline while returning-customer revenue grows — expected for a maturing retailer, but it also means acquisition channels matter more over time, not less, since the new-customer pool is thinning relative to the base.

## Reproducing it

```bash
cd data
python3 generate_data.py      # rebuilds solstice.db from scratch
```

Then either open `data/solstice.db` directly in a SQLite browser to run the queries in `sql/02_analysis_queries.sql`, or follow `docs/powerbi_build_guide.md` to bring it into Power BI Desktop. `dashboard/dashboard.html` can just be opened in a browser — no server, no dependencies.

## Honest limitations

This is synthetic data, so it doesn't have the genuinely weird outliers real transaction data has (fraud, refund abuse, data entry typos beyond the deliberate missing-email rate). The seasonality and growth curves are modeled, not observed, so treat the "findings" above as demonstrations of the analytical approach rather than real market insight. If I were doing this against a live business I'd also want inventory/stock-out data to distinguish "customers didn't want it" from "we didn't have it in stock," which isn't modeled here.

— Mohammad Waris
