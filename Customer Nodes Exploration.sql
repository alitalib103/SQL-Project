-- 1. How many unique nodes are there on the Data Bank system?
select count(distinct node_id) as unique_nodes
from customer_nodes;

-- 2. What is the number of nodes per region?
select region_id, 
       count(distinct node_id) as nodes_per_region
from customer_nodes
group by region_id
order by region_id;

-- 3. How many customers are allocated to each region?
select region_id,
	   count(distinct customer_id) as Customers_per_region
from customer_nodes
group by region_id
order by region_id;

-- 4. How many days on average are customers reallocated to a different node?
select node_id, 
       round(avg(datediff(end_date, start_date)),2) as average_Reallocation_days
from customer_nodes
where end_date is not null and year(end_date) <> 9999
group by node_id
order by node_id;

 
-- 5. What is the median, 80th and 95th percentile for this same reallocation
--    days metric for each region?
set @row_num = 0, @current_region = '', @total_rows = 0;
select region_id,
       round(avg(case when percentile_rank = 0.50 then reallocation_days end),2) as Median,
       round(avg(case when percentile_rank = 0.80 then reallocation_days end),2) as '80th Percentile',
       round(avg(case when percentile_rank = 0.95 then reallocation_days end),2) as '95th Percentile'
from (
    select 
        data.*,
        @row_num := if(@current_region = region_id, @row_num + 1, 1) as 'row_number',
        @total_rows := if(@current_region = region_id, @total_rows, cnt_region) as total_rows,
        @current_region := region_id,
        case 
            when @total_rows > 0 then round((@row_num / @total_rows), 2) 
            else 0 
        end as percentile_rank
    from (
        select 
            region_id, 
            datediff(end_date, start_date) as reallocation_days,
            count(*) over(partition by region_id) as cnt_region
        from customer_nodes
        where end_date is not null and year(end_date) <> 9999
        order by region_id, datediff(end_date, start_date)
    ) as data
) as ranked
where percentile_rank in (0.50, 0.80, 0.95)
group by region_id;



