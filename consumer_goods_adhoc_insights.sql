-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region
SELECT
	distinct(market)
FROM dim_customer
WHERE customer="Atliq Exclusive" AND region="APAC";

-- 2. What is the percentage of unique product increase in 2021 vs 2020? The final output:
-- unique_products_2020
-- unique_products_2021
-- percentage_chg
WITH unique_prod_2020 AS (
	SELECT
		product_code,
        COUNT(DISTINCT(product_code)) AS prod_2020
	FROM fact_sales_monthly
    WHERE fiscal_year = 2020),
unique_prod_2021 AS (
	SELECT
		product_code,
		COUNT(DISTINCT(product_code)) AS prod_2021
    FROM fact_sales_monthly
    WHERE fiscal_year = 2021)
	SELECT
		prod_2020,
        prod_2021,
        ROUND((((prod_2021 - prod_2020)*100)/prod_2020),2) AS percentage_chg
	FROM unique_prod_2020 t1
    CROSS JOIN unique_prod_2021 t2 ON t1.product_code=t2.product_code;
    
-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
-- The final output contains 2 fields: segment, product_count
	SELECT
		segment,
        COUNT(product) AS unique_prod
	FROM dim_product
    GROUP BY segment
    ORDER BY unique_prod DESC;

-- 4. follow up: which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields:
-- segment, product_count_2020, product_count_2021, difference
WITH unique_prod_2020 AS (
	SELECT
		dp.segment,
        COUNT(DISTINCT(dp.product_code)) AS prod_2020
	FROM dim_product dp
    JOIN fact_sales_monthly f ON dp.product_code=f.product_code
    WHERE f.fiscal_year = 2020
    GROUP BY dp.segment),
unique_prod_2021 AS (
	SELECT
		dp.segment,
        COUNT(DISTINCT(dp.product_code)) AS prod_2021
	FROM dim_product dp
    JOIN fact_sales_monthly f ON dp.product_code=f.product_code
    WHERE f.fiscal_year = 2021
    GROUP BY dp.segment)
SELECT
	t1.segment,
    prod_2020,
    prod_2021,
    (prod_2021 - prod_2020) AS difference
FROM unique_prod_2020 t1
CROSS JOIN unique_prod_2021 t2 ON t1.segment=t2.segment
GROUP BY t1.segment
ORDER BY difference DESC;

-- 5. Get the products that have the highest and lowest manufacturing costs. The final output should contain these field:
-- product_code, product, manufacturing_cost
SELECT
	dp.product_code,
    product,
    fm.manufacturing_cost
FROM dim_product dp
JOIN fact_manufacturing_cost fm
ON fm.product_code = dp.product_code
WHERE fm.manufacturing_cost = (
	SELECT
		MIN(manufacturing_cost)
	FROM fact_manufacturing_cost) 
    OR
    fm.manufacturing_cost = (
	SELECT
		MAX(manufacturing_cost)
	FROM fact_manufacturing_cost)
ORDER BY manufacturing_cost DESC;

-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct
-- for the fiscal year 2021 and in the Indian market. The final output contains these fields:
-- customer_code, customer, average_discount_percentage
SELECT
	d.customer_code,
    c.customer,
    d.pre_invoice_discount_pct AS average_discount_percentage
FROM dim_customer c
JOIN fact_pre_invoice_deductions d ON c.customer_code=d.customer_code
WHERE pre_invoice_discount_pct > (SELECT AVG(pre_invoice_discount_pct) FROM fact_pre_invoice_deductions) AND
market="India" AND fiscal_year = 2021
GROUP BY c.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;

-- 7. Get the complete report of the Gross sales amount for the customer "Atliq Exclusive" for each month. This analysis helps to get 
-- an idea of low high-performing months and take strategic decisions. The final report contains these columns:
-- Month, Year, Gross sales amount
SELECT
	MONTHNAME(s.date) AS Month,
    s.fiscal_year AS Year,
    ROUND(SUM(g.gross_price * s.sold_quantity),2) AS Gross_sales_amount
FROM fact_gross_price g
JOIN fact_sales_monthly s ON g.product_code=s.product_code
JOIN dim_customer c ON c.customer_code=s.customer_code
WHERE c.customer="Atliq Exclusive"
GROUP BY MONTH(s.date), s.fiscal_year
ORDER BY MONTH(s.date), s.fiscal_year;

-- 8. In which quarter of 2020, got the maximum total sold_quantity? The final output contains these fields sorted by
-- the total_sold_quantity: Quarter, total_sold_quantity
SELECT
	CASE
		WHEN date BETWEEN "2019-09-01" AND "2019-11-30" THEN "Q1"
        WHEN date BETWEEN "2019-12-01" AND "2020-02-28" THEN "Q2"
        WHEN date BETWEEN "2020-03-01" AND "2020-05-31" THEN "Q3"
        WHEN date BETWEEN "2020-06-01" AND "2020-08-31" THEN "Q4"
	END AS Quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year=2020
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
-- The final output contain these fields: channel, gross sales mln, percentage
WITH cte_channel AS (
	SELECT
		c.channel,
		SUM(g.gross_price * s.sold_quantity) AS gross_sales
	FROM fact_gross_price g
    JOIN fact_sales_monthly s ON g.product_code=s.product_code
    JOIN dim_customer c ON s.customer_code=c.customer_code
    WHERE s.fiscal_year=2021
    GROUP BY c.channel
    ORDER BY gross_sales DESC)
SELECT
	channel,
    ROUND(gross_sales/1000000,2) AS gross_sales_mln,
    ROUND(gross_sales/(SUM(gross_sales) OVER())*100,2) AS percentage
	FROM cte_channel;

-- 10. Get the top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
-- The final outputs contains these fields: division, product_code
WITH cte_sold_qty AS (
SELECT
	p.division,
    s.product_code,
    p.product,
    SUM(sold_quantity) AS total_sold_quantity
FROM dim_product p
JOIN fact_sales_monthly s ON p.product_code=s.product_code 
WHERE s.fiscal_year=2021
GROUP BY p.division, s.product_code, p.product
ORDER BY total_sold_quantity DESC),
cte_rank AS(
SELECT
	*,
	RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) as ranks
FROM cte_sold_qty)
	SELECT 
    t1.division,
    t1.product_code,
    t1.product,
    t2.total_sold_quantity, 
    t2.ranks
    FROM cte_sold_qty t1 
    JOIN cte_rank t2 ON t1.product_code=t2.product_code
    WHERE ranks <=3;