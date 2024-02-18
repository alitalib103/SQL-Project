-- 1. What is the unique count and total amount for each transaction type?
select	txn_type,
		count(distinct customer_id) as unique_custumers,
		sum(txn_amount) as total_amonut
from customer_transactions
group by txn_type
order by txn_type;

-- 2. What is the average total historical deposit counts and amounts for all
-- customers?
select avg(deposit_count) as avg_deposit_count,
	   round(avg(deposit_amount),2) as ave_deposit_amount
from (
		select customer_id,
			   count(customer_id) as deposit_count, 
			   avg(txn_amount) as deposit_amount
        from customer_transactions
        where txn_type = 'deposit'
        group by customer_id
	) as customer_deposits;

-- 3. For each month - how many Data Bank customers make more than 1
--    deposit and either 1 purchase or 1 withdrawal in a single month?
with monthly_transactions as (
	select  customer_id,
			year(txn_date) as txn_year,
            month(txn_date) as txn_month,
            sum(case when txn_type = 'deposit' then 1 else 0 end) as deposit_count,
            sum(case when txn_type = 'purchase' then 1 else 0 end) as purchase_count,
            sum(case when txn_type = 'wihtdrawal' then 1 else 0 end) as withdrawal_count
	from customer_transactions
    group by customer_id,
			 txn_year,
             txn_month
),
qualified_customers as (
	select txn_year,
		   txn_month,
           count(*) as qualifying_customers
	from monthly_transactions
    where deposit_count > 1 and (purchase_count >=1 or withdrawal_count >=1)
    group by txn_year,
			 txn_month
)
select * from qualified_customers;


-- 4. What is the closing balance for each customer at the end of the month?
select customer_id,
	   date_format(txn_date, '%Y-%m') as monthly_year,
       sum( case
			when txn_type = 'deposit' then txn_amount
            when txn_type in ('withdrawal', 'purchase') then -txn_amount
            else 0
			end
		) as closing_balance
from customer_transactions
group by customer_id, monthly_year
order by customer_id, monthly_year;



-- 5. What is the percentage of customers who increase their closing balance
-- by more than 5%?
with monthly_closing_balances as (
select customer_id,
	   date_format(txn_date, '%Y-%m') as month,
	   sum(
			case
			when txn_type = 'deposit' then txn_amount
			when txn_type in ('withdrawal', 'purchase') then -txn_amount
			else 0
			end
		   ) as closing_balance
from customer_transactions
group by customer_id, date_format(txn_date, '%Y-%m')
),
BalanceChanges as (
    select 
        curr.customer_id,
        curr.month as current_month,
        prev.month as previous_month,
        curr.closing_balance,
        prev.closing_balance as previous_closing_balance,
        ((curr.closing_balance - prev.closing_balance) / prev.closing_balance) * 100 as percent_change
    from monthly_closing_balances curr
    inner join monthly_closing_balances prev on curr.customer_id = prev.customer_id 
        AND STR_TO_DATE(CONCAT(curr.month, '-01'), '%Y-%m-%d') = 
           STR_TO_DATE(CONCAT(prev.month, '-01'), '%Y-%m-%d') + interval 1 month
),
IncreasedCustomers as (
    select customer_id
    from BalanceChanges
    where percent_change > 5
),
TotalCustomers as (
    select count(distinct customer_id) as total from customer_transactions
),
IncreasedCustomerCount as (
    select count(distinct customer_id) as increased from IncreasedCustomers
)
select (increased / total) * 100 as percentage_increase_over_5
from IncreasedCustomerCount, TotalCustomers;
