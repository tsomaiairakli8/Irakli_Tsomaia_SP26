/*Task 2. Implement role-based authentication model for dvd_rental database
 * */

-- Creating user "rentaluser" with the password "rentalpassword"

CREATE ROLE rentaluser WITH 
    LOGIN                   
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    INHERIT   
    NOREPLICATION
    NOBYPASSRLS
    CONNECTION LIMIT -1
    PASSWORD 'rentalpassword';


-- Grant connection and schema usage
GRANT CONNECT ON DATABASE dvdrental TO rentaluser;
GRANT USAGE ON SCHEMA public TO rentaluser;

-- Grant select to user
GRANT SELECT ON TABLE customer TO rentaluser;

-- Use rentaluser role
SET ROLE rentaluser;  SELECT current_user;

SELECT  * FROM customer -- Selection of customers works

SELECT  * FROM film -- SQL Error [42501]: ERROR: permission denied for table film


SET ROLE postgres; -- We select role as postgres again because rentaluser cant create roles

-- Creating group called 'rental'
CREATE ROLE rental;

-- Adding rentaluser to the group
GRANT rental TO rentaluser;

-- Grant permissions to the group
GRANT SELECT, INSERT, UPDATE ON TABLE rental TO rental;
GRANT USAGE ON SCHEMA public TO rental;
GRANT USAGE, SELECT ON SEQUENCE rental_rental_id_seq TO rental; -- We have to grant usage on the rental_rental_id_seq to allow auto-incrementing IDs

-- Use rentaluser role again
SET ROLE rentaluser;

-- Insert rows as rentaluser and updating it
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id) -- Works
VALUES (NOW(), 1, 1, NOW() + INTERVAL '10 days', 1);

UPDATE rental SET return_date = NOW() WHERE rental_id = 1; -- Works

-- SET ROLE postgres; needed before this
-- Revoking insert privilege from rental group
REVOKE INSERT ON TABLE rental FROM rental;

-- SET ROLE rentaluser; needed after this

-- Insert without privilege
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id) -- SQL Error [42501]: ERROR: permission denied for table rental
VALUES (NOW(), 1, 1, NOW() + INTERVAL '7 days', 1);

-- Creating a personalized role for any customer. postgres role is used




DO $$ -- Since non-hardcoded aproaches are preferable I use function and a subquery
DECLARE 
    target_id INT;
    f_name TEXT;
    l_name TEXT;
    role_name TEXT;
BEGIN
    -- 1. Use a subquery to find a customer with payments and rentals
    SELECT c.customer_id, LOWER(c.first_name), LOWER(c.last_name)   -- This finds customer mary smith
    INTO target_id, f_name, l_name
    FROM customer c
    WHERE EXISTS (SELECT 1 FROM rental r WHERE r.customer_id = c.customer_id)
      AND EXISTS (SELECT 1 FROM payment p WHERE p.customer_id = c.customer_id)
    LIMIT 1;

    -- 2. Construct the role name
    role_name := 'client_' || f_name || '_' || l_name;

    -- 3. Execute Dynamic SQL to create the role
    EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', role_name, 'customerpass');

    -- 4. Grant permissions
    EXECUTE format('GRANT SELECT ON customer, rental, payment TO %I', role_name);

    -- 5. Enable RLS and create the policy
    EXECUTE 'ALTER TABLE rental ENABLE ROW LEVEL SECURITY';
    
    -- Using the target_id found in the subquery for the policy logic
    EXECUTE format('
        CREATE POLICY customer_rental_policy ON rental
        FOR SELECT TO %I
        USING (customer_id = %L)', role_name, target_id);

    RAISE NOTICE 'Created role and policy for: % (ID: %)', role_name, target_id;
END $$;


/*Task 3. Implement row-level security for clinet_mary_smith*/

-- We enable the RLS on tables
ALTER TABLE rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment ENABLE ROW LEVEL SECURITY;
   
--Creating policy for rental table

CREATE POLICY rental_select_policy ON rental
FOR SELECT
TO client_mary_smith
USING (
    customer_id = (SELECT customer_id FROM customer 
                   WHERE 'client_' || lower(first_name) || '_' || lower(last_name) = current_user));

--Creating policy for payment table
CREATE POLICY payment_select_policy ON payment
FOR SELECT
TO client_mary_smith
USING (
    customer_id = (SELECT customer_id FROM customer 
                   WHERE 'client_' || lower(first_name) || '_' || lower(last_name) = current_user));

-- Testing the RLS as client_mary_smith

SET ROLE client_mary_smith;

SELECT * FROM rental r -- 76 rows returned since there are 76 records of this user in rental
SELECT * FROM payment -- 64 rows returned since there are 64 records of this user in payment
SELECT * FROM film --SQL Error [42501]: ERROR: permission denied for table film
/*Comment: If we specify the other users records as client_mary_smith in rental or payment table it will return empty table. Other rows are hidden in that case*/
SELECT * FROM payment
WHERE customer_id = 2 -- Returns zero rows

