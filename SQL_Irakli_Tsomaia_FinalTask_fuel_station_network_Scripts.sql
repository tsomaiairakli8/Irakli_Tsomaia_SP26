CREATE DATABASE fuel_station_network; -- Creating database

CREATE SCHEMA IF NOT EXISTS fsn; -- Creating schema

-- Creating tables. Parents first

-- 1. Location Table (Parent)
CREATE TABLE IF NOT EXISTS fsn.location (
    location_id SERIAL PRIMARY KEY, 
    location_description VARCHAR(255) NOT null UNIQUE
);

-- 2. Roles Table (Parent)
CREATE TABLE IF NOT EXISTS fsn.roles (
    role_id SERIAL PRIMARY KEY,
    role_description VARCHAR(50) NOT NULL UNIQUE
);

-- 3. Loyalty Tiers (Parent)
CREATE TABLE IF NOT EXISTS fsn.loyalty_tiers (
    loyalty_tier_id SERIAL PRIMARY KEY,
    loyalty_tier_description VARCHAR(50) NOT null UNIQUE
);

-- 4. Payment Method (Parent)
CREATE TABLE IF NOT EXISTS fsn.payment_method (
    payment_method_id SERIAL PRIMARY KEY,
    payment_method_description VARCHAR(50) NOT null UNIQUE
);

-- 5. Fuel Types (Parent)
CREATE TABLE IF NOT EXISTS fsn.fuel_types (
    fuel_type_id SERIAL PRIMARY KEY,
    fuel_description VARCHAR(50) NOT NULL UNIQUE
);

-- 6. Supplier (Parent)
CREATE TABLE IF NOT EXISTS fsn.supplier (
    supplier_id SERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL UNIQUE,
    contact_info VARCHAR(255) NOT NULL UNIQUE
);

-- 7. Customers (Depends on Loyalty Tiers)
CREATE TABLE IF NOT EXISTS fsn.customers (
    customer_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT null unique,
    loyalty_tier_id INT REFERENCES fsn.loyalty_tiers(loyalty_tier_id),
    join_date DATE DEFAULT CURRENT_DATE
);

-- 8. Fuel Station (Depends on Location)
CREATE TABLE IF NOT EXISTS fsn.fuel_station (
    station_id SERIAL PRIMARY KEY,
    station_name VARCHAR(100) NOT NULL UNIQUE, 
    location_id INT REFERENCES fsn.location(location_id)
);

-- 9. Employees (Depends on Station and Roles)
CREATE TABLE IF NOT EXISTS fsn.employees (
    employee_id SERIAL PRIMARY KEY,
    station_id INT REFERENCES fsn.fuel_station(station_id),
    role_id INT REFERENCES fsn.roles(role_id),
    first_name VARCHAR(50) NOT NULL ,
    last_name VARCHAR(50) NOT NULL
);

-- 10. Tanks (Depends on Station)
CREATE TABLE IF NOT EXISTS fsn.tanks (
    tank_id SERIAL PRIMARY KEY,
    station_id INT REFERENCES fsn.fuel_station(station_id),
    max_capacity DECIMAL(12, 2) NOT NULL
);

-- 11. Delivery (Depends on Supplier)
CREATE TABLE IF NOT EXISTS fsn.delivery (
    delivery_id SERIAL PRIMARY KEY,
    supplier_id INT REFERENCES fsn.supplier(supplier_id),
    quantity_received DECIMAL(12, 2) NOT NULL,
    cost_per_unit DECIMAL(10, 2) NOT NULL,
    delivery_date DATE DEFAULT CURRENT_DATE,
    -- GENERATED ALWAYS AS for total shipment value
    total_delivery_value DECIMAL(15, 2) GENERATED ALWAYS AS (quantity_received * cost_per_unit) stored -- This would decrease the load on the system
);

-- 12. Pricing (Depends on Station and Fuel Type)
CREATE TABLE IF NOT EXISTS fsn.pricing (
    pricing_id SERIAL PRIMARY KEY,
    station_id INT REFERENCES fsn.fuel_station(station_id),
    fuel_type_id INT REFERENCES fsn.fuel_types(fuel_type_id),
    price_per_unit DECIMAL(10, 2) NOT NULL,
    effective_date DATE DEFAULT CURRENT_DATE
);

-- 13. Sales (Depends on Customer, Pricing, Employee, Payment)
CREATE TABLE IF NOT EXISTS fsn.sales (
    sale_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES fsn.customers(customer_id), -- Gets NULL if its a guest with no account in our base
    pricing_id INT REFERENCES fsn.pricing(pricing_id),
    employee_id INT REFERENCES fsn.employees(employee_id),
    payment_method_id INT REFERENCES fsn.payment_method(payment_method_id),
    quantity_sold DECIMAL(12, 2) NOT NULL,
    total_amount DECIMAL(15, 2) NOT NULL,
    sale_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 14. Inventory Logs (Depends on Tanks, Fuel Types, Sales, Delivery)
CREATE TABLE IF NOT EXISTS fsn.inventory_logs (
    inventory_log_id SERIAL PRIMARY KEY,
    tank_id INT REFERENCES fsn.tanks(tank_id),
    fuel_type_id INT REFERENCES fsn.fuel_types(fuel_type_id),
    change_amount DECIMAL(12, 2) NOT NULL,
    sale_id INT REFERENCES fsn.sales(sale_id),
    delivery_id INT REFERENCES fsn.delivery(delivery_id),
    remaining_stock DECIMAL(12, 2) NOT NULL,
    log_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/*Altering tables and adding constraints as needed. We drop them first so script is rerunnable*/

-- Ensure deliveries are within the allowed timeline
ALTER TABLE fsn.delivery DROP CONSTRAINT IF EXISTS CK_delivery_date_valid;
ALTER TABLE fsn.delivery ADD CONSTRAINT CK_delivery_date_valid 
CHECK (delivery_date >= '2026-01-01' AND delivery_date <= CURRENT_TIMESTAMP);

-- Same with join date
ALTER TABLE fsn.customers  DROP CONSTRAINT IF EXISTS CK_customer_join_date_valid;
ALTER TABLE fsn.customers  ADD CONSTRAINT CK_customer_join_date_valid 
CHECK (join_date >= '2026-01-01' AND join_date <= CURRENT_TIMESTAMP);

-- Same with pricings effective date
ALTER TABLE fsn.pricing  DROP CONSTRAINT IF EXISTS CK_pricing_date_valid;
ALTER TABLE fsn.pricing  ADD CONSTRAINT CK_pricing_date_valid 
CHECK (effective_date >= '2026-01-01' AND effective_date <= CURRENT_TIMESTAMP);

-- Ensures that sales cant belogged in future and are also within timeline
ALTER TABLE fsn.sales  DROP CONSTRAINT IF EXISTS CK_sale_time_date_valid;
ALTER TABLE fsn.sales  ADD CONSTRAINT CK_sale_time_date_valid 
CHECK (sale_time >= '2026-01-01 00:00:00+04'AND sale_time <= CURRENT_TIMESTAMP); 

-- inventory_log logic, if its sale delivery_id is null and vice-versa
ALTER TABLE fsn.inventory_logs DROP CONSTRAINT IF EXISTS CK_log_type_exclusivity;
ALTER TABLE fsn.inventory_logs ADD CONSTRAINT CK_log_type_exclusivity 
CHECK (
    (sale_id IS NOT NULL AND delivery_id IS NULL) OR 
    (sale_id IS NULL AND delivery_id IS NOT NULL)
);

-- Prevents impossible tank sizes
ALTER TABLE fsn.tanks DROP CONSTRAINT IF EXISTS CK_tank_min_capacity;
ALTER TABLE fsn.tanks ADD CONSTRAINT CK_tank_min_capacity 
CHECK (max_capacity > 0);

-- Prevents impossible sales
ALTER TABLE fsn.sales DROP CONSTRAINT IF EXISTS CK_sales_positive_values;
ALTER TABLE fsn.sales ADD CONSTRAINT CK_sales_positive_values 
CHECK (quantity_sold > 0 AND total_amount >= 0);

-- Cant have negative numbers in the remaining stock
ALTER TABLE fsn.inventory_logs DROP CONSTRAINT IF EXISTS CK_empthy_remaining_stock;
ALTER TABLE fsn.inventory_logs ADD CONSTRAINT CK_empthy_remaining_stock 
CHECK (remaining_stock >= 0)
;

-- Price cant be negative
ALTER TABLE fsn.pricing DROP CONSTRAINT IF EXISTS CK_price_must_be_positive;
ALTER TABLE fsn.pricing ADD CONSTRAINT CK_price_must_be_positive 
CHECK (price_per_unit > 0);


-- Loyalty level according to logic
ALTER TABLE fsn.loyalty_tiers DROP CONSTRAINT IF EXISTS CK_standard_tier_names;
ALTER TABLE fsn.loyalty_tiers ADD CONSTRAINT CK_standard_tier_names 
CHECK (loyalty_tier_description IN ('Bronze', 'Silver', 'Gold', 'Platinum','VIP', 'None'));

-- We need a trigger for remaining_stock in inventory_logs to function properly. We create function and bind it to a column with trigger 
CREATE OR REPLACE FUNCTION fsn.calculate_remaining_stock()
RETURNS TRIGGER AS $$
DECLARE
    last_stock DECIMAL(12, 2);
BEGIN
    -- Get the latest remaining stock for this specific tank
    SELECT remaining_stock INTO last_stock
    FROM fsn.inventory_logs
    WHERE tank_id = NEW.tank_id -- NEW reffers to data that is not saved yet but is passed in insert statment
    ORDER BY log_timestamp DESC, inventory_log_id DESC
    LIMIT 1;

    -- If this is the first entry for the tank, start at 0
    IF last_stock IS NULL THEN
        last_stock := 0;
    END IF;

    -- Set the new remaining stock
    NEW.remaining_stock := last_stock + NEW.change_amount;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--Creating trigger

DROP TRIGGER IF EXISTS trg_update_stock ON fsn.inventory_logs;
CREATE TRIGGER trg_update_stock 
BEFORE INSERT ON fsn.inventory_logs
FOR EACH ROW
EXECUTE FUNCTION fsn.calculate_remaining_stock();

-- We need another trigger so the total_amount column in Sales table functions properly. Since we cant need to look price for unit in separete table function+trigger are used.

CREATE OR REPLACE FUNCTION fsn.calculate_sale_total()
RETURNS TRIGGER AS $$
DECLARE
    current_unit_price DECIMAL(10, 2);
BEGIN
    -- 1. Look up the price from the pricing table linked to this sale
    SELECT price_per_unit INTO current_unit_price
    FROM fsn.pricing
    WHERE pricing_id = NEW.pricing_id;

    -- 2. Calculate the total (Price * Quantity)
    NEW.total_amount := current_unit_price * NEW.quantity_sold;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Rerunnable Trigger Setup
DROP TRIGGER IF EXISTS trg_calculate_sale_total ON fsn.sales;
CREATE TRIGGER trg_calculate_sale_total
BEFORE INSERT ON fsn.sales
FOR EACH ROW
EXECUTE FUNCTION fsn.calculate_sale_total();

/*We insert the values. Parents first, child tables second*/


-- 1. Locations 
INSERT INTO fsn.location (location_description) VALUES 
('Tbilisi - Vake'), ('Tbilisi - Saburtalo'), ('Batumi - Port'), 
('Kutaisi - Center'), ('Rustavi - Highway'), ('Gori - Entrance')
ON CONFLICT (location_description) DO NOTHING;

-- 2. Roles
INSERT INTO fsn.roles (role_description) VALUES 
('Manager'), ('Cashier'), ('Attendant'), ('Mechanic'), ('Security'), ('Regional Supervisor')
ON CONFLICT (role_description) DO NOTHING;

-- 3. Loyalty Tiers 
INSERT INTO fsn.loyalty_tiers (loyalty_tier_description) VALUES 
('None'), ('Bronze'), ('Silver'), ('Gold'), ('Platinum'), ('VIP')
ON CONFLICT (loyalty_tier_description) DO NOTHING;

-- 4. Payment Methods
INSERT INTO fsn.payment_method (payment_method_description) VALUES 
('Cash'), ('Credit Card'), ('Debit Card'), ('Apple Pay'), ('Fleet Card'), ('Mobile App')
ON CONFLICT (payment_method_description) DO NOTHING;

-- 5. Fuel Types
INSERT INTO fsn.fuel_types (fuel_description) VALUES 
('Regular 92'), ('Premium 95'), ('Super 98'), ('Diesel'), ('Eco-Diesel'), ('LPG')
ON CONFLICT (fuel_description) DO NOTHING;

-- 6. Suppliers 
INSERT INTO fsn.supplier (company_name, contact_info) VALUES 
('Gulf Oil', 'contact@gulf.ge'), ('Wissol', 'info@wissol.ge'), 
('SOCAR', 'support@socar.ge'), ('Rompetrol', 'office@rompetrol.ge'), 
('Lukoil', 'hr@lukoil.ge'), ('Local Biofuel Co', 'bio@local.ge')
ON CONFLICT (company_name) DO NOTHING;

-- Child tables
-- 7. Customers 
INSERT INTO fsn.customers (full_name, email, loyalty_tier_id) 
VALUES 
    ('Giorgi Beridze', 'gberidze@gmail.com', (SELECT loyalty_tier_id FROM fsn.loyalty_tiers WHERE loyalty_tier_description = 'Gold')),
    ('Nino Makharadze', 'nmako@gmail.com', (SELECT loyalty_tier_id FROM fsn.loyalty_tiers WHERE loyalty_tier_description = 'Silver')),
    ('David Kapianidze', 'dakapana@gmail.com', (SELECT loyalty_tier_id FROM fsn.loyalty_tiers WHERE loyalty_tier_description = 'Bronze')),
    ('Luka Meskhi', 'luka2000@gmail.com', (SELECT loyalty_tier_id FROM fsn.loyalty_tiers WHERE loyalty_tier_description = 'None')),
    ('Mariya Volski', 'mariko@gmail.com', (SELECT loyalty_tier_id FROM fsn.loyalty_tiers WHERE loyalty_tier_description = 'Platinum')),
    ('Anano Tskhadadze', 'anna1221@gmail.com', (SELECT loyalty_tier_id FROM fsn.loyalty_tiers WHERE loyalty_tier_description = 'None'))
ON CONFLICT (email) DO NOTHING;

-- 8. Fuel stations
INSERT INTO fsn.fuel_station (station_name, location_id) 
VALUES 
    ('Vake Premium', (SELECT location_id FROM fsn.location WHERE location_description = 'Tbilisi - Vake')),
    ('Saburtalo Express', (SELECT location_id FROM fsn.location WHERE location_description = 'Tbilisi - Saburtalo')),
    ('Batumi Coastal', (SELECT location_id FROM fsn.location WHERE location_description = 'Batumi - Port')),
    ('Kutaisi Central', (SELECT location_id FROM fsn.location WHERE location_description = 'Kutaisi - Center')),
    ('Rustavi Transit', (SELECT location_id FROM fsn.location WHERE location_description = 'Rustavi - Highway')),
    ('Gori Hub', (SELECT location_id FROM fsn.location WHERE location_description = 'Gori - Entrance'))
ON CONFLICT DO nothing;

-- 9. Employees 


INSERT INTO fsn.employees (station_id, role_id, first_name, last_name)
VALUES 
((SELECT station_id FROM fsn.fuel_station WHERE station_name = 'Vake Premium'),(SELECT role_id FROM fsn.roles WHERE role_description = 'Manager'), 'Levan', 'Abashidze'),
((SELECT station_id FROM fsn.fuel_station WHERE station_name = 'Vake Premium'), (SELECT role_id FROM fsn.roles WHERE role_description = 'Cashier'), 'Tamta', 'Gagua'),
((SELECT station_id FROM fsn.fuel_station WHERE station_name = 'Saburtalo Express'), (SELECT role_id FROM fsn.roles WHERE role_description = 'Cashier'), 'Irakli', 'Koberidze'),
((SELECT station_id FROM fsn.fuel_station WHERE station_name = 'Batumi Coastal'), (SELECT role_id FROM fsn.roles WHERE role_description = 'Attendant'), 'Sandro', 'Bakradze'),
((SELECT station_id FROM fsn.fuel_station WHERE station_name = 'Kutaisi Central'), (SELECT role_id FROM fsn.roles WHERE role_description = 'Manager'), 'Eka', 'Dvali'),
((SELECT station_id FROM fsn.fuel_station WHERE station_name = 'Rustavi Transit'), (SELECT role_id FROM fsn.roles WHERE role_description = 'Security'), 'Vano', 'Meli')
ON CONFLICT DO NOTHING;

-- 10.Tanks   
INSERT INTO fsn.tanks (station_id, max_capacity)
SELECT station_id, 50000.00 -- All tanks with same capacity
FROM fsn.fuel_station
ON CONFLICT DO NOTHING;

-- 11 Deliveries IMPORTANT NOTE: random() and generate_series() scripts used here and next in query is dbms specific. 
-- It will not work in MySQL / MariaDB and SQL Server (T-SQL). But I decided that it is appropriate way to avoid duplicates and add realistic data
INSERT INTO fsn.delivery (supplier_id, quantity_received, cost_per_unit, delivery_date)
SELECT 
    (SELECT supplier_id FROM fsn.supplier ORDER BY RANDOM() LIMIT 1), -- Randoms create random values in a range so we are there are no duplicates
    (random() * 5000 + 5000)::DECIMAL(12,2),
    (random() * 0.5 + 2.0)::DECIMAL(10,2),
    CAST(date_trunc('day', NOW() - (interval '15 days' * s.i)) AS DATE)
FROM generate_series(0, 5) AS s(i)
ON CONFLICT DO NOTHING;

-- 12. Pricings 
INSERT INTO fsn.pricing (station_id, fuel_type_id, price_per_unit, effective_date)
SELECT 
    s.station_id, 
    f.fuel_type_id, 
    (2.50 + (random() * 1.5))::DECIMAL(10,2), -- Generates a price between 2.50 and 4.00
    '2026-01-01' -- Set to the start of the year so it covers the last 3 months
FROM fsn.fuel_station s
CROSS JOIN fsn.fuel_types f -- This creates every possible combination
ON CONFLICT DO NOTHING;

-- 13 Sales 
INSERT INTO fsn.sales (customer_id, pricing_id, employee_id, payment_method_id, quantity_sold, sale_time)
SELECT 
    (SELECT customer_id FROM fsn.customers ORDER BY RANDOM() LIMIT 1),
    (SELECT pricing_id FROM fsn.pricing ORDER BY RANDOM() LIMIT 1),
    (SELECT employee_id FROM fsn.employees ORDER BY RANDOM() LIMIT 1),
    (SELECT payment_method_id FROM fsn.payment_method ORDER BY RANDOM() LIMIT 1),
    (random() * 50 + 5)::DECIMAL(12,2),
    CAST(date_trunc('day', NOW() - (interval '18 days' * s.i)) AS DATE)
FROM generate_series(0, 5) AS s(i); -- Creates random sales

--14. Logs informtion. IMPORTANT: Since contraint prevents negative numbers in remaining stock its crucial to run deliveries part first. 
-- Logs for Deliveries
INSERT INTO fsn.inventory_logs (tank_id, fuel_type_id, change_amount, sale_id, delivery_id)
SELECT 
    (SELECT tank_id FROM fsn.tanks LIMIT 1),
    (SELECT fuel_type_id FROM fsn.fuel_types LIMIT 1),
    quantity_received,
    NULL,
    delivery_id
FROM fsn.delivery
LIMIT 6;
-- Logs for sales
INSERT INTO fsn.inventory_logs (tank_id, fuel_type_id, change_amount, sale_id, delivery_id)
SELECT 
    (SELECT tank_id FROM fsn.tanks LIMIT 1),
    (SELECT fuel_type_id FROM fsn.fuel_types LIMIT 1),
    -quantity_sold,
    sale_id,
    NULL
FROM fsn.sales
LIMIT 6;

/* Creating task functions */
-- 1. Function that accepts PK, name of column and value. To make it work we need a function to specify the table and PK column
CREATE OR REPLACE FUNCTION fsn.update_any_table_column(
    p_table_name TEXT, 
    p_column_name TEXT, 
    p_new_value TEXT, -- New value is encoded as TEXT and should be recieved in quotes. This makes changing rows with text as well as with integers possible
    p_pk_column TEXT,
    p_pk_value INT
)
RETURNS VOID AS $$
BEGIN
    EXECUTE format(
        'UPDATE fsn.%I SET %I = %L WHERE %I = %s',
        p_table_name, 
        p_column_name, 
        p_new_value, 
        p_pk_column, 
        p_pk_value);
    RAISE NOTICE 'Dynamic Update: fsn.%I (ID: %) set % to %', 
                 p_table_name, p_pk_value, p_column_name, p_new_value;
END;
$$ LANGUAGE plpgsql;
-- Example of how function in action. 
SELECT fsn.update_any_table_column('delivery','cost_per_unit', '5' , 'delivery_id',6); 
SELECT fsn.update_any_table_column('fuel_station', 'station_name', 'Vake Premium','station_id', 1);

-- 2. Create a function that adds a record in transaction table

CREATE OR REPLACE FUNCTION fsn.add_fuel_sale(
    p_customer_full_name TEXT, -- Customer full name
    p_customer_email TEXT,     -- Email - needed for uniquely identifying
    p_station_name TEXT, -- sation name
    p_fuel_type TEXT, -- fuel type
    p_employee_last_name TEXT, -- Name of employee
    p_payment_method TEXT, -- Payment method
    p_quantity_sold DECIMAL(12,2) -- Quantity sold
)
RETURNS VOID AS $$
DECLARE
    v_pricing_id INT;
    v_customer_id INT;
    v_employee_id INT;
    v_payment_id INT;
    v_station_exists INT;
    v_fuel_exists INT;
BEGIN
    -- 1. Resolve Customer using BOTH Name and Email for uniqueness
    IF p_customer_email IS NOT NULL THEN
        SELECT customer_id INTO v_customer_id 
        FROM fsn.customers 
        WHERE full_name = p_customer_full_name 
          AND email = p_customer_email;
    END IF;
    
    -- If no unique match found, proceed as Guest
    IF v_customer_id IS NULL THEN
        RAISE NOTICE 'No unique match for % (%). Proceeding as Guest sale.', 
                     p_customer_full_name, p_customer_email;
    END IF;

    -- 2. Mandatory Lookups (Payment, Employee, Station, Fuel)
    SELECT payment_method_id INTO v_payment_id FROM fsn.payment_method WHERE payment_method_description = p_payment_method;
    IF v_payment_id IS NULL THEN RAISE EXCEPTION 'Payment method "%" not found.', p_payment_method; END IF;
    
    SELECT employee_id INTO v_employee_id FROM fsn.employees WHERE last_name = p_employee_last_name LIMIT 1;
    IF v_employee_id IS NULL THEN RAISE EXCEPTION 'Employee "%" not found.', p_employee_last_name; END IF;

    SELECT station_id INTO v_station_exists FROM fsn.fuel_station WHERE station_name = p_station_name;
    IF v_station_exists IS NULL THEN RAISE EXCEPTION 'Station "%" not found.', p_station_name; END IF;

    SELECT fuel_type_id INTO v_fuel_exists FROM fsn.fuel_types WHERE fuel_description = p_fuel_type;
    IF v_fuel_exists IS NULL THEN RAISE EXCEPTION 'Fuel type "%" not found.', p_fuel_type; END IF;

    -- 3. Get Pricing
    SELECT pricing_id INTO v_pricing_id FROM fsn.pricing 
    WHERE station_id = v_station_exists AND fuel_type_id = v_fuel_exists
    ORDER BY effective_date DESC LIMIT 1;

    IF v_pricing_id IS NULL THEN
        RAISE EXCEPTION 'No price set for % at %.', p_fuel_type, p_station_name;
    END IF;

    -- 4. Insert Sale
    INSERT INTO fsn.sales (customer_id, pricing_id, employee_id, payment_method_id, quantity_sold)
    VALUES (v_customer_id, v_pricing_id, v_employee_id, v_payment_id, p_quantity_sold);

    RAISE NOTICE 'Sale recorded. Total calculated by trigger. Inventory updated by trigger.';

END;
$$ LANGUAGE plpgsql;

-- Example of function in action

SELECT fsn.add_fuel_sale( -- We insert the customer with loyalty
    'Giorgi Beridze', 
    'gberidze@gmail.com',
    'Vake Premium', 
    'Regular 92', 
    'Abashidze', 
    'Credit Card', 
    39.99
);

SELECT fsn.add_fuel_sale( -- We insert the customer that just happens to have same name but email check turn his record into guest record
    'Giorgi Beridze', 
    'giorgi.b88@gmail.com',
    'Vake Premium', 
    'Regular 92', 
    'Abashidze', 
    'Credit Card', 
    30.00
);

SELECT fsn.add_fuel_sale( -- We insert the guest customer that left no personal info
    NULL, 
    NULL, 
    'Vake Premium', 
    'Regular 92', 
    'Abashidze', 
    'Cash', 
    15.00
);

/* Creating a view that presents analytics for the most recently added quarter in database*/

CREATE OR REPLACE VIEW fsn.vw_latest_quarter_analytics AS
WITH latest_quarter AS (
    -- Identify the most recent quarter present in the database
    SELECT 
        DATE_TRUNC('quarter', MAX(sales.sale_time)) as start_of_quarter
    FROM fsn.sales
)
SELECT 
    s.station_name AS "Station",
    f.fuel_description AS "Fuel Type",
    COUNT(sa.sale_id) AS "Total Transactions",
    SUM(sa.quantity_sold) AS "Volume Sold (Litre)",
    SUM(sa.total_amount) AS "Gross Revenue",
    ROUND(AVG(sa.total_amount), 2) AS "Average Transaction Value",
    -- Identifies the Quarter and Year for context
    TO_CHAR((SELECT start_of_quarter FROM latest_quarter), 'YYYY "Q"Q') AS "Period"
FROM fsn.sales sa
JOIN fsn.pricing p ON sa.pricing_id = p.pricing_id
JOIN fsn.fuel_station s ON p.station_id = s.station_id
JOIN fsn.fuel_types f ON p.fuel_type_id = f.fuel_type_id
WHERE DATE_TRUNC('quarter', sa.sale_time) = (SELECT start_of_quarter FROM latest_quarter)
GROUP BY s.station_name, f.fuel_description, "Period"
ORDER BY "Gross Revenue" DESC;

SELECT * FROM fsn.vw_latest_quarter_analytics;

/*Creating a read-only role for the manager*/

CREATE ROLE manager_read_only WITH 
    LOGIN 
    PASSWORD '123456789'
    CONNECTION LIMIT -1;


GRANT USAGE ON SCHEMA fsn TO manager_read_only;-- Allow the manager to use schem

-- Grant read-only access to all current tables
GRANT SELECT ON ALL TABLES IN SCHEMA fsn TO manager_read_only;

-- grant SELECT on all current views
GRANT SELECT ON ALL SEQUENCES IN SCHEMA fsn TO manager_read_only;