	
-- Calculate the monthly difference of profit 
	
	with sub_query as
	(
		select CONVERT(DATE, CONCAT(YEAR(orderdate), '-', 
		MONTH(orderdate) , '-01') , 23) as month_year , grandtotal
		from Orders
		-- This sub query to avoid us
	) ,

	extract_date as
	(    select month_year as month_year, sum(grandtotal) 
			over(partition by month_year order by month_year) as monthly_sales 
				from sub_query
	) ,

	distinct_query as
	(
	   /*This subquery to get the distinct values 
	   of month year to avoid having duplicate rows in the result*/
		select distinct month_year , monthly_sales 
		from extract_date
	)

	select month_year , monthly_sales , lag(monthly_sales , 1) 
		over (order by month_year) as previous_month_sales,
		case
			when lag(monthly_sales, 1) 
			over (order by month_year) is null then 0 -- handle the first month
			else round(((monthly_sales - lag(monthly_sales, 1) 
			over (order by month_year)) / lag(monthly_sales, 1) 
			over (order by month_year)) * 100, 2)
		end as "sales_percentage_difference%"
	from distinct_query;



-- Monetary model for customer segmentation

	with sub_query as
	(
		select distinct CustomerID ,
		CustomerName ,
		LastOrderDate as last_purchase , 
		LastOrderDate , 
		NumberOfOrder as Frequency ,
		TotalOfAmount as Monetary 
		from Customers
	) ,
	rfm_values as
	(
		-- Sub query to calculate the Recency, Frequency and  Monetary
		SELECT 
		DISTINCT CustomerID,
		CustomerName,
		datediff(day, last_purchase ,  max(LastOrderDate) OVER ()) AS Recency,
		Frequency,
		Monetary,
		(Frequency + Monetary) / 2 AS fm_average
	FROM 
		sub_query
	) ,
	rfm_scores as
	(
		-- Sub query to calculate the Recency_score , Frequency_score , Monetary_score
		select distinct CustomerID ,  CustomerName , Recency , Frequency ,  Monetary , 
		ntile(5) over(order by Recency desc) as Recency_score , ntile(5) over(order by fm_average) as avg_fm_score
		from rfm_values
	)
	select distinct CustomerID ,  CustomerName , Recency , Frequency ,  Monetary , Recency_score , avg_fm_score , 
		case 
			when Recency is null and AVG_FM_Score in (0 , 1 , 2) then 'Lost'
			when Recency_score = 5 and AVG_FM_Score in (5 , 4) then 'Champions'
			when Recency_score  = 4 and AVG_FM_Score = 5 then 'Champions'
			when Recency_score in (5,4) and AVG_FM_Score = 2 then 'Potential Loyalists'
			when Recency_score in (3,4) and AVG_FM_Score = 3 then 'Potential Loyalists'
			when Recency_score = 5 and AVG_FM_Score = 3 then 'Loyal Customers'
			when Recency_score = 4 and AVG_FM_Score = 4 then 'Loyal Customers'
			when Recency_score = 3 and AVG_FM_Score in (4 , 5) then 'Loyal Customers'
			when Recency_score = 5 and AVG_FM_Score = 1 then 'Recent Customers'
			when Recency_score in (4 , 3) and AVG_FM_Score = 1 then 'Promising'
			when Recency_score = 3 and AVG_FM_Score = 2 then 'Customers Needing Attention'
			when Recency_score = 2 and AVG_FM_Score in (3 , 2) then 'Customers Needing Attention'
			when Recency_score = 2 and AVG_FM_Score in (4 , 5) then 'At Risk'
			when Recency_score = 1 and AVG_FM_Score = 3 then 'At Risk'
			when Recency_score = 1 and AVG_FM_Score IN (5 , 4) then 'Cant Lose Them'
			when Recency_score = 1 and AVG_FM_Score = 2 then 'Hibernating'
			/*This value was not provided in the given table but was set
			in the logic, as not adding it will allow some rows to have empty values.*/
			when Recency_score = 2 and AVG_FM_Score  = 1 then 'Lost'   
			when Recency_score = 1 and AVG_FM_Score  = 1 then 'Lost'
		end as cust_segment
	from rfm_scores;



-- Percentage of orders modified

	with void_cnt as
	(
		select count (distinct historyid) as void_count
		from Void
	), orders_cnt as
	(
		select count(historyid) as orders_count
		from Orders
	)
	select round (CAST (void_count AS FLOAT) / orders_count , 4) 
	* 100 as 'percentage_of_orders_modified%'
	from void_cnt , orders_cnt;



-- Sales generated per cashier

	select CashierID , CashierName , sum(GrandTotal) as total
	from Orders
	group by CashierID , CashierName
	order by total desc;


-- Customer repeat rate

	select round(cast(count(*) AS FLOAT) / (select count(*) from Customers) , 4) 
	* 100 as Customer_repeat_rate
	from Customers
	where FirstOrderDate != LastOrderDate;


-- Customer retention rate


	WITH CustomerRetentionData_2017 AS (
		SELECT COUNT(CustomerID) AS TotalCustomers_2017,
			SUM(CASE WHEN YEAR(FirstOrderDate) = 2017 THEN 1 ELSE 0 END) AS NewCustomers_2017,
			SUM(CASE WHEN YEAR(LastOrderDate) > 2017 THEN 1 ELSE 0 END) AS ReturningCustomers_2017
		FROM Customers
		WHERE YEAR(FirstOrderDate) <= 2017
	) , CustomerRetentionData_2018 as
	(
		SELECT COUNT(CustomerID) AS TotalCustomers_2018,
			SUM(CASE WHEN YEAR(FirstOrderDate) = 2018 THEN 1 ELSE 0 END) AS NewCustomers_2018,
			SUM(CASE WHEN YEAR(LastOrderDate) > 2018 THEN 1 ELSE 0 END) AS ReturningCustomers_2018
		FROM Customers
		WHERE YEAR(FirstOrderDate) <= 2018
	) , CustomerRetentionData_2019 as
	(
		SELECT COUNT(CustomerID) AS TotalCustomers_2019 ,
			SUM(CASE WHEN YEAR(FirstOrderDate) = 2019 THEN 1 ELSE 0 END) AS NewCustomers_2019 ,
			SUM(CASE WHEN YEAR(LastOrderDate) > 2019 THEN 1 ELSE 0 END) AS ReturningCustomers_2019 
		FROM Customers
		WHERE YEAR(FirstOrderDate) <= 2019
	) , CustomerRetentionData_2020 as
	(
		SELECT COUNT(CustomerID) AS TotalCustomers_2020,
			SUM(CASE WHEN YEAR(FirstOrderDate) = 2020 THEN 1 ELSE 0 END) AS NewCustomers_2020,
			SUM(CASE WHEN YEAR(LastOrderDate) > 2020 THEN 1 ELSE 0 END) AS ReturningCustomers_2020
		FROM Customers
		WHERE YEAR(FirstOrderDate) <= 2020
	)
	SELECT '2017' as Year , TotalCustomers_2017 as TotalCustomers , 
	NewCustomers_2017 as NewCustomers, 
		ReturningCustomers_2017 as ReturningCustomers , 
		round(((ReturningCustomers_2017 * 1.0) / NewCustomers_2017) * 100 , 2) 
		AS CustomerRetentionRate
		from CustomerRetentionData_2017
		union
	select '2018' as Year , TotalCustomers_2018, 
	NewCustomers_2018, ReturningCustomers_2018, 
		round(((ReturningCustomers_2018 * 1.0) / NewCustomers_2018) * 100 , 2) 
		AS CustomerRetentionRate_2018
		from CustomerRetentionData_2018
		union
	select '2019' as Year , TotalCustomers_2019, NewCustomers_2019, 
	ReturningCustomers_2019, 
		round(((ReturningCustomers_2019 * 1.0) / NewCustomers_2019) * 100 , 2) 
		AS CustomerRetentionRate_2019
		from CustomerRetentionData_2019
		union
	select '2020' as Year , TotalCustomers_2020, NewCustomers_2020, 
	ReturningCustomers_2020, 
		round(((ReturningCustomers_2020 * 1.0) / NewCustomers_2020) * 100 , 2) 
		AS CustomerRetentionRate_2020
		from CustomerRetentionData_2020;




-- Number of customers visits and number of orders made per month
	with join_query as
	(
		select orderID , convert(date , concat(year(orderdate) , '-' 
		,month(orderdate) , '-01') , 23)  as OrderDate ,
			o.grandtotal , c.CustomerID , c.CustomerName
		from Orders o left outer join Customers c
		on o.customerid = c.CustomerID
	) , num_query as
	(
		select OrderDate , count(OrderDate) as NumberOfOrders , 
		count(distinct(customerID)) as NumberOfCustomers
		from join_query
		group by OrderDate	
	) , prev_query as
	(
		select OrderDate , NumberOfOrders ,	lag(NumberOfOrders , 1) 
		over(order by OrderDate) as PrevOrd , NumberOfCustomers , 
			lag(NumberOfCustomers , 1) 
			over(order by OrderDate) as PrevCust
		from num_query
	)
	select orderdate , numberoforders , prevord , 
		case
			when prevord is null then 0  -- handle the first month
			else round(((numberoforders * 1.00 - prevord * 1.00)
			/ prevord * 1.00) , 2) * 100
		end as 'PercentageOrdersDiff%',
		numberofcustomers , 
		prevcust ,
			case
			when prevcust is null then 0  -- handle the first month
			else round(((numberofcustomers * 1.00 - prevcust * 1.00)
			/ prevcust * 1.00) , 2) * 100
		end as 'PercentageCustomersDiff%'
	from prev_query;


-- Customer churn rate 

	with join_query as
	(
		-- To join the orders with the customers tables

		select orderID , CONVERT(date , concat(year(orderdate) , '-' 
		, month(orderdate) , '-01')) as OrderFirstDay ,
			o.grandtotal , c.customerID , c.CustomerName 
			, FirstOrderDate , LastOrderDate
		from Orders o left outer join Customers c
		on o.customerid = c.CustomerID
	) , status_query as 
	(
		-- To know if the customer is dropped or retained

		select orderID , OrderFirstDay , EOMONTH(OrderFirstDay) 
		as OrderLastDay , grandtotal , customerID , CustomerName ,
			FirstOrderDate , LastOrderDate , 
			(case 
			when (FirstOrderDate is null) or 
			(LastOrderDate is null) then 'NAN' 
			when (FirstOrderDate >= OrderFirstDay) and 
			(LastOrderDate <= EOMONTH(OrderFirstDay)) then 'Dropped' 
			else 'Retained' 
			end) as Status 
		from join_query
	) , churn_query as
	(
		select concat(year(OrderFirstDay) , '-' 
		, month(OrderFirstDay)) as Month_Year,
			sum(case when status = 'Dropped' 
			then 1 else 0 end) as count_of_dropped , 
			sum(case when status = 'Retained' 
			then 1 else 0 end) as count_of_retained
		from status_query
		group by OrderFirstDay
	)
	
	-- To calculate the churn rate
	select Month_Year , count_of_dropped , count_of_retained , 
		CONVERT(decimal(10 , 3), ROUND((count_of_dropped * 1.00) 
		/ (count_of_retained * 1.00) , 4) * 100) as Churn_Rate
	from churn_query
	order by convert(date , concat(Month_Year , '-01'));


--Average covers (Number of orders / Number of working days)

	with sub_query as
	(
		select OrderID , convert(date , concat(year(orderdate) , 
		'-' , month(orderdate) , '-' , day(orderdate))) 
		as  OrderDate , grandtotal 
		from Orders
	), sub_query1 as
	(
		select OrderDate , count(OrderID) as MealsServed 
		, count(*) 
		over(partition by concat(year(orderdate) , '-' , month(orderdate))) as NumOfDays
		from sub_query
		group by OrderDate
	)
	select format(OrderDate, 'yyyy-MM') AS MonthYear, 
	sum(MealsServed) / max(NumOfDays) AS AvgMealsPerDay
	from sub_query1
	group by format(OrderDate, 'yyyy-MM')
	order by format(OrderDate, 'yyyy-MM');


