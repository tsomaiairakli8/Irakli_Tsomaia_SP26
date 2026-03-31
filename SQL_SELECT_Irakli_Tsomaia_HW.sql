-- Task: The marketing team needs a list of animation movies between 2017 and 2019 to promote family-friendly content in an upcoming season in stores
SELECT f.film_id, -- since this task is easy I would choose join method. Its easily readable and fast
       f.title,
       c."name" AS category_name,
       f.rating, -- we need more specifications what family-friendly means exactly
       f.release_year,
       f.rental_rate
FROM   public.film f
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
INNER JOIN public.category c ON fc.category_id = c.category_id
WHERE  c."name" = 'Animation' 
       AND f.release_year BETWEEN 2017 AND 2019
       AND f.rental_rate > 1;
/* 
INNER JOINs are used across all three tables. This is critical because 
a LEFT JOIN would preserve films that don't have a category, but the 
WHERE clause filter on c."name" would discard them anyway, making 
an INNER JOIN more semantically correct and efficient for the optimizer.
*/

WITH TargetCategory AS ( -- CTE is best for readibility and further development of query but since this one is simple I would use simple joins
    -- finding ID to avoid hardcoding in the main join
    SELECT category_id, "name"
    FROM public.category 
    WHERE "name" = 'Animation'
)
SELECT 
    f.film_id, 
    f.title,
    tc."name" AS category_name,
    f.rating,
    f.release_year,
    f.rental_rate
FROM public.film f
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
INNER JOIN TargetCategory tc ON fc.category_id = tc.category_id
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1;

SELECT f.film_id, -- subquery is hardest to read so far. Task is not requiring it and makes no difference in performance. Least preferable query in my opinion
       f.title,
       (SELECT c."name" 
        FROM public.category c 
        WHERE c.category_id = fc.category_id) AS category_name,
       f.rating,
       f.release_year,
       f.rental_rate
FROM   public.film f
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
WHERE  fc.category_id = (SELECT category_id 
                         FROM public.category 
                         WHERE "name" = 'Animation')
       AND f.release_year BETWEEN 2017 AND 2019
       AND f.rental_rate > 1;


/* TASK: Retrieve store IDs, full addresses, and total payment amounts 
   starting from April 1, 2017, ordered by the highest amount.
*/
-- Pure join query is best in performance but since its a little hard to read I would use CTE
SELECT 
    st.store_id,
    a.address || ' ' || COALESCE(a.address2, '') AS full_address,
    SUM(p.amount) AS total_amount
FROM public.payment p
INNER JOIN public.staff s ON p.staff_id = s.staff_id
INNER JOIN public.store st ON s.store_id = st.store_id
INNER JOIN public.address a ON st.address_id = a.address_id
WHERE p.payment_date >= CAST('2017-04-01' AS DATE)
GROUP BY st.store_id, a.address, a.address2
ORDER BY total_amount DESC;

/*  
All joins are INNER. This filters the result set to only include records 
where there is a matching staff member and other parameters
*/

WITH StorePayments AS ( -- Makes best choice for logical, step-by-step understanding of task. My choice for this task
    SELECT 
        s.store_id, 
        p.amount
    FROM public.payment p
    INNER JOIN public.staff s ON p.staff_id = s.staff_id
    WHERE p.payment_date >= CAST('2017-04-01' AS DATE)
)
SELECT 
    sp.store_id,
    a.address || ' ' || COALESCE(a.address2, '') AS full_address,
    SUM(sp.amount) AS total_amount
FROM StorePayments sp
INNER JOIN public.store st ON sp.store_id = st.store_id
INNER JOIN public.address a ON st.address_id = a.address_id
GROUP BY sp.store_id, a.address, a.address2
ORDER BY total_amount DESC;
/* 
 Same logic of joins here
 */

SELECT -- Worst choice is subquery. Bad readibility, will become unreadable if developed further and hard to understand
    sub.store_id,
    (SELECT a.address || ' ' || COALESCE(a.address2, '') 
     FROM public.address a 
     WHERE a.address_id = sub.address_id) AS full_address,
    sub.total_amount
FROM (
    SELECT 
        s.store_id, 
        st.address_id,
        SUM(p.amount) AS total_amount
    FROM public.payment p
    INNER JOIN public.staff s ON p.staff_id = s.staff_id
    INNER JOIN public.store st ON s.store_id = st.store_id
    WHERE p.payment_date >= CAST('2017-04-01' AS DATE)
    GROUP BY s.store_id, st.address_id
) AS sub
ORDER BY total_amount DESC;
/* 
 Same logic of joins here
 */

/* Task: The marketing department in our stores aims to identify the most successful actors since 2015
  to boost customer interest in their films. Show top-5 actors by number of movies (released since 2015) 
  they took part in 
*/

SELECT -- Pure join solution is good for this task but CTE is better in scalability and other people to understand
    a.first_name, 
    a.last_name, 
    COUNT(fa.film_id) AS number_of_movies
FROM public.actor a
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON fa.film_id = f.film_id
WHERE f.release_year > 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_of_movies DESC
LIMIT 5;

/* JOIN TYPE DESCRIPTION: 
INNER JOIN is used across the chain actor -> film_actor -> film. 
If an actor exists but has no movies, or if a movie has no actors, 
those records are excluded from the count. This is the most 
straightforward way to represent a many-to-many relationship.
*/

WITH RecentFilms AS ( -- CTE best solution. Good logical understanding and scalability 
    SELECT film_id 
    FROM public.film 
    WHERE release_year > 2015
),
ActorMovieCounts AS (
    SELECT 
        a.actor_id,
        a.first_name, 
        a.last_name, 
        COUNT(fa.film_id) AS number_of_movies
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN RecentFilms rf ON fa.film_id = rf.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT first_name, last_name, number_of_movies
FROM ActorMovieCounts
ORDER BY number_of_movies DESC
LIMIT 5;
/* 
 Same logic of joins here. A LEFT JOIN would include actors with 0 movies, which 
would likely not appear in the "Top 5" anyway
 */

SELECT  -- Subquery is hard to read and makes more problems than solutions, hard to scale, hard to develop. Last resort 
    a.first_name, 
    a.last_name, 
    COUNT(fa.film_id) AS number_of_movies
FROM public.actor a
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
WHERE fa.film_id IN (
    SELECT film_id 
    FROM public.film 
    WHERE release_year > 2015
)
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_of_movies DESC
LIMIT 5;
/*
 Same logic of joins here. The 
subquery in the WHERE clause acts as a filter, effectively performing the 
work of an INNER JOIN*
 */

/*Task: The marketing team needs to track the production trends of Drama, Travel,
 and Documentary films to inform genre-specific marketing strategies. Show number
 of Drama, Travel, Documentary per year (include columns: release_year, number_of_drama_movies, 
 number_of_travel_movies, number_of_documentary_movies), sorted by release year in descending order */

-- Joins are fine for this taks but for more complex needs and in case of further filtrations CTE is best.
SELECT 
    f.release_year,
    COUNT(*) FILTER (WHERE c."name" = 'Drama') AS number_of_drama_movies,
    COUNT(*) FILTER (WHERE c."name" = 'Travel') AS number_of_travel_movies,
    COUNT(*) FILTER (WHERE c."name" = 'Documentary') AS number_of_documentary_movies
FROM public.film f
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
INNER JOIN public.category c ON fc.category_id = c.category_id
WHERE c."name" IN ('Drama', 'Travel', 'Documentary')
GROUP BY f.release_year
ORDER BY f.release_year DESC;

/* why INNER JOIN: 
All joins are INNER. If we used a LEFT JOIN on 'category', we would 
get rows with NULL category names that would then be ignored by the 
FILTER and WHERE clauses, leading to unnecessary processing overhead.
*/

WITH CategorizedFilms AS ( -- CTE the best choice so far. Good for further development. My choice
    SELECT 
        f.release_year,
        c."name" AS cat_name
    FROM public.film f
    INNER JOIN public.film_category fc ON f.film_id = fc.film_id
    INNER JOIN public.category c ON fc.category_id = c.category_id
    WHERE c."name" IN ('Drama', 'Travel', 'Documentary')
)
SELECT 
    release_year,
    COUNT(*) FILTER (WHERE cat_name = 'Drama') AS number_of_drama_movies,
    COUNT(*) FILTER (WHERE cat_name = 'Travel') AS number_of_travel_movies,
    COUNT(*) FILTER (WHERE cat_name = 'Documentary') AS number_of_documentary_movies
FROM CategorizedFilms
GROUP BY release_year
ORDER BY release_year DESC;
/* Same join logic, helps to deal with nulls*/

SELECT -- Subquery makes it hard to read and understand. Will become a problem if developed further
    der.release_year,
    COUNT(*) FILTER (WHERE der.cat_name = 'Drama') AS number_of_drama_movies,
    COUNT(*) FILTER (WHERE der.cat_name = 'Travel') AS number_of_travel_movies,
    COUNT(*) FILTER (WHERE der.cat_name = 'Documentary') AS number_of_documentary_movies
FROM (
    SELECT 
        f.release_year,
        c."name" AS cat_name
    FROM public.film f
    INNER JOIN public.film_category fc ON f.film_id = fc.film_id
    INNER JOIN public.category c ON fc.category_id = c.category_id
    WHERE c."name" IN ('Drama', 'Travel', 'Documentary')
) AS der
GROUP BY der.release_year
ORDER BY der.release_year DESC;
/* Same join logic, helps to deal with nulls*/

/*Task: The HR department aims to reward top-performing employees in 2017 with bonuses to recognize their 
 * contribution to stores revenue. Show which three employees generated the most revenue in 2017? 
 */
/*This taks is impossible to achieve with pure joins without nested queries and window functions.
  The logic of GROUP BY function prevents it and makes it impossible to query
*/
-- CTE is best choice. High performance and logically easy to understand query when it written step-by step
WITH Staff_Revenue AS (
    SELECT 
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment p
    WHERE p.payment_date BETWEEN '2017-01-01 00:00:00' AND '2017-12-31 23:59:59.999'
    GROUP BY p.staff_id
),
Latest_Payment_ID AS (
    -- We find the specific payment_id of the last transaction in 2017
    SELECT 
        p.staff_id, 
        MAX(p.payment_id) AS last_payment_id
    FROM public.payment p
    WHERE p.payment_date <= '2017-12-31 23:59:59.999'
    GROUP BY p.staff_id
),
Staff_Last_Store AS (
    -- We trace the specific payment back to the store via inventory
    SELECT 
        p.staff_id,
        i.store_id
    FROM public.payment p
    INNER JOIN public.rental r ON p.rental_id = r.rental_id
    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
    INNER JOIN Latest_Payment_ID lpi ON p.payment_id = lpi.last_payment_id
)
SELECT 
    s.first_name,
    s.last_name,
    sls.store_id AS last_assigned_store,
    sr.total_revenue
FROM Staff_Revenue sr
INNER JOIN public.staff s ON sr.staff_id = s.staff_id
INNER JOIN Staff_Last_Store sls ON sr.staff_id = sls.staff_id
ORDER BY sr.total_revenue DESC
LIMIT 3;
-- JOINS are all INNER due to NULL filtration


-- Subquery is extremaly hard to understand, its too complicated and very slow. The more records there will be, the slower it will become
SELECT  
    s.first_name,
    s.last_name,
    i.store_id AS last_assigned_store,
    sr.total_revenue
FROM public.staff s
-- JOIN 1: Get the pre-aggregated revenue for 2017
INNER JOIN (
    SELECT 
        p_sub.staff_id, 
        SUM(p_sub.amount) AS total_revenue
    FROM public.payment p_sub
    WHERE p_sub.payment_date BETWEEN '2017-01-01 00:00:00' AND '2017-12-31 23:59:59.999'
    GROUP BY p_sub.staff_id
) AS sr ON s.staff_id = sr.staff_id
-- JOIN 2: Join to the payment table to find the 'latest' transaction
INNER JOIN public.payment p1 ON s.staff_id = p1.staff_id
-- JOIN 3: Self-join to check if a newer payment exists for the same staff
LEFT JOIN public.payment p2 ON p1.staff_id = p2.staff_id 
    AND p1.payment_id < p2.payment_id 
    AND p2.payment_date <= '2017-12-31 23:59:59.999'
-- JOIN 4 & 5: Trace the specific latest payment to its physical store
INNER JOIN public.rental r ON p1.rental_id = r.rental_id
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
WHERE p2.payment_id IS NULL -- This filters p1 to only the most recent record
  AND p1.payment_date <= '2017-12-31 23:59:59.999'
ORDER BY sr.total_revenue DESC
LIMIT 3;
/*INNER JOIN (sr): Ensures we only process staff with sales in 2017.
 LEFT JOIN (p2): Attempt to find any payment newer than p1.
 IS NULL Filter: By checking if p2.payment_id IS NULL, we logically isolate 
   the row in p1 that has NO newer counterparts—the "latest" one.
*/

/*
 The management team wants to identify the most popular movies and their target audience age groups
  to optimize marketing efforts. Show which 5 movies were rented more than others (number of rentals),
   and what's the expected age of the audience for these movies
 */
-- Pure joins are fine at this stage, they provide good readability and performace. But CTE is suggested in case of query development
SELECT 
    f.title,
    COUNT(r.rental_id) AS rental_count,
    f.rating AS mpaa_rating,
    CASE 
        WHEN f.rating = 'G' THEN 'All Ages'
        WHEN f.rating = 'PG' THEN '8-12 Years'
        WHEN f.rating = 'PG-13' THEN '13-17 Years'
        WHEN f.rating = 'R' THEN '18+ Years'
        WHEN f.rating = 'NC-17' THEN 'Adults Only (18+)'
        ELSE 'Unrated'
    END AS target_audience_age
FROM public.film f
INNER JOIN public.inventory i ON f.film_id = i.film_id
INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title, f.rating
ORDER BY rental_count DESC
LIMIT 5;
/* 
All joins are INNER. If we used a LEFT JOIN on 'inventory', films that were 
never in stock would show up with a rental_count of 0, which would be 
pointless for a "Top 5" report ordered descending.
*/
-- CTE more work to do but it makes query readable and explains well logic making it perfect for scaling. This one is best choice
WITH Film_Rental_Stats AS ( -- cte to group movies by title, rating and so on. Easier to apply casewhens later
    SELECT 
        f.film_id,
        f.title,
        f.rating,
        COUNT(r.rental_id) AS rental_count
    FROM public.film f
    INNER JOIN public.inventory i ON f.film_id = i.film_id
    INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
    GROUP BY f.film_id, f.title, f.rating
)
SELECT 
    title,
    rental_count,
    rating AS mpaa_rating,
    CASE 
        WHEN rating = 'G' THEN 'All Ages'
        WHEN rating = 'PG' THEN '8-12 Years'
        WHEN rating = 'PG-13' THEN '13-17 Years'
        WHEN rating = 'R' THEN '18+ Years'
        WHEN rating = 'NC-17' THEN 'Adults Only (18+)'
        ELSE 'Unrated'
    END AS target_audience_age
FROM Film_Rental_Stats
ORDER BY rental_count DESC
LIMIT 5;
-- Same reasons for joins here. Excluding null values

-- By far worst choice is subqueries. No valuable increase in performance, bad for scaling and readability
SELECT 
    der.title,
    der.rental_count,
    der.rating AS mpaa_rating,
    CASE 
        WHEN der.rating = 'G' THEN 'All Ages'
        WHEN der.rating = 'PG' THEN '8-12 Years'
        WHEN der.rating = 'PG-13' THEN '13-17 Years'
        WHEN der.rating = 'R' THEN '18+ Years'
        WHEN der.rating = 'NC-17' THEN 'Adults Only (18+)'
        ELSE 'Unrated'
    END AS target_audience_age
FROM ( -- Basically same as cte but harder to read
    SELECT 
        f.title, 
        f.rating, 
        COUNT(r.rental_id) AS rental_count
    FROM public.film f
    INNER JOIN public.inventory i ON f.film_id = i.film_id
    INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
    GROUP BY f.film_id, f.title, f.rating
) AS der
ORDER BY der.rental_count DESC
LIMIT 5;
-- same reasoning of joins here, Null and 0 deletion

/* The stores’ marketing team wants to analyze actors' 
inactivity periods to select those with notable career breaks for targeted promotional campaigns
V1: calculate gap between the latest release_year and current year per each actor
*/

-- Pure join approach is doable if we dont count EXTRACT(YEAR FROM CURRENT_DATE) - MAX(f.release_year) as a subquery
SELECT 
    a.first_name,
    a.last_name,
    MAX(f.release_year) AS latest_release,
    (EXTRACT(YEAR FROM CURRENT_DATE) - MAX(f.release_year)) AS years_of_inactivity
FROM public.actor a
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY years_of_inactivity DESC;
-- All joins are INNER. This provides a direct path from actor to film. CURRENT_DATE is used to make query dynamic

-- CTE is best choice because its readability and performance
WITH Actor_Latest_Film AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        MAX(f.release_year) AS latest_release
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
) -- We filter actors by latest movie first
SELECT 
    first_name,
    last_name,
    latest_release,
    (EXTRACT(YEAR FROM CURRENT_DATE) - latest_release) AS years_of_inactivity
FROM Actor_Latest_Film
ORDER BY years_of_inactivity DESC;
/* 
INNER JOINs are used between actor, film_actor, and film. This ensures that 
we only calculate inactivity for actors who have at least one record in 
the system. A LEFT JOIN would return NULL for 'latest_release', which 
would break the inactivity calculation.
*/

-- Subquery approach makes it harder to read and slightly slows the performance
SELECT 
    der.first_name,
    der.last_name,
    der.latest_release,
    (EXTRACT(YEAR FROM CURRENT_DATE) - der.latest_release) AS years_of_inactivity
FROM (
    SELECT 
        a.first_name,
        a.last_name,
        MAX(f.release_year) AS latest_release
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
) AS der
ORDER BY years_of_inactivity DESC;
-- INNER JOINs for the same reason above

--Task V2: find gaps between sequential films per each actor

-- A lot of aggrigations in case of pure joins and also a lot of columns in GROUP BY. Decreased performance
SELECT 
    a.first_name,
    a.last_name,
    f1.title AS original_film,
    f1.release_year AS original_year,
    MIN(f2.release_year) AS next_release_year,
    (MIN(f2.release_year) - f1.release_year) AS gap_size
FROM public.actor a
INNER JOIN public.film_actor fa1 ON a.actor_id = fa1.actor_id
INNER JOIN public.film f1 ON fa1.film_id = f1.film_id
INNER JOIN public.film_actor fa2 ON a.actor_id = fa2.actor_id
INNER JOIN public.film f2 ON fa2.film_id = f2.film_id
WHERE f2.release_year > f1.release_year
GROUP BY a.actor_id, a.first_name, a.last_name, f1.title, f1.release_year
ORDER BY gap_size DESC, original_film DESC;
/*
This uses a many-to-many self-join. For every film (f1), we join every 
other film (f2) that was released later by the same actor. The GROUP BY 
and MIN() then collapse those multiple "later" films into just the 
single "next" film.
*/

-- CTE makes it better choice for performance and readability
WITH Actor_Film_List AS ( -- We connect actors to movies
    SELECT DISTINCT
        a.actor_id,
        a.first_name,
        a.last_name,
        f.release_year,
        f.title
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
), 
Film_Gaps AS (-- We calculate the age gaps
    SELECT 
        f1.actor_id,
        f1.first_name,
        f1.last_name,
        f1.title AS original_film,
        f1.release_year AS original_year,
        MIN(f2.release_year) AS next_release_year
    FROM Actor_Film_List f1
    INNER JOIN Actor_Film_List f2 ON f1.actor_id = f2.actor_id 
        AND f2.release_year > f1.release_year
    GROUP BY f1.actor_id, f1.first_name, f1.last_name, f1.title, f1.release_year
)
SELECT 
    first_name,
    last_name,
    original_film,
    original_year,
    next_release_year,
    (next_release_year - original_year) AS gap_size
FROM Film_Gaps
ORDER BY gap_size DESC, original_film DESC;
/*
INNER JOINs are used throughout. The self-join in Film_Gaps is particularly 
important; by using f2.release_year > f1.release_year, we effectively 
exclude the actor's final film from the 'original_year' column because 
it has no "next" release to join to.
*/

-- Subquery is slow to perform and too complicated to read.
SELECT 
    f_main.first_name,
    f_main.last_name,
    f_main.title AS original_film,
    f_main.release_year AS original_year,
    -- Scalar subquery to find the absolute next release year for this specific actor
    (SELECT MIN(f_next.release_year)
     FROM public.film f_next
     INNER JOIN public.film_actor fa_next ON f_next.film_id = fa_next.film_id
     WHERE fa_next.actor_id = f_main.actor_id
       AND f_next.release_year > f_main.release_year
    ) AS next_release_year,
    -- Repeating the logic to perform the mathematical subtraction
    (SELECT MIN(f_next.release_year)
     FROM public.film f_next
     INNER JOIN public.film_actor fa_next ON f_next.film_id = fa_next.film_id
     WHERE fa_next.actor_id = f_main.actor_id
       AND f_next.release_year > f_main.release_year
    ) - f_main.release_year AS gap_size
FROM (
    -- Derived table to get the base actor-film list
    SELECT 
        a.actor_id, 
        a.first_name, 
        a.last_name, 
        f.title, 
        f.release_year
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
) AS f_main
WHERE (
    -- Filter out the actor's very last film since it has no "next" year
    SELECT MIN(f_next.release_year)
    FROM public.film f_next
    INNER JOIN public.film_actor fa_next ON f_next.film_id = fa_next.film_id
    WHERE fa_next.actor_id = f_main.actor_id
      AND f_next.release_year > f_main.release_year
) IS NOT NULL
ORDER BY gap_size DESC, original_film DESC;

