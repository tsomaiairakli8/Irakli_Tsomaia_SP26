/* Task: Inserting 3 favorite movies in public.film table
 * NOTE: since film.film_id is serial and since triger for film.fulltext column exists I ignore those two columns. They insert automatically.
 * Column film.special_features is treated as array, In order to make query rerunable without errors I use aliases
 * SELECT FROM makes sure there are no duplicates in films
 */
BEGIN;
INSERT INTO public.film
(title, description, release_year, language_id, original_language_id, rental_duration, rental_rate, length, replacement_cost, rating, last_update, special_features)
SELECT 
title, description, release_year, language_id, original_language_id, rental_duration, rental_rate, length, replacement_cost, rating, last_update, special_features
FROM (
	VALUES
	(UPPER('La La Land'), 'When Sebastian, a pianist, and Mia, an actress, follow their passion and achieve success in their respective fields, they find themselves torn between their love for each other and their careers.', 2016, 1, 1, 1, 4.99, 128, 19.99, 'PG-13'::mpaa_rating, now(), ARRAY['Trailers']::text[]),
	(UPPER('The Godfather'), 'Don Vito Corleone, head of a mafia family, decides to hand over his empire to his youngest son, Michael. However, his decision unintentionally puts the lives of his loved ones in grave danger.', 1972, 1, 1, 2, 9.99, 175, 29.99, 'R'::mpaa_rating, now(), ARRAY['Trailers', 'Commentaries']::text[]),
	(UPPER('I Swear'), 'John Davidson grows up with Tourette syndrome in 1980s Scotland. He faces a society that does not understand his condition. He eventually becomes a campaigner to increase public awareness.', 2025, 1, 1, 3, 19.99, 121, 16.99, 'R'::mpaa_rating, now(), ARRAY['Trailers', 'Commentaries', 'Behind the Scenes']::text[])
) AS t(title, description, release_year, language_id, original_language_id, rental_duration, rental_rate, length, replacement_cost, rating, last_update, special_features
)
WHERE NOT EXISTS ( -- Makes sure movie with same title cant be added twice
    SELECT 1 
    FROM public.film f 
    WHERE f.title = t.title
)
RETURNING * ;
COMMIT;


/*Task: Inserting actors that played in movies
 * Notes: Since public.actor.actor_id is serial and autoincrements I ignore that column while insertion. actor.last_update autoincrements as now() so it is ignored too.
 * In order to make query rerunable without errors I use aliases
 * SELECT FROM makes sure there are no duplicates in actors
 * */
BEGIN;
INSERT INTO public.actor (first_name, last_name)
SELECT t.first_name, t.last_name
FROM (
    VALUES 
        (UPPER('Emma'), UPPER('Stone')),
        (UPPER('Ryan'), UPPER('Gosling')),
        (UPPER('Al'), UPPER('Pacino')),
        (UPPER('Marlon'), UPPER('Brando')),
        (UPPER('Robert'), UPPER('Aramayo')),
        (UPPER('Shirley'), UPPER('Henderson'))
) AS t(first_name, last_name)
WHERE NOT EXISTS ( -- This makes sure that script will not produce duplicates when ran twice
    SELECT 1 
    FROM public.actor a 
    WHERE a.first_name = t.first_name 
      AND a.last_name = t.last_name
)
RETURNING *;

COMMIT;



/*Task: insert actros in public.film_actor table accordigly
 * NOTE: update_time is self-inserting so i dont specify it
 *SELECT FROM makes sure actors will be added to coresponding films no matter what actors id`s or film`s id`s are
 *  */
BEGIN;
INSERT INTO public.film_actor (actor_id, film_id)
SELECT a.actor_id, f.film_id
FROM public.actor a 
INNER JOIN public.film f ON (
    -- Block 1: La La Land
    (f.title = UPPER('La La Land') AND (
        (a.first_name = UPPER('Emma') AND a.last_name = UPPER('Stone')) OR 
        (a.first_name = UPPER('Ryan') AND a.last_name = UPPER('Gosling'))
    ))
    OR
    -- Block 2: The Godfather
    (f.title = UPPER('The Godfather') AND (
        (a.first_name = UPPER('Al') AND a.last_name = UPPER('Pacino')) OR 
        (a.first_name = UPPER('Marlon') AND a.last_name = UPPER('Brando'))
    ))
    OR
    -- Block 3: I Swear
    (f.title = UPPER('I Swear') AND (
        (a.first_name = UPPER('Robert') AND a.last_name = UPPER('Aramayo')) OR 
        (a.first_name = UPPER('Shirley') AND a.last_name = UPPER('Henderson'))
    ))
)
ON CONFLICT (actor_id, film_id) DO NOTHING -- On conflict makes sure that script is runnable more than once without errors
RETURNING *;
COMMIT;

/* Task: Insert movies in public.inventory table
 * NOTE: Since inventory_id is serial I dont add it manualy. Same with last_update, its now() by default
 * SELECT FROM makes sure there are no duplicates in inventory
 * */
BEGIN;
INSERT INTO public.inventory (film_id, store_id)
SELECT film_id, 1
FROM public.film f 
WHERE f.title IN (UPPER('La La Land'), UPPER('The Godfather'), UPPER('I Swear'))
AND NOT EXISTS ( -- Makes sure that moveis do not get duplicates in inventory table if scrip is running few times
    SELECT 1 FROM public.inventory i 
    WHERE i.film_id = f.film_id
)
RETURNING *;
COMMIT;

/*Task find person with more than 43 rental and payment records and alter their name to yours
 * Note: I dont know if it counts as hardcoding ID-s, I`ve founde persons customer_id with a query and enter only that ID
 * instead of entering the whole CTE tables every time. customer_id is 598
 * Query is:
 * WITH cte_rentals AS (
    SELECT customer_id, COUNT(*) AS rental_count
    FROM public.rental
    GROUP BY customer_id
    HAVING COUNT(*) > 43 -- record with more than 43 rentals
),
cte_payments AS (
    SELECT customer_id, COUNT(*) AS payment_count
    FROM public.payment
    GROUP BY customer_id
    HAVING COUNT(*) > 43 -- record with more than 43 payments
)
SELECT 
    r.customer_id, 
    r.rental_count, 
    p.payment_count
FROM cte_rentals r
INNER JOIN cte_payments p ON r.customer_id = p.customer_id
ORDER BY customer_id DESC 
LIMIT 1;

 */
BEGIN;
UPDATE public.customer
SET store_id=1, first_name='IRAKLI', last_name='TSOMAIA', email='IRAKLI.TSOMAIA@sakilacustomer.org', address_id=604, activebool=true, create_date='now'::text::date, last_update=now(), active=1
WHERE customer_id=598
RETURNING *;
COMMIT;

/*Task: remove records related to you (as a customer) from all tables except 'Customer' and 'Inventory'
 * Note: since it was asked previously not to touch address table I will not run any operations on it
 * Deleting order matters in order to avoid errors. We delete from public.payment first
 * Deleting is safe because: tables have constraints and hierarchy that prevent the unnecessary deletion. Above that in this case the where clause narrows down the deleted information.
 * */
BEGIN;
DELETE FROM public.payment 
WHERE customer_id = 598
RETURNING *;
COMMIT;
-- Deletes our payment  history
BEGIN;
DELETE FROM public.rental 
WHERE customer_id = 598
RETURNING *;
COMMIT;
-- Deletes our rental history

/*Task: Rent movies by inserting rows into rental and payment tables
 * Note: customer_id is pasted as is, rental_id and last_update are ignored due to them being autoincremented
 * We need to create a partition for our payment insertion to work
 * Query that inserts in rental and payment tables are united in one block to make sure they run equal ammount of times.
 *  */

BEGIN;
CREATE TABLE public.payment_default PARTITION OF public.payment DEFAULT;
COMMIT;
--Query above is a partition

BEGIN;
INSERT INTO public.rental
(rental_date, inventory_id, customer_id, return_date, staff_id)
SELECT
CURRENT_TIMESTAMP, 
    i.inventory_id, 
    598,
    CURRENT_TIMESTAMP + INTERVAL '7 days', -- Will be returned in a week
    1 
FROM public.inventory i 
INNER JOIN public.film f ON i.film_id =f.film_id
WHERE f.title IN (UPPER('La La Land'), UPPER('The Godfather'), UPPER('I Swear')) -- All three movies are rented at the same time and will be returned at the same time in 7 days
RETURNING *;


-- We insert into rental table first




INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT 
    r.customer_id, 
    r.staff_id, 
    r.rental_id,
    CASE -- Since public.payment-s amount column is not the same as public.film-s rental_rate column I added the estimated prices at random
        WHEN f.title = UPPER('The Godfather') THEN 2.99  -- Estimated price
        WHEN f.title = UPPER('La La Land')     THEN 4.99  -- Estimated price
        WHEN f.title = UPPER('I Swear')         THEN 3.99  -- Estimated price
        ELSE 0.99                                         
    END AS amount,
    CURRENT_TIMESTAMP
FROM public.rental r
JOIN public.inventory i ON r.inventory_id = i.inventory_id
JOIN public.film f ON i.film_id = f.film_id
WHERE r.customer_id = 598
RETURNING *;
COMMIT;


/* * -----------------------------------------------------------------------------
 * 1. WHY A SEPARATE TRANSACTION IS USED (BEGIN/COMMIT)
 * -----------------------------------------------------------------------------
 * We wrap these sub-tasks in a transaction to ensure ATOMICITY. In a complex 
 * workflow where we insert Films, then Actors, then link them in Film_Actor, 
 * these steps are logically codependent. All this makes sure there are no 'half-done'
 * transactions .
 * * -----------------------------------------------------------------------------
 * 2. WHAT WOULD HAPPEN IF THE TRANSACTION FAILS
 * -----------------------------------------------------------------------------
 * If any single statement within the BEGIN/COMMIT block fails (e.g., a 
 * syntax error, a partition violation, or a constraint error), the entire 
 * block is aborted. PostgreSQL treats the transaction as a single unit; 
 * if one part fails, the whole unit fails.
 * * -----------------------------------------------------------------------------
 * 3. ROLLBACK POSSIBILITY AND DATA AFFECTED
 * -----------------------------------------------------------------------------
 * ROLLBACK is fully possible as long as the COMMIT command hasn't been issued. 
 * If a failure occurs, an automatic ROLLBACK is triggered, and ALL DATA modified 
 * since the 'BEGIN' command is reverted to its original state. 
 * Since we divide whole task into subtasks and give each one its own BEGIN
 * and COMMIT the failed block will stop at the point of error. 
 * Skippable blocks could be made by creating our own unique constraints but since its not in the task I prefered to use the methods above
 * * -----------------------------------------------------------------------------
 * 4. HOW REFERENTIAL INTEGRITY IS PRESERVED
 * -----------------------------------------------------------------------------
 * Integrity is preserved by following the RELATIONAL HIERARCHY. 
 * - We insert Parent records (Film, Actor) before Child records (Film_Actor, Rental).
 * - We also delete records in reverse order.
 * - We use INNER JOINS on natural keys (Titles/Names) to dynamically fetch 
 * Foreign Keys (IDs) rather than hardcoding them. 
 * - This ensures that every entry in a junction table correctly references 
 * an existing row in a master table.
 * * -----------------------------------------------------------------------------
 * 5. HOW THE SCRIPT AVOIDS DUPLICATES
 * -----------------------------------------------------------------------------
 * Unique constraints could be implemented but since its not the point of this task I decided to use WHERE NOT EXISTS approach
 * -----------------------------------------------------------------------------
 */
