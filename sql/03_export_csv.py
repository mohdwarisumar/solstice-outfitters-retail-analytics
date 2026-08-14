"""
Quick fallback exporter: dumps every table in solstice.db to CSV so you can
load them into Power BI via Get Data > Folder/Text-CSV if you don't want to
bother installing a SQLite ODBC driver.

Usage: python3 03_export_csv.py   (run from the sql/ folder, or adjust paths)
"""
import sqlite3
import csv
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "solstice.db")
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "csv_export")

os.makedirs(OUT_DIR, exist_ok=True)

conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()
cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
tables = [r[0] for r in cur.fetchall()]

for table in tables:
    cur.execute(f"SELECT * FROM {table}")
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    out_path = os.path.join(OUT_DIR, f"{table}.csv")
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(cols)
        writer.writerows(rows)
    print(f"{table}: {len(rows):,} rows -> {out_path}")

conn.close()
