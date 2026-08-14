# Solstice Outfitters — Power BI Build Guide

This is the step-by-step I used to turn `data/solstice.db` into the Power BI report. I can't run Power BI Desktop from where this was built, so treat this as a precise recipe rather than a finished `.pbix` — following it end to end (roughly 60–90 minutes if you're comfortable with Power BI, longer if some of this is new) gets you the actual report.

## 1. Get the data in

1. Power BI Desktop → **Get Data** → **More** → **Database** → **SQLite database**.
   - If the SQLite connector isn't in your list, install the SQLite ODBC driver first (`sqliteodbc` from ch-werner.de, 64-bit build) — Power BI uses ODBC under the hood for SQLite.
   - Point it at `data/solstice.db`.
2. In the Navigator, select all six tables: `dim_date`, `dim_store`, `dim_employee`, `dim_product`, `dim_customer`, `fact_sales`. Load them (not DirectQuery — this dataset is small enough that Import mode is faster and lets you work offline).
3. Alternative if the ODBC driver is a pain to install: open `sql/03_export_csv.py` (included) to dump each table to CSV, then **Get Data → Folder / Text-CSV** instead. Same result, zero driver setup.

## 2. Build the data model

Go to **Model view** and wire up these relationships (all single-direction, star schema, `fact_sales` is the many side):

| From (fact_sales) | To (dimension) | Cardinality |
|---|---|---|
| `date_key` | `dim_date[date_key]` | Many-to-one |
| `customer_id` | `dim_customer[customer_id]` | Many-to-one |
| `product_id` | `dim_product[product_id]` | Many-to-one |
| `store_id` | `dim_store[store_id]` | Many-to-one |
| `employee_id` | `dim_employee[employee_id]` | Many-to-one |

Mark `dim_date` as a **Date Table** (Table tools → Mark as Date Table → pick `full_date`). This unlocks time-intelligence DAX functions (`SAMEPERIODLASTYEAR`, `DATESYTD`, etc.).

Set data types explicitly — SQLite is loosely typed and Power BI sometimes guesses wrong:
- `dim_date[full_date]` → Date
- `fact_sales[unit_price]`, `list_price`, `unit_cost`, `discount_pct` → Decimal Number
- `dim_customer[email]` → Text (leave the nulls as-is, don't blank-fill them — that's a real data quality signal worth keeping visible)

## 3. Add the measures

Create a dedicated measures table so they're not scattered across dimension tables: **Model view → New Table**, name it `_Measures`, formula: `_Measures = ROW("blank", BLANK())` — this gives you a clean home folder for everything below.

```dax
Net Revenue =
SUMX(
    fact_sales,
    fact_sales[quantity] * fact_sales[unit_price] *
    SWITCH(fact_sales[order_status], "Completed", 1, "Returned", -1, 0)
)

Net Profit =
SUMX(
    fact_sales,
    fact_sales[quantity] * (fact_sales[unit_price] - fact_sales[unit_cost]) *
    SWITCH(fact_sales[order_status], "Completed", 1, "Returned", -1, 0)
)

Profit Margin % = DIVIDE([Net Profit], [Net Revenue])

Orders = CALCULATE(DISTINCTCOUNT(fact_sales[order_id]), fact_sales[order_status] <> "Cancelled")

Average Order Value = DIVIDE([Net Revenue], [Orders])

Units Sold = CALCULATE(SUM(fact_sales[quantity]), fact_sales[order_status] = "Completed")

Return Rate % =
DIVIDE(
    CALCULATE(COUNTROWS(fact_sales), fact_sales[order_status] = "Returned"),
    COUNTROWS(fact_sales)
)

Revenue PY = CALCULATE([Net Revenue], SAMEPERIODLASTYEAR(dim_date[full_date]))

Revenue YoY % = DIVIDE([Net Revenue] - [Revenue PY], [Revenue PY])

Revenue YTD = TOTALYTD([Net Revenue], dim_date[full_date])

-- Distinct customers who bought in the selected period
Active Customers = DISTINCTCOUNT(fact_sales[customer_id])

-- New vs returning: a customer's first-ever order date, computed once
Customer First Order Date =
CALCULATE(
    MIN(fact_sales[date_key]),
    ALLEXCEPT(fact_sales, fact_sales[customer_id])
)

Repeat Purchase Rate =
VAR CustomersThisPeriod = DISTINCTCOUNT(fact_sales[customer_id])
VAR RepeatCustomers =
    CALCULATE(
        DISTINCTCOUNT(fact_sales[customer_id]),
        FILTER(
            VALUES(fact_sales[customer_id]),
            CALCULATE(DISTINCTCOUNT(fact_sales[order_id])) > 1
        )
    )
RETURN DIVIDE(RepeatCustomers, CustomersThisPeriod)

-- Rank for a "top products" visual that reacts to filters
Product Revenue Rank = RANKX(ALLSELECTED(dim_product[product_name]), [Net Revenue])
```

A note on the first three measures: `SUMX` with a row-level `SWITCH` is doing the netting-out-returns logic — that mirrors query #1 in `sql/02_analysis_queries.sql` deliberately, so the SQL and the DAX agree with each other. If a reviewer checks your SQL output against your dashboard numbers, they should match to the penny.

## 4. Report pages

Three pages keeps it focused rather than a wall of tiles.

### Page 1 — Executive Overview
- Card row: **Net Revenue**, **Revenue YoY %**, **Orders**, **Average Order Value**, **Profit Margin %** (5 cards, top row)
- Line chart: Net Revenue by month, with a second line for Revenue PY (same axis) so the YoY comparison is visual, not just a number
- Column chart: Net Revenue by Category
- Donut or 100% stacked bar: Revenue split by store type (Online vs Retail)
- Slicers along the top: Year, Quarter, Region

### Page 2 — Customers
- Table or matrix: RFM segments (Champions / Regular / At Risk / Lost) with customer count and total monetary value — build this either by importing the output of SQL query #4 as a calculated table, or replicate the NTILE logic with DAX `RANKX` + bucketing (SQL import is more reliable here; NTILE doesn't have a clean native DAX equivalent)
- Stacked column: New vs Returning revenue by month (matches SQL query #10)
- Scatter plot: Frequency (x) vs Monetary (y), one dot per customer, colored by segment
- KPI card: Repeat Purchase Rate

### Page 3 — Operations
- Matrix: Store × Month revenue with conditional formatting (data bars)
- Bar chart: Return Rate % by Category — this is a real merchandising insight (footwear and apparel return far more than gear) and a good talking point in an interview
- Table: Top 15 products by revenue with margin %, sorted, using `Product Revenue Rank`
- Bar chart: Retail staff performance (revenue per employee) — filter out Online in a visual-level filter since online has no employee attribution

## 5. Formatting choices that make it not look templated

- Turn off the default Power BI theme. Build a custom theme JSON (`docs/theme.json` included) using a muted forest-green / warm-grey palette that actually fits an outdoor brand, instead of the default blue/orange.
- Remove chart titles that just repeat the axis labels; use text boxes with actual sentence insights instead (e.g. "Camping & Hiking overtook apparel as the top category in mid-2023, driven by the summer sales bump").
- Use a consistent card style throughout (rounded corners, no drop shadows, one accent color for positive/negative deltas) rather than the default card visual look.
- Add a small "data as of [last refresh date]" footer — real dashboards have that, template screenshots usually don't.

## 6. Publish / share

If you want a shareable link rather than just a local `.pbix`: **Publish** to a Power BI workspace (needs a Power BI account, free tier works for personal portfolio use), then use **File → Embed report → Publish to web** *only* if the data is fully synthetic and you're comfortable with it being public — for a portfolio piece that's usually fine since there's no real customer data in here.
