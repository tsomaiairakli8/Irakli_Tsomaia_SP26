/*Task 1: Sales report highlighting the top customers with the highest sales across different sales channels*/
-- Solution logic: Without using ROW_NUMBER() and SUM() OVER() we can use self joins and subqueries
-- Performance: Using method below is significantly slower then using window frames, using OVER() is recommended
with cte1 as ( -- We create cte to calculate total sold amount by customer and channel
    select 
        s.cust_id,
        c.channel_desc ,
        sum(s.amount_sold) as total_of_customer_by_channel
    from sh.channels c 
    inner join sh.sales s on c.channel_id = s.channel_id
    group by s.cust_id, c.channel_desc
),
channel_totals as ( -- We create grand total to calculate percentages
    select 
        channel_desc,
        sum(total_of_customer_by_channel) as grand_total_channel
    from cte1
    group by channel_desc
)

select 
    c2.cust_first_name,
    c2.cust_last_name,
    a.channel_desc channel,
    round(a.total_of_customer_by_channel, 2) as total_sales,
    to_char(round((a.total_of_customer_by_channel / b.grand_total_channel) * 100, 4), 'FM990.9999') || '%' as sales_percentage
from cte1 a
inner join sh.customers c2 on c2.cust_id = a.cust_id
inner join channel_totals b on a.channel_desc = b.channel_desc
where ( -- The filter that looks through the data in order to find top 5 customers
    select count(*) 
    from cte1 c 
    where c.channel_desc = a.channel_desc 
    and c.total_of_customer_by_channel > a.total_of_customer_by_channel
) < 5
order by a.channel_desc, a.total_of_customer_by_channel desc;


/*Task 2: Create a query to retrieve data for a report that displays the
 total sales for all products in the Photo category in the Asian region for the year 2000*/
-- Solution logic: We use crosstab to split year_sum into four quarters
CREATE EXTENSION IF NOT EXISTS tablefunc; -- We need to create tablefunc extension for crosstab function

SELECT 
    prod_name,
    COALESCE(ROUND(q1, 2), 0.00) AS Q1,
    COALESCE(ROUND(q2, 2), 0.00) AS Q2,
    COALESCE(ROUND(q3, 2), 0.00) AS Q3,
    COALESCE(ROUND(q4, 2), 0.00) AS Q4,
    ROUND(
        COALESCE(q1, 0) + COALESCE(q2, 0) + COALESCE(q3, 0) + COALESCE(q4, 0), 
        2
    ) AS YEAR_SUM  -- Horizontal total for the YEAR_SUM
FROM crosstab(  -- Source Query: Returns Product, Quarter Number, Total Sales and applies filters
    'SELECT 
        p.prod_name, 
        TO_CHAR(s.time_id, ''Q'') as quarter, 
        SUM(s.amount_sold)
     FROM sh.sales s
     INNER JOIN sh.products p ON p.prod_id = s.prod_id
     INNER JOIN sh.customers c ON c.cust_id = s.cust_id
     INNER JOIN sh.countries cn ON cn.country_id = c.country_id 
     WHERE p.prod_category_desc = ''Photo'' 
       AND cn.country_region = ''Asia''
       AND s.time_id BETWEEN ''2000-01-01'' AND ''2000-12-31''
     GROUP BY p.prod_name, 
    TO_CHAR(s.time_id, ''Q'')
     ORDER BY p.prod_name, 
    quarter',
    'SELECT m FROM generate_series(1,4) m'
) AS ct(prod_name TEXT, q1 NUMERIC, q2 NUMERIC, q3 NUMERIC, q4 NUMERIC)   -- Category Query: Ensures we have 4 columns even if a quarter is missing
ORDER BY YEAR_SUM DESC;

/*Task 3: Create a query to generate a sales report for customers ranked in the top 300 based on total sales for years 1998, 1999, and 2001*/
-- Solution logic: We use cte to filter the top 300 customers and we join the cte to sales table.
WITH top_300_customers AS ( -- Identify the Top 300 customers globally for 1998, 1999, and 2001
    SELECT 
        s.cust_id,
        SUM(s.amount_sold) as total_combined_sales
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE t.calendar_year IN (1998, 1999, 2001)
    GROUP BY s.cust_id
    ORDER BY total_combined_sales DESC
    LIMIT 300
)
SELECT 
    c.channel_desc AS sales_channel,
    cu.cust_id,
    cu.cust_last_name, 
    cu.cust_first_name AS customer_name,
    ROUND(SUM(s.amount_sold), 2) AS channel_total_sales
FROM sh.sales s
JOIN sh.channels c ON s.channel_id = c.channel_id
JOIN sh.customers cu ON s.cust_id = cu.cust_id
JOIN sh.times t ON s.time_id = t.time_id
JOIN top_300_customers tc ON s.cust_id = tc.cust_id -- Filter: Only include the Top 300 customers identified in the CTE
WHERE t.calendar_year IN (1998, 1999, 2001)
GROUP BY 
    c.channel_desc, 
    cu.cust_id, 
    cu.cust_last_name, 
    cu.cust_first_name
ORDER BY 
   c.channel_desc, 
    SUM(s.amount_sold) DESC;

/*Task 4: Create a query to generate a sales report for January 2000, February 2000, and March 2000 specifically for the Europe and Americas regions*/
-- Solution logic: We use CASE WHEN logic to split amount_sold into two columns
SELECT 
    t.calendar_month_desc,
    p.prod_category,
    ROUND(SUM(CASE WHEN cn.country_region = 'Americas' THEN s.amount_sold ELSE 0 END), 0) AS americas_sales,
    ROUND(SUM(CASE WHEN cn.country_region = 'Europe' THEN s.amount_sold ELSE 0 END), 0) AS europe_sales
FROM sh.sales s
INNER JOIN sh.products p ON p.prod_id = s.prod_id 
INNER JOIN sh.customers c ON s.cust_id = c.cust_id
INNER JOIN sh.times t ON t.time_id = s.time_id 
INNER JOIN sh.countries cn ON c.country_id = cn.country_id 
WHERE s.time_id BETWEEN '2000-01-01' AND '2000-03-31'
  AND cn.country_region IN ('Europe', 'Americas')
GROUP BY 
    t.calendar_month_desc,
    p.prod_category
ORDER BY t.calendar_month_desc,
    p.prod_category;