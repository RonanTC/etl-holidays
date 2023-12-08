CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(64)
);

CREATE TABLE locations (
    location_id SERIAL PRIMARY KEY,
    location_name VARCHAR(64)
);

CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    order_date DATE,
    price_paid NUMERIC(10, 2),
    customer_id INT REFERENCES customers(customer_id),
    location_id INT REFERENCES locations(location_id)
);

INSERT INTO customers
(customer_name)
VALUES
('Keith'),
('Dave');