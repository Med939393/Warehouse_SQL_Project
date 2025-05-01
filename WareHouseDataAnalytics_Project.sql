-- Create Schemas

CREATE SCHEMA gold;


CREATE TABLE gold.dim_customers(
	customer_key int,
	customer_id int,
	customer_number nvarchar(50),
	first_name nvarchar(50),
	last_name nvarchar(50),
	country nvarchar(50),
	marital_status nvarchar(50),
	gender nvarchar(50),
	birthdate date,
	create_date date
);


CREATE TABLE gold.dim_products(
	product_key int ,
	product_id int ,
	product_number nvarchar(50) ,
	product_name nvarchar(50) ,
	category_id nvarchar(50) ,
	category nvarchar(50) ,
	subcategory nvarchar(50) ,
	maintenance nvarchar(50) ,
	cost int,
	product_line nvarchar(50),
	start_date date 
);


CREATE TABLE gold.fact_sales(
	order_number nvarchar(50),
	product_key int,
	customer_key int,
	order_date date,
	shipping_date date,
	due_date date,
	sales_amount int,
	quantity tinyint,
	price int 
);

select * from  gold.dim_customers 
select * from gold.dim_products
select * from gold.fact_sales

--1. Change-over-Time trends 

--Change Over Time Analysis
===============================================================================
--Purpose:
   -- To track trends, growth, and changes in key metrics over time.
    -- For time-series analysis and identifying seasonality.
    -- To measure growth or decline over specific periods.

--SQL Functions Used:
   -- Date Functions: DATEPART(), DATETRUNC(), FORMAT()
   --- Aggregate Functions: SUM(), COUNT(), AVG()
--===============================================================================
--*/

-- Analyse sales performance over time
-- Quick Date Functions
SELECT COALESCE(order_date, '1900-01-01') AS order_date, 
       sales_amount 
FROM gold.fact_sales 
ORDER BY order_date 

-- removing the "NULL" values 

SELECT 
    DATE_TRUNC('month', order_date) AS order_date,
       SUM(sales_amount) as cnt_amount ,
	   count(distinct(customer_key)) as cnt_customer,
	   sum(quantity) as cnt_quantity 
FROM gold.fact_sales where order_date is not NULL group by 1
ORDER BY 1 


-- 2.Cumulative Analysis
--Purpose:
   -- - To calculate running totals or moving averages for key metrics.
  -  -- To track performance over time cumulatively.
 -  -- Useful for growth analysis or identifying long-term trends.

--SQL Functions Used:
    --- Window Functions: SUM() OVER(), AVG() OVER()
===============================================================================
--*/

-- Calculate the total sales per month 
-- and the running total of sales over time 
--Calculate the total sales per month
--The running total of sales over time 
   
select * from gold.fact_sales

with cte as (select DATE_TRUNC('month', order_date) AS order_date,
SUM(sales_amount) as total_sales,
AVG(price) as average_price

from gold.fact_sales where DATE_TRUNC('month', order_date) is not null  group by 1 ) 

select order_date,total_sales,sum(total_sales) over(order by order_date ) as running_total_sales,
ROUND(AVG(average_price) over(partition by order_date order by order_date ),0) as average_price_moving
from cte 

--3.Performance Analysis
--Performance Analysis (Year-over-Year, Month-over-Month)
===============================================================================
--Purpose:
   - -- To measure the performance of products, customers, or regions -----over time.
    -- For benchmarking and identifying high-performing entities.
    -- To track yearly trends and growth.

--SQL Functions Used:
    -- LAG(): Accesses data from previous rows.
    -- AVG() OVER(): Computes average values within partitions.
   - --- CASE: Defines conditional logic for trend analysis.
---=========================================================-======================
--*/

--/* Analyze the yearly performance of products by comparing their sales 
--to both the average sales performance of the product and the previous year's sales */

select * from gold.dim_products


WITH cte AS (
    SELECT 
        EXTRACT(YEAR FROM f.order_date) AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key 
    WHERE EXTRACT(YEAR FROM f.order_date) IS NOT NULL
    GROUP BY 1, 2
    ORDER BY 1 DESC
)
SELECT 
    order_year,
    product_name,
    current_sales,
    ROUND(AVG(current_sales) OVER (PARTITION BY product_name), 0) AS avg_sales,
    ROUND(current_sales - AVG(current_sales) OVER (PARTITION BY product_name), 0) AS diff_avg,
    CASE 
        WHEN ROUND(current_sales - AVG(current_sales) OVER (PARTITION BY product_name), 0) > 0 THEN 'above the average'
		WHEN ROUND(current_sales - AVG(current_sales) OVER (PARTITION BY product_name), 0) < 0 THEN 'below the average'
        ELSE 'average'
    END AS analyse_performance,
lag(current_sales) over (partition by product_name order by order_year)as py_sales ,
current_sales-lag(current_sales) over (partition by product_name order by order_year) as dif_py ,
CASE 
        WHEN current_sales-lag(current_sales) over (partition by product_name order by order_year) > 0 THEN 'Increase'
		WHEN current_sales-lag(current_sales) over (partition by product_name order by order_year) < 0 THEN 'Decrease'
        ELSE 'No change'
    END AS py_change
from cte 
ORDER BY product_name, order_year;

--4.Part-to-Whole Analysis
--Purpose:
    -- To compare performance or metrics across dimensions or time periods.
    -- To evaluate differences between categories.
    -- Useful for A/B testing or regional comparisons.

--SQL Functions Used:
    -- SUM(), AVG(): Aggregates values for comparison.
    -- Window Functions: SUM() OVER() for total calculations.
===============================================================================
--*/
-- Which categories contribute the most to overall sales?

with cte as (select p.category,SUM(f.sales_amount) as total_sales FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
group by 1 )
select category,total_sales,
sum(total_sales) over () as over_sales,

CONCAT (Round((total_sales / sum(total_sales) over ()) * 100,2),'%') as percentage_of_total

from cte 

--5.Data Segmentation Analysis
===============================================================================
--Purpose:
   -- To group data into meaningful categories for targeted insights.
    -- For customer segmentation, product categorization, or regional analysis.

--SQL Functions Used:
    -- CASE: Defines custom segmentation logic.
    --GROUP BY: Groups data into segments.
===============================================================================


--/*Segment products into cost ranges and count how many products fall into each segment*/
select * from  gold.dim_customers 
select * from gold.dim_products
select * from gold.fact_sales

WITH product_segments AS (
    SELECT
        product_key,
        product_name,
        cost,
        CASE 
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
            ELSE 'Above 1000'
        END AS cost_range
    FROM gold.dim_products
)
SELECT 
    cost_range,
    COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;

--/*Group customers into three segments based on their spending behavior:
	-- VIP: Customers with at least 12 months of history and spending more than €5,000.
	-- Regular: Customers with at least 12 months of history but spending €5,000 or less.
	-- New: Customers with a lifespan less than 12 months.
--And find the total number of customers by each group
WITH customer_spending AS (
    SELECT
        c.customer_key,
        SUM(f.sales_amount) AS total_spending,
        MIN(f.order_date) AS first_order,
        MAX(f.order_date) AS last_order,
        DATE_PART('year', AGE(MAX(f.order_date), MIN(f.order_date))) * 12 +
        DATE_PART('month', AGE(MAX(f.order_date), MIN(f.order_date))) AS lifespan
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
)
SELECT 
    customer_segment,
    COUNT(customer_key) AS total_customers
FROM (
    SELECT 
        customer_key,
        CASE 
            WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM customer_spending
) AS segmented_customers
GROUP BY customer_segment
ORDER BY total_customers DESC;


--5/*
===============================================================================
--Customer Report
===============================================================================
--Purpose:
    -- This report consolidates key customer metrics and behaviors

--Highlights:
    --1. Gathers essential fields such as names, ages, and transaction details.
	--2. Segments customers into categories (VIP, Regular, New) and age groups.
    --3. Aggregates customer-level metrics:
	   -- total orders
	  - -- total sales
	   -- total quantity purchased
	   -- total products
	   -- lifespan (in months)
    --4. Calculates valuable KPIs:
	    -- recency (months since last order)
		-- average order value
		-- average monthly spend
-- =============================================================================
-- Create Report: gold.report_customers
-- =============================================================================
DROP VIEW IF EXISTS gold.report_customers;

CREATE VIEW gold.report_customers AS

WITH base_query AS (
    /*---------------------------------------------------------------------------
    1) Base Query: Retrieves core columns from tables
    ---------------------------------------------------------------------------*/
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATE_PART('year', AGE(CURRENT_DATE, c.birthdate)) AS age
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_customers AS c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL
),

customer_aggregation AS (
    /*---------------------------------------------------------------------------
    2) Customer Aggregations: Summarizes key metrics at the customer level
    ---------------------------------------------------------------------------*/
    SELECT 
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        DATE_PART('year', AGE(MAX(order_date), MIN(order_date))) * 12 +
        DATE_PART('month', AGE(MAX(order_date), MIN(order_date))) AS lifespan
    FROM base_query
    GROUP BY 
        customer_key,
        customer_number,
        customer_name,
        age
)

SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE 
         WHEN age < 20 THEN 'Under 20'
         WHEN age BETWEEN 20 AND 29 THEN '20-29'
         WHEN age BETWEEN 30 AND 39 THEN '30-39'
         WHEN age BETWEEN 40 AND 49 THEN '40-49'
         ELSE '50 and above'
    END AS age_group,
    CASE 
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    last_order_date,
    DATE_PART('year', AGE(CURRENT_DATE, last_order_date)) * 12 +
    DATE_PART('month', AGE(CURRENT_DATE, last_order_date)) AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    -- Compute average order value (AOV)
    CASE 
        WHEN total_sales = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_value,
    -- Compute average monthly spend
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_spend
FROM customer_aggregation;


select * from gold.report_customers


--/*
===============================================================================
--Ranking Analysis
===============================================================================
--Purpose:
   -- - To rank items (e.g., products, customers) based on performance or other metrics.
    --- To identify top performers or laggards.

--SQL Functions Used:
    -- Window Ranking Functions: RANK(), DENSE_RANK(), ROW_NUMBER(), TOP
    -- Clauses: GROUP BY, ORDER BY
===============================================================================
*/

-- Which 5 products Generating the Highest Revenue?
-- Simple Ranking

with cte as (SELECT 
    
        p.product_name,
        sum(f.sales_amount) as total_sales
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key

group by 1 order by 2 DESC )

select product_name,total_sales from (select product_name,total_sales,rank() over( order by total_sales desc) as rk from cte ) where rk <= 5

-- What are the 5 worst-performing products in terms of sales?

with cte as (SELECT 
    
        p.product_name,
        sum(f.sales_amount) as total_sales
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key

group by 1 order by 2 ASC)

select product_name,total_sales from (select product_name,total_sales,rank() over( order by total_sales ASC) as rk from cte ) where rk <= 5



----- Find the top 10 customers who have generated the highest revenue

select c.customer_key,c.first_name,c.last_name,sum(f.sales_amount) as total_revenues from gold.fact_sales as f left join 
  gold.dim_customers as c on
f.customer_key = c.customer_key  group by 1,2,3 order by 4 DESC limit 10
    
---- The 3 customers with the fewest orders placed       

select c.customer_key,
    c.first_name,
    c.last_name ,COUNT(DISTINCT order_number) AS total_orders from gold.fact_sales as f left join 
  gold.dim_customers as c on
f.customer_key = c.customer_key group by 1,2,3 order by 4 ASC limit 3


===============================================================================
--Magnitude Analysis
--Purpose:
    -- To quantify data and group results by specific dimensions.
    -- For understanding data distribution across categories.

--SQL Functions Used:
    -- Aggregate Functions: SUM(), COUNT(), AVG()
    -- GROUP BY, ORDER BY
===============================================================================
*/--

select * from  gold.dim_customers 
select * from gold.dim_products
select * from gold.fact_sales
-- Find total customers by countries

select country, count(customer_key) as total_customers from gold.dim_customers group by 1 order by 2 desc

---- Find total customers by gender

select gender, count(customer_key) as total_customers from gold.dim_customers group by 1 order by 2 desc

-- Find total products by category

select category, count(product_key) as total_products from gold.dim_products group by 1 order by 2 desc

-- What is the average costs in each category?

select category, AVG(cost) as average_cost from gold.dim_products group by 1 order by 2 desc

-- What is the total revenue generated for each category?

select p.category,sum(sales_amount) as total_revenue from gold.fact_sales as f left join gold.dim_products as p
on f.product_key = p.product_key group by 1 order by 2 desc

-- What is the total revenue generated by each customer?
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY 
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY total_revenue DESC;

-- What is the distribution of sold items across countries?

SELECT
    c.country,
    SUM(f.quantity) AS total_sold_items
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY c.country
ORDER BY total_sold_items DESC;




