/*Task 1: Create a query for analyzing the annual sales data for the years 1999 to 2001,
 *  focusing on different sales channels and regions: 'Americas,' 'Asia,' and 'Europe.' */
-- Logic: We use 3 cte in order to filter, partition with window functions and create columns required
WITH cte AS ( -- Applies filters
    SELECT 
        c2.country_region,
        t.calendar_year,
        c.channel_desc,
        SUM(amount_sold) AS sales
    FROM sh.sales s
    JOIN sh.times t ON t.time_id = s.time_id
    JOIN sh.customers c3 ON c3.cust_id = s.cust_id 
    JOIN sh.countries c2 ON c2.country_id = c3.country_id 
    JOIN sh.products p ON p.prod_id = s.prod_id 
    JOIN sh.channels c ON c.channel_id = s.channel_id 
    WHERE c2.country_region IN ('Americas' ,'Asia', 'Europe') 
      AND t.calendar_year IN (1998, 1999, 2000, 2001)
    GROUP BY c2.country_region, t.calendar_year, c.channel_desc
),
cte2 AS ( -- Creates partition
    SELECT
        country_region,
        calendar_year,
        channel_desc,
        sales,
        (100 * sales / SUM(sales) OVER (
            PARTITION BY calendar_year, country_region
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        )) AS pct_by_channels_raw
    FROM cte
),
cte3 AS 
( -- Creating column
SELECT 
    country_region,
    calendar_year,
    channel_desc,
    sales AS AMOUNT_SOLD,
    ROUND(pct_by_channels_raw, 2)::TEXT AS "by_channels",
    ROUND(
        LAG(pct_by_channels_raw) OVER (
            PARTITION BY country_region, channel_desc 
            ORDER BY calendar_year
        ), 2
    )::TEXT AS "previous_period"
FROM cte2 
ORDER BY country_region, calendar_year, channel_desc
)

SELECT  country_region, -- Final select statment
    calendar_year,
    channel_desc,
    to_char(round(AMOUNT_SOLD, 0), '9,999,999,999') || '$' AS "amount_sold",
    by_channels || '%' AS "% BY CHANNELS",
     previous_period || '%' AS "% PREVIOUS PERIOD",
(by_channels::numeric - previous_period::NUMERIC)::TEXT || '%' AS delta
FROM cte3
WHERE calendar_year >= 1999
ORDER BY country_region, calendar_year, channel_desc;


/*Task 2: You need to create a query that meets the requirements*/
-- Logic: Same cte-s to filter our data first, then case when-s to meet the requirements
WITH cte AS (
    SELECT 
        t.calendar_week_number,
        t.time_id,
        t.day_name,
        SUM(amount_sold) AS sales
    FROM sh.sales s
    JOIN sh.times t ON t.time_id = s.time_id
    WHERE t.calendar_week_number IN (48, 49, 50, 51) -- week 48 is included to calculate monday properly
      AND t.calendar_year = 1999
    GROUP BY t.calendar_week_number, t.time_id, t.day_name
),
cte2 AS (
    SELECT 
        calendar_week_number,
        time_id,
        day_name,
        sales,
        SUM(sales) OVER (
            PARTITION BY calendar_week_number 
            ORDER BY time_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cum_sum,
        round(AVG(sales) OVER (ORDER BY time_id ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING), 2) as standard_avg,
        round(AVG(sales) OVER (ORDER BY time_id ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING), 2) as mon_avg,
        round(AVG(sales) OVER (ORDER BY time_id ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING), 2) as fri_avg
    FROM cte -- Logic for calculating averages for regular days, Monday and Friday
)
SELECT
    calendar_week_number,
    time_id,
    day_name,
    sales,
    cum_sum AS "CUM_SUM",
    CASE 
        WHEN day_name = 'Monday' THEN mon_avg
        WHEN day_name = 'Friday' THEN fri_avg
        ELSE standard_avg
    END AS "CENTERED_3_DAY_AVG"
FROM cte2
WHERE calendar_week_number IN (49, 50, 51)
ORDER BY time_id;

/*Task 3: Provide 3 instances of utilizing window functions that include a frame clause, using RANGE, ROWS, and GROUPS modes*/
-- Logic: 3 days rolling average of sales. We include December to get the first of jenuary right
WITH cte1 AS (
SELECT 
    time_id,
    SUM(amount_sold) AS daily_sales,
    AVG(SUM(amount_sold)) OVER (
        ORDER BY time_id 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3day_avg
FROM sh.sales
WHERE time_id BETWEEN '1998-12-01' AND '1999-01-31'
GROUP BY time_id
)
SELECT
time_id,
daily_sales,
rolling_3day_avg
FROM cte1
WHERE time_id BETWEEN '1999-01-01' AND '1999-01-31'
ORDER BY time_id
;

-- Logic: Query calculates a running total of quantity sold but treat all products sold at the same price as a single "logical" block.
SELECT 
    prod_id,
    amount_sold,
    quantity_sold,
    SUM(quantity_sold) OVER (
        ORDER BY amount_sold 
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_qty_by_price
FROM sh.sales
WHERE time_id = '1999-01-01'
ORDER BY amount_sold;

-- Logic: Scenario: marketing team runs a different promotion every week. We want to see the total sales for the current promotion plus the previous one 
-- regardless of how many individual sales occurred during those weeks
SELECT 
    t.calendar_week_number,
    t.time_id,
    SUM(s.amount_sold) AS daily_sales,
    -- Sums all rows in the current week and the entire previous week
    SUM(SUM(s.amount_sold)) OVER (
        ORDER BY t.calendar_week_number 
        GROUPS BETWEEN 1 PRECEDING AND CURRENT ROW
    ) AS two_week_promo_total
FROM sh.sales s
JOIN sh.times t ON s.time_id = t.time_id
WHERE t.calendar_year = 1999
GROUP BY t.calendar_week_number, t.time_id
ORDER BY t.time_id;