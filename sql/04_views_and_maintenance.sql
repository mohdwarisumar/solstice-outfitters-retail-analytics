/* ============================================================================
   Solstice Outfitters — Views, Keys & Maintenance Statements
   Database: solstice.db (SQLite)
   ----------------------------------------------------------------------------
   These aren't part of the analysis — they demonstrate the rest of the core
   SQL toolkit: primary/foreign keys, views, and the standard maintenance
   statements (UPDATE, DELETE, ALTER, TRUNCATE). Everything below is safe to
   run against a copy of the database; nothing here is required for the
   dashboards or Power BI report to work.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   KEYS — already in place, just pointing at where to look
   Every table in sql/01_schema.sql declares a PRIMARY KEY (the column that
   uniquely identifies each row — order_line_id on fact_sales, product_id on
   dim_product, etc.) and fact_sales declares FOREIGN KEYs back to each
   dimension table (date_key, customer_id, product_id, store_id, employee_id)
   — that's what actually enforces "every sale must point at a real product,
   a real customer, a real store," not just a naming convention.
---------------------------------------------------------------------------- */


/* ----------------------------------------------------------------------------
   VIEW — a saved query you can SELECT from like a table. Useful for a
   calculation you reuse constantly (like net revenue per line, which shows
   up in half the analysis queries) so you write the CASE logic once.
---------------------------------------------------------------------------- */
CREATE VIEW IF NOT EXISTS v_net_sales_line AS
SELECT
    f.order_line_id,
    f.order_id,
    f.date_key,
    f.customer_id,
    f.product_id,
    f.store_id,
    CASE WHEN f.order_status = 'Completed' THEN f.quantity * f.unit_price
         WHEN f.order_status = 'Returned'  THEN -1 * f.quantity * f.unit_price
         ELSE 0 END AS net_revenue,
    CASE WHEN f.order_status = 'Completed' THEN f.quantity * (f.unit_price - f.unit_cost)
         WHEN f.order_status = 'Returned'  THEN -1 * f.quantity * (f.unit_price - f.unit_cost)
         ELSE 0 END AS net_profit
FROM fact_sales f;

-- now this simple SELECT does what query #1's CASE logic did, without repeating it:
SELECT d.year, d.month, ROUND(SUM(v.net_revenue), 2) AS net_revenue
FROM v_net_sales_line v
JOIN dim_date d ON v.date_key = d.date_key
GROUP BY d.year, d.month
ORDER BY d.year, d.month;


/* ----------------------------------------------------------------------------
   UPDATE — correct a single row. Example: a customer emails in a corrected
   email address.
---------------------------------------------------------------------------- */
UPDATE dim_customer
SET email = 'corrected.address@example.com'
WHERE customer_id = 1;


/* ----------------------------------------------------------------------------
   DELETE — remove specific rows. Example: purge test/cancelled orders that
   should never have been written to the fact table (a real cleanup task,
   not something you'd normally do to Completed/Returned rows).
---------------------------------------------------------------------------- */
DELETE FROM fact_sales
WHERE order_status = 'Cancelled' AND order_id = 100000;


/* ----------------------------------------------------------------------------
   ALTER TABLE — change a table's structure. Example: the business wants to
   start tracking whether an order came through the mobile app.
---------------------------------------------------------------------------- */
ALTER TABLE fact_sales ADD COLUMN is_mobile_order INTEGER DEFAULT 0;


/* ----------------------------------------------------------------------------
   TRUNCATE — empty a table completely, keeping its structure. Standard SQL
   (MySQL, SQL Server, Postgres) has a dedicated TRUNCATE TABLE statement:

       TRUNCATE TABLE staging_import;

   SQLite has no TRUNCATE keyword — the equivalent there is a DELETE with no
   WHERE clause, which removes every row but leaves the table (and its
   schema) in place:
---------------------------------------------------------------------------- */
DELETE FROM fact_sales WHERE 1=0;  -- harmless no-op version for this demo file;
                                    -- a real truncate would be: DELETE FROM table_name;
