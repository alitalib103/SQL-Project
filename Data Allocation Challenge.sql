-- ● running customer balance column that includes the impact each transaction
-- ● customer balance at the end of each month
-- ● minimum, average and maximum values of the running balance for each customer
with RunningBalances as (
    select 
        customer_id, 
        txn_date, 
        @running_balance := if(@prev_customer_id = customer_id, @running_balance + txn_amount, txn_amount) as running_balance,
        @prev_customer_id := customer_id
    from 
        (select @running_balance := 0, @prev_customer_id := '') as vars,
        customer_transactions
    order by customer_id, txn_date
),
MonthEndBalances as (
    select 
        customer_id,
        LAST_DAY(txn_date) as month_end,
        MAX(running_balance) as month_end_balance
    from RunningBalances
    group by customer_id, LAST_DAY(txn_date)
),
BalanceStats as (
    select 
        customer_id,
        min(running_balance) as min_balance,
        avg(running_balance) as avg_balance,
        max(running_balance) as max_balance
    from RunningBalances
    group by customer_id
)
select 
    b.customer_id, 
    b.month_end,
    b.month_end_balance,
    s.min_balance,
    s.avg_balance,
    s.max_balance
from MonthEndBalances b
join BalanceStats s on b.customer_id = s.customer_id;

-- Option 1: data is allocated based off the amount of money at the end of
-- the previous month

set @running_balance := 0;
set @prev_customer_id := null;
with RunningBalances as (
    select 
        customer_id, 
        txn_date,
        @running_balance := if(@prev_customer_id = customer_id, @running_balance + case when txn_type in ('deposit', 'purchase', 'withdrawal') then txn_amount else 0 end, 
        case when txn_type in ('deposit', 'purchase', 'withdrawal') then txn_amount else 0 end) as running_balance,
        @prev_customer_id := customer_id
    from 
        (select customer_id, txn_date, txn_type, txn_amount from customer_transactions order by customer_id, txn_date) as sorted_transactions
),
MonthEndBalances as (
    select
        customer_id,
        LAST_DAY(txn_date) as month_end,
        MAX(running_balance) as month_end_balance
    from RunningBalances
    group by customer_id, LAST_DAY(txn_date)
),
BalanceStats as (
    select
        customer_id,
        min(running_balance) as min_balance,
        avg(running_balance) as avg_balance,
        max(running_balance) as max_balance
    from RunningBalances
    group by customer_id
),
DataAllocation as (
    select
        b.customer_id, 
        b.month_end,
        b.month_end_balance,
        s.min_balance,
        s.avg_balance,
        s.max_balance,
        (b.month_end_balance / 1000) as data_allocated_GB -- Assuming 1 GB data per $1000 balance
    from MonthEndBalances b
    join BalanceStats s on b.customer_id = s.customer_id
)
select 
    month_end,
    round(SUM(data_allocated_GB),2) as total_data_allocated_GB
from DataAllocation
group by month_end
order by month_end;

-- Option 2: data is allocated on the average amount of money kept in the
-- account in the previous 30 days

set @prev_customer_id := null, @running_balance := 0;

with RunningBalances as (
    select
        customer_id,
        txn_date,
        case 
            when @prev_customer_id = customer_id then @running_balance := @running_balance + txn_amount
            else @running_balance := txn_amount 
        end as running_balance,
        @prev_customer_id := customer_id
    from
        (select customer_id, txn_date, txn_amount from customer_transactions order by customer_id, txn_date) as ordered_transactions
),
MonthEndStats as (
    select
        customer_id,
        date_format(txn_date, '%Y-%m') as month,
        max(running_balance) as month_end_balance,
        min(running_balance) as min_balance,
        avg(running_balance) as avg_balance,
        max(running_balance) as max_balance
    from RunningBalances
    group by customer_id, date_format(txn_date, '%Y-%m')
),
DataAllocation as (
    select
        month,
        round(SUM(avg_balance / 1000),2) as data_allocated_GB -- Assuming 1 GB per $1000 of average balance
    from MonthEndStats
    group by month
)
select * from DataAllocation
order by month;

-- Option 3: data is updated real-time

SET @prev_customer_id := NULL, @running_balance := 0;

with RunningBalances as (
    select
        customer_id,
        txn_date,
        @running_balance := if(@prev_customer_id = customer_id, 
                               @running_balance + case 
                                   when txn_type = 'deposit' then txn_amount 
                                   when txn_type IN ('withdrawal', 'purchase') then -txn_amount 
                                   else 0 
                               end, 
                               case 
                                   when txn_type in ('deposit', 'withdrawal', 'purchase') then txn_amount 
                                   else 0 
                               end) as running_balance,
        @prev_customer_id := customer_id
    from customer_transactions,
         (select @prev_customer_id := 0, @running_balance := 0) as vars
    order by customer_id, txn_date
),
MonthlyStats as (
    select
        customer_id,
        DATE_FORMAT(txn_date, '%Y-%m') as month,
        MAX(running_balance) as month_end_balance,
        MIN(running_balance) as min_balance,
        avg(if(running_balance < 0, 0, running_balance)) AS avg_balance,
        MAX(running_balance) AS max_balance
    from RunningBalances
    group by customer_id, DATE_FORMAT(txn_date, '%Y-%m')
),
TotalDataAllocation as (
    select
        month,
        round(SUM(avg_balance / 1000),2) AS total_data_required_GB -- Assuming 1 GB per $1000 of positive average balance
    from MonthlyStats
   group by month
)
select * from TotalDataAllocation order by month;




