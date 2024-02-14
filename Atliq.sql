-- generate a report of individual product sale ( aggergated on monthly basis at the product level) 
-- for amazon india customer for FYI=2021 .

SELECT * FROM gdb0041.dim_customer;
SELECT * FROM dim_product;
SELECT * FROM fact_forecast_monthly;
SELECT * FROM fact_freight_cost;
SELECT * FROM fact_gross_price;
SELECT * FROM fact_manufacturing_cost;
SELECT * FROM fact_post_invoice_deductions;
SELECT * FROM fact_pre_invoice_deductions;
SELECT * FROM fact_sales_monthly;

-- croma india product wise sales report for fiscal year 2021

-- month
-- product name
-- variant
-- sold quantity
-- gross price per item
-- gross price total
select * from fact_sales_monthly 
   where 
     customer_code=90002002 and
	  get_fiscal_year(date)=2021
order by date asc;

-- product name variant 
select s.date ,s.product_code, p.product,p.variant,s.sold_quantity,g.gross_price,
round(g.gross_price*s.sold_quantity,2) as gross_price_total
 from fact_sales_monthly as s
join
dim_product as p
on s.product_code=p.product_code
join fact_gross_price as g
on
 g.product_code=s.product_code and 
 g.fiscal_year=get_fiscal_year(s.date)
   where 
     customer_code=90002002 and
	  get_fiscal_year(date)=2021
order by date asc;

select * from dim_customer 
where customer like "%amazon%" and market ='india';

-- generate an aggregate monthly gross sales report for croma india customer 	
--  so can we track how much sales this perticular customer is generating for
-- AtilQ and manage our relation accordingly.
-- Month
-- total gross amount to croma in this month 

SELECT s.date ,ROUND(SUM(g.gross_price*s.sold_quantity),3) AS gross_price_total FROM
fact_sales_monthly AS s
JOIN fact_gross_price AS g
ON s.product_code=g.product_code AND
g.fiscal_year=GET_FISCAL_YEAR(s.date)
WHERE customer_code= 90002002
GROUP BY s.date
ORDER BY s.date;

-- generate a yearly report for croma india where there are two columns
--  fiscal year
-- total gross sales amount in the year from croma
SELECT 
    GET_FISCAL_YEAR(date) AS fiscal_year,
    SUM(ROUND(sold_quantity * g.gross_price, 2)) AS yearly_sales
FROM
    fact_sales_monthly s
        JOIN
    fact_gross_price g ON g.fiscal_year = GET_FISCAL_YEAR(s.date)
        AND g.product_code = s.product_code
WHERE
    customer_code = 90002002
GROUP BY GET_FISCAL_YEAR(date)
ORDER BY fiscal_year;


-- creat a stored proc that can determine the market badge based on following logic
-- if total sold quantity > 5 Million that market is consider gold else
-- it is silver 
-- input is market and fiscal year 
-- output market badge 
set @out_badge = '0';
call gdb0041.get_market_badge('india', '2020', @out_badge);
select @out_badge;


with cte1 as
(SELECT 
    	    s.date, 
            s.fiscal_year,
            s.customer_code,
            c.market,
            s.product_code, 
            p.product, 
            p.variant, 
            s.sold_quantity, 
            g.gross_price as gross_price_per_item,
            ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
            pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_customer c 
		ON s.customer_code = c.customer_code
	JOIN dim_product p
        	ON s.product_code=p.product_code
	JOIN fact_gross_price g
    		ON g.fiscal_year=s.fiscal_year
    		AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
        	ON pre.customer_code = s.customer_code AND
    		pre.fiscal_year=s.fiscal_year)
 select * ,round(gross_price_total-gross_price_total*pre_invoice_discount_pct,3)
 as net_invoice_sale
 from cte1;
 
 SELECT 
    	    s.date, 
            s.fiscal_year,
            s.customer_code,
            c.market,
            s.product_code, 
            p.product, 
            p.variant, 
            s.sold_quantity, 
            g.gross_price as gross_price_per_item,
            ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
            pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_customer c 
		ON s.customer_code = c.customer_code
	JOIN dim_product p
        	ON s.product_code=p.product_code
	JOIN fact_gross_price g
    		ON g.fiscal_year=s.fiscal_year
    		AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
        	ON pre.customer_code = s.customer_code AND
    		pre.fiscal_year=s.fiscal_year;


-- net sales  price per product  with cte and view --           
with cte2 as
      (SELECT 
      s.date,s.fiscal_year,s.customer_code,s.market,
      s.product_code,s.product,s.variant,
      s.sold_quantity,s.gross_price_per_item,
      s.gross_price_total,
      s.pre_invoice_discount_pct,
      (1-s.pre_invoice_discount_pct)*s.gross_price_total as net_invoice_sales,
       (po.discounts_pct+po.other_deductions_pct) as post_invoice_deduction
       FROM sales_preinv_discount as s
       join fact_post_invoice_deductions as po
       on s.date=po.date
       and s.customer_code=po.customer_code
       and s.product_code=po.product_code)
select *,round((1-post_invoice_deduction)*net_invoice_sales,3) 
as net_sales from cte2;

-- net sales by using view --
SELECT *,
(1-post_invoice_deduction)*net_invoice_sales as net_sales
FROM gdb0041.post_invoice_discount
;

-- gross sales --

select 
s.date,s.fiscal_year,
s.customer_code,c.customer,c.market,
s.product_code,p.product,
p.variant,s.sold_quantity,
g.gross_price as gross_price_item
,(g.gross_price*s.sold_quantity) as gorss_price_total
from fact_sales_monthly as s
join dim_product as p on
p.product_code=s.product_code
join dim_customer as c on 
c.customer_code=s.customer_code
join fact_gross_price as g on
g.product_code=s.product_code and
g.fiscal_year=s.fiscal_year;

-- top market by net sales --
SELECT market,round(sum(net_sales)/1000000,2) 
as net_sales_mln
 FROM net_sales
 where fiscal_year=2021
 group by market
order by net_sales_mln desc
limit 5;

-- store procedures for get_top_net_sales_by_market --
call gdb0041.get_top_n_market_by_net_sales(2020, 5); 

-- store procedures for top customer 
SELECT customer,market,round(sum(net_sales)/1000000,2) as
net_sales_mln
FROM gdb0041.net_sales
where 
fiscal_year=2021 
and 
market = 'india'
group by customer
order by net_sales_mln desc
limit 5;

-- store procedures for top customer--

call gdb0041.top_customer_net_sales('india', 2021, 3);

-- top product by net sales in perticular fiscal year --
SELECT product,
round(sum(net_sales/1000000),2) as net_sales_mln
FROM gdb0041.net_sales
where fiscal_year=2021
group by product 
order by net_sales_mln desc
limit 5;
-- store procedures for top product by net sales
 -- in perticular  fiscal year--
 call gdb0041.top_product(2020, 3);
 
 -- as product owner want to see bar chart report for FY=2021
 -- for top 10 market by % net sales.
 with cte1 as 
 (SELECT c.customer,round(sum(s.net_sales)/1000000,2) as
net_sales_mln
FROM gdb0041.net_sales as s
join dim_customer as c
on s.customer_code = c.customer_code
where s.fiscal_year=2021
group by customer
order by net_sales_mln desc)
select * , net_sales_mln*100/sum(net_sales_mln) over() as pct
from cte1
;
-- creat a table which shows regoin wise(APAC,EU,LTAM etc)% net sales 
-- breakdown by coustomer in a respective region so that we can perform 
-- regionl analysis on financial performance of the company
with cte3 as 
(SELECT 
c.customer,
c.region,round(sum(s.net_sales)/1000000,2) as
net_sales_mln FROM 
net_sales as s
join dim_customer as c
on s.customer_code=c.customer_code
and s.customer=c.customer
where s.fiscal_year=2021
group by c.customer,c.region
order by net_sales_mln desc)
select *,net_sales_mln*100/sum(net_sales_mln) over(partition by region)
as pct_share_region
from cte3
order by region, net_sales_mln desc;

-- get top n product in each division by quantity sold
with cte1 as (
SELECT p.division,p.Product,sum(s.Sold_quantity)
as total_quantity_sold
 FROM fact_sales_monthly as s
join dim_product as p
on p.product_code=s.product_code
where fiscal_year=2021
group By p.division, p.product),
 cte2 as(select *,dense_rank() over(partition by division
            order by total_quantity_sold desc) as drank from cte1)
select * from cte2 where drank<=3;

-- retrieve the top market in every region by their gross sales amount in FY=2021

with cte1 as 
(select c.market,c.region,round(sum(s.sold_quantity*g.gross_price)/1000000,2) 
as gross_sales_mln
 from fact_gross_price as g
 join fact_sales_monthly as s
 on 
 g.product_code=s.product_code and
 g.fiscal_year=s.fiscal_year
 join dim_customer as c
 on c.customer_code=s.customer_code
 where s.fiscal_year=2021
 group by c.region,c.market
order by gross_sales_mln desc) ,
cte2 as (
select * ,dense_rank() over(partition by region order by gross_sales_mln desc)
as drnk from cte1)
select * from cte2 where drnk<=2;

-- Net Sales Contribution in Percent 
SELECT * FROM gdb0041.net_sales;

with cte2 as
(select customer,round(sum(net_sales)/1000000,2) as
net_sales_mln from net_sales
where
fiscal_year=2021
group by customer
order by net_sales_mln desc)
select * , net_sales_mln*100/sum(net_sales_mln) over() as pct
from cte2;

-- net Sales By Customer and Region 
SELECT 
c.customer,
c.region,round(sum(s.net_sales)/1000000,2) as
net_sales_mln FROM 
net_sales as s
join dim_customer as c
on s.customer_code=c.customer_code
and s.customer=c.customer
where s.fiscal_year=2021
group by c.customer,c.region
order by net_sales_mln desc;




 









 
 
 
 




       





     


