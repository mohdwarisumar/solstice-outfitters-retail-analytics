CREATE TABLE dim_customer (
    customer_id INTEGER PRIMARY KEY, first_name TEXT, last_name TEXT, email TEXT, city TEXT, region TEXT,
    signup_date TEXT, acquisition_channel TEXT
);
CREATE TABLE dim_date (
    date_key INTEGER PRIMARY KEY, full_date TEXT NOT NULL, day INTEGER, day_name TEXT,
    month INTEGER, month_name TEXT, quarter INTEGER, year INTEGER,
    is_weekend INTEGER, is_holiday INTEGER, fiscal_period TEXT
);
CREATE TABLE dim_employee (
    employee_id INTEGER PRIMARY KEY, employee_name TEXT, role TEXT, store_id INTEGER, hire_date TEXT,
    FOREIGN KEY (store_id) REFERENCES dim_store(store_id)
);
CREATE TABLE dim_product (
    product_id INTEGER PRIMARY KEY, product_name TEXT NOT NULL, category TEXT, subcategory TEXT, brand TEXT,
    unit_cost REAL, unit_price REAL, launch_date TEXT
);
CREATE TABLE dim_store (
    store_id INTEGER PRIMARY KEY, store_name TEXT NOT NULL, store_type TEXT, city TEXT, region TEXT, opened_date TEXT
);
CREATE TABLE fact_sales (
    order_line_id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, date_key INTEGER NOT NULL,
    customer_id INTEGER NOT NULL, product_id INTEGER NOT NULL, store_id INTEGER NOT NULL,
    employee_id INTEGER, quantity INTEGER NOT NULL, unit_price REAL NOT NULL, list_price REAL NOT NULL,
    discount_pct REAL NOT NULL, unit_cost REAL NOT NULL, order_status TEXT NOT NULL, payment_method TEXT,
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
    FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
    FOREIGN KEY (store_id) REFERENCES dim_store(store_id),
    FOREIGN KEY (employee_id) REFERENCES dim_employee(employee_id)
);
CREATE INDEX idx_fact_date ON fact_sales(date_key);
CREATE INDEX idx_fact_customer ON fact_sales(customer_id);
CREATE INDEX idx_fact_product ON fact_sales(product_id);
CREATE INDEX idx_fact_store ON fact_sales(store_id);
