---   MONTH users by categories --
/* here we calculate categories of users :
 * - Active users: New + Returned + Retained 
 * - Churned */
/* ! To calculate 'first_p_month in the final MONTH table, 
 * we should include it in all scripts after calculating in CTE user_details */

/* the script "user_details" is the basic for Users and Payments tables.
 * For MONTHS table we need only "first_p_month', therefore it is included in this script.
 * but for PAYMENTS table it is not needed (there is no 'user_details' table and "first_p_month' variable in script PAYMENTS.
 * in Power BI we just add this column from another table by user_id key*/
create function f_PeriodLastMonth()
returns date 
language plpgsql
as $$
declare period_end date;
begin
select max(date(date_trunc ('month', payment_date))) into period_end FROM project.games_payments;
return period_end;
end;
$$

with  user_Details as
(
select 
gpu.user_id,
gpu.language,
gpu.age,
min(date(date_trunc ('month', gp.payment_date))) as first_p_month,
max(date(date_trunc ('month', gp.payment_date))) as last_p_month,
(max(gp.payment_date)-min(gp.payment_date))+1 as LT_days, 
count(distinct date(date_trunc ('month', gp.payment_date))) as months_paid,
count(gp.payment_date) as transactions,
sum(gp.revenue_amount_usd) as LTV
from project.games_paid_users gpu
left join project.games_payments gp on gpu.user_id =gp.user_id 
group by 1,2,3
)
,
/* in this script we add to PAYMENTS table data from pdated User Table */
all_data as 
(
select 
gp.user_id,
gp.payment_date,
gp.revenue_amount_usd, 
date(date_trunc ('month', gp.payment_date)) as p_month,
gpu.first_p_month,
gp.game_name
from user_Details as  gpu
inner join project.games_payments as gp on gpu.user_id =gp.user_id 
group by 1,2,3,5,6
order by 1
)
,
--/* In this script for each user is calculated revenue by each month they paid.
-- * It will be used in the nex CTE to show prev month and prev month rev*/
user_monthly_data as
(
select 
user_id,
game_name,
payment_date,
revenue_amount_usd,
p_month,
first_p_month,
sum(revenue_amount_usd) as month_rev
from all_data
group by 1,2,3,4,5,6
)
,
--/* In this script for each User are shown: month and revenue + previous month and the next month + their revenue. 
-- * If there were no payments in previous/next month, NULL is shown  */
user_prev_next_data as 
(
select
md.user_id as user_id,
md.game_name,
md.payment_date,
md.first_p_month as first_p_month,
md.revenue_amount_usd,
md.p_month,
sum(md.month_rev) as month_rev,
pmd.p_month as prev_month, 
sum(pmd.month_rev) as prev_month_rev,
nmd.p_month as next_month, 
sum(nmd.month_rev) as next_month_rev
from user_monthly_data as md
left join user_monthly_data as pmd on pmd.p_month=md.p_month - interval '1 month' and pmd.user_id=md.user_id
left join user_monthly_data as nmd on nmd.p_month=md.p_month + interval '1 month' and nmd.user_id=md.user_id
group by 1,2,3,4,5,6,8,10
),
month_users_pivot as 
(
select 
p_month ,
prev_month,
next_month,
first_p_month,
count (distinct user_id) as users,
case 
	when p_month=first_p_month then count(distinct user_id)
	else null
end new_users,
case  
	when prev_month is null then count(distinct user_id)
end as new_n_returned,
case  
	when next_month is null then count(distinct user_id)
end as churned_u
from user_prev_next_data 
group by 1,2,3,4
order by 1
)
select 
p_month,
sum(users) as users,
sum(new_users) as new_users,
sum(new_n_returned)- sum(new_users) as returned_u,
sum(users)-sum(new_n_returned) as retained_u,
case 
	when p_month<f_PeriodLastMonth() then sum(churned_u) 
end as churned_u
from month_users_pivot
group by 1
--,2,3,4,5,6
order by 1


