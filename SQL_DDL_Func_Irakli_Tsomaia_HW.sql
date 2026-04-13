/*Task 1 : Creating view of sales by category in current quarter
 * Notes: CREATE OR REPLACE is used for rerunnability
 * Current quarter and year is extracted by using EXTRACT FROM CURRENT_DATE in where clause
 * Inner joins make sure that both null values and  zero-sales categories are excluded
 * This query returns empry table when used since now its April and there are no payments in this quarter
 * In order to test view I changed CURRENT_DATE to (SELECT EXTRACT(YEAR FROM MIN(payment_date)) FROM payment) and (SELECT EXTRACT(QUARTER FROM MIN(payment_date)) FROM payment) accordingly
 * Data that should not appear: Historical data from previous years
 *  */

CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS

SELECT 
    c.name AS category_name,
    SUM(p.amount) AS total_revenue,
    EXTRACT(QUARTER FROM p.payment_date) AS current_quarter,
    EXTRACT(YEAR FROM p.payment_date) AS current_year
FROM category c
INNER JOIN film_category fc ON c.category_id = fc.category_id
INNER JOIN inventory i ON fc.film_id = i.film_id
INNER JOIN rental r ON i.inventory_id = r.inventory_id
INNER JOIN payment p ON r.rental_id = p.rental_id
WHERE 
    EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
    AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
GROUP BY 
    c.name, 
    EXTRACT(QUARTER FROM p.payment_date), 
    EXTRACT(YEAR FROM p.payment_date);

SELECT  * FROM public.sales_revenue_by_category_qtr


/*Task 2: Create a query language functions
 * Integer parameters are used to allow precise filtering of historical or current data.
 * We use DECLARE EXTRACT(YEAR FROM CURRENT_DATE). This allows the function to accept any year from 2000 up to the current calendar year, 
 * preventing users from querying future years where data cannot possibly exist.
 *  If no payments match the year/quarter, the result set is empty. This is expected behavior for a sales report.
 * 
 * */

CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr(
    p_year INTEGER, 
    p_quarter INTEGER
)
RETURNS TABLE (
    category_name TEXT,
    total_revenue NUMERIC,
    result_quarter INTEGER,
    result_year INTEGER
) AS $$

DECLARE
    current_yr INTEGER := EXTRACT(YEAR FROM CURRENT_DATE);
BEGIN
    --  Validate Quarter Input
    IF p_quarter < 1 OR p_quarter > 4 THEN
        RAISE EXCEPTION 'Invalid Input: Quarter must be between 1 and 4. Received: %', p_quarter; -- Message that is shown if invalid quarter is passed
    END IF;

    IF p_year < 2000 OR p_year > current_yr THEN
        RAISE EXCEPTION 'Invalid Input: Year % is invalid. Please select a year between 2000 and %.', p_year, current_yr; -- Message that is shown if invalid year is passed
    END IF;

    RETURN QUERY
    SELECT 
        c.name::TEXT,
        SUM(p.amount),
        EXTRACT(QUARTER FROM p.payment_date)::INTEGER,
        EXTRACT(YEAR FROM p.payment_date)::INTEGER
    FROM category c
    INNER JOIN film_category fc ON c.category_id = fc.category_id
    INNER JOIN inventory i ON fc.film_id = i.film_id
    INNER JOIN rental r ON i.inventory_id = r.inventory_id
    INNER JOIN payment p ON r.rental_id = p.rental_id
    WHERE 
        EXTRACT(YEAR FROM p.payment_date) = p_year
        AND EXTRACT(QUARTER FROM p.payment_date) = p_quarter
    GROUP BY 
        c.name, 
        EXTRACT(QUARTER FROM p.payment_date), 
        EXTRACT(YEAR FROM p.payment_date);

    IF NOT FOUND THEN -- Message that is shown if no data is found
        RAISE NOTICE 'No sales data found for Year: %, Quarter: %', p_year, p_quarter;
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM public.get_sales_revenue_by_category_qtr(2017, 1); -- Correct test query
SELECT * FROM public.get_sales_revenue_by_category_qtr(2039, 2); -- Incorrect test query




/*Task 3: Create procedure language functions most_popular_films_by_countries
 * We use a CTE (film_counts) to first aggregate all rentals by country and film.
 * Then, we filter that CTE by comparing each count to a second subquery that finds the MAX count for that specific country.
 * Most popular = most rental count
 * In case of ties: If multiple films share the MAX rental count, all are returned.
 * */
CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(p_countries TEXT[])
RETURNS TABLE (
    country TEXT,
    film TEXT,
    rating TEXT,
    language TEXT,
    length_in_mins INTEGER,
    release_year INTEGER
) AS $$

BEGIN
    RETURN QUERY
    WITH film_counts AS (
        -- Step 1: Get rental counts for every film in the target countries
        SELECT 
            co.country_id,
            co.country::TEXT as country_name,
            f.title::TEXT as film_title,
            f.rating::TEXT as film_rating,
            l.name::TEXT as lang_name,
            f.length::INTEGER as f_len,
            f.release_year::INTEGER as f_year,
            COUNT(r.rental_id) as rental_count
        FROM country co
        JOIN city ci ON co.country_id = ci.country_id
        JOIN address a ON ci.city_id = a.city_id
        JOIN customer cu ON a.address_id = cu.address_id
        JOIN rental r ON cu.customer_id = r.customer_id
        JOIN inventory i ON r.inventory_id = i.inventory_id
        JOIN film f ON i.film_id = f.film_id
        JOIN language l ON f.language_id = l.language_id
        WHERE co.country = ANY(p_countries)
        GROUP BY 
            co.country_id, co.country, f.film_id, f.title, 
            f.rating, l.name, f.length, f.release_year
    )
    -- Step 2: Select only those films that match the maximum count for their country
    SELECT 
        fc.country_name,
        fc.film_title,
        fc.film_rating,
        fc.lang_name,
        fc.f_len,
        fc.f_year
    FROM film_counts fc
    WHERE fc.rental_count = (
        SELECT MAX(fc2.rental_count)
        FROM film_counts fc2
        WHERE fc2.country_id = fc.country_id
    );

    IF NOT FOUND THEN
        RAISE NOTICE 'No data found for the provided countries.'; -- Message that is shown if there is no data fro country or the invalid country is entered in parameter
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM  public.most_popular_films_by_countries(ARRAY['United Arab Emirates', 'Turkey']); -- Correct test query
SELECT * FROM  public.most_popular_films_by_countries(ARRAY['Narnia', 'Nonexistantcountry']); -- Incorrect test query



/*Task 4: Create procedure language functions
 * Aftr googling I decide to use ILIKE for case-insensitive matching. The '%' wildcards allow for partial title discovery.
 * Sequence is created to make a column row_num, and it restarts after each use of function
 * Performance: Sequence may be slow due to scanning the whole table. For minimizing processing, the sequence is dropped immediately after use, ensuring it doesn't clutter the system catalog
 * Multiple or no matches: Every matching rental gets a sequential number from the sequence. If no matches found - the sequence is created and dropped, but the result remains empty, and a NOTICE is issued.
 * 
 */
 * */
CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(p_title_pattern TEXT)
RETURNS TABLE (
    row_num BIGINT,
    film_title TEXT,
    language TEXT,
    customer_name TEXT,
    rental_date TIMESTAMP
) AS $$

 *
 * MULTIPLE/NO MATCHES:
 * 1. Multiple: Every matching rental gets a sequential number from the sequence.
 * 2. No Matches: The sequence is created and dropped, but the result set 
 * remains empty, and a NOTICE is issued.
 */
BEGIN
    -- Create a temporary sequence that only exists for this session/call
    CREATE TEMPORARY SEQUENCE IF NOT EXISTS temp_row_seq START 1;
    -- Reset in case it was used previously in the same session
    ALTER SEQUENCE temp_row_seq RESTART WITH 1;

    RETURN QUERY
    SELECT 
        nextval('temp_row_seq')::BIGINT,
        f.title::TEXT,
        l.name::TEXT,
        (c.first_name || ' ' || c.last_name)::TEXT as customer_name,
        r.rental_date::TIMESTAMP
    FROM film f
    JOIN language l ON f.language_id = l.language_id
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN customer c ON r.customer_id = c.customer_id
    WHERE f.title ILIKE p_title_pattern
    ORDER BY r.rental_date DESC;

    
    DROP SEQUENCE temp_row_seq; -- Cleanup: Remove the sequence after the result is generated

    IF NOT FOUND THEN
        RAISE NOTICE 'No movies matching pattern "%" were found in stock.', p_title_pattern;  -- Message that is shown if there is no pattern in stock
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM public.films_in_stock_by_title('%boy%') -- Correct test query
SELECT * FROM public.films_in_stock_by_title('%nonexistaantstring%') -- Incorrect test query



/*Task 5: Create procedure language functions
 * Unique id generation:  In the schema, the 'film_id' column is a SERIAL type. By omitting 'film_id' from the INSERT statement, PostgreSQL automatically fetches the next value from the underlying sequence, ensuring a unique ID.
 * Dealing with duplicates: We perform an explicit check using IF EXISTS. By using UPPER(), we ensure that titles are unique regardless of case (e.g., 'Movie' vs 'movie').
 * If movie already exists: function triggers RAISE EXCEPTION that stops query and notifies user
 * Language validation: language_id is retrieved and if result is NULL an exception is raised
 * Insertion failure: If any part of the function (duplicate check, language check, or the  INSERT itself) fails, the entire transaction is rolled back.
 * Consistency: Chain of RAISE EXCEPTION-s prevent us from adding inconsistant data and keep databse in valid state
 * */
CREATE OR REPLACE FUNCTION public.new_movie(
    p_title TEXT,
    p_release_year INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
    p_language_name TEXT DEFAULT 'Klingon'
)
RETURNS VOID AS $$

DECLARE
    v_language_id INTEGER;
BEGIN
    --  Check for duplicate movie titles
    IF EXISTS (SELECT 1 FROM film WHERE UPPER(title) = UPPER(p_title)) THEN
        RAISE EXCEPTION 'Duplicate Error: Movie title "%" already exists.', p_title; -- Message that is shown if movie already exists
    END IF;

    -- Validate language existence
    SELECT language_id INTO v_language_id 
    FROM language 
    WHERE TRIM(UPPER(name)) = TRIM(UPPER(p_language_name));

    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language Error: Language "%" not found in the database.', p_language_name; -- Message that is shown if there is no valid language in database
    END IF;

    -- Insert the new movie
    INSERT INTO film (
        title, 
        release_year, 
        language_id, 
        rental_duration, 
        rental_rate, 
        replacement_cost
    )
    VALUES (
        p_title, 
        p_release_year, 
        v_language_id, 
        3,      -- Rental duration
        4.99,   -- Rental rate
        19.99   -- Replacement cost
    );

    RAISE NOTICE 'Success: Movie "%" added (Year: %, Language: %).', p_title, p_release_year, p_language_name; -- Message that is shown if there are no failures

EXCEPTION
    WHEN OTHERS THEN
        -- Re-raise the caught error to ensure the caller is aware of the failure
        RAISE;
END;
$$ LANGUAGE plpgsql;


SELECT public.new_movie('Data Engineering'); -- This will raise errors because 'Klingon' is not added to default languages table
SELECT public.new_movie('Data Engineering', 2019, 'English'); -- Correct test query

