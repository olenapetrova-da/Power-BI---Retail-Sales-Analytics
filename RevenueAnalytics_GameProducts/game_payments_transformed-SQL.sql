-- Table Games_Payments ---
/* the script "user_details" is the basic for Users and Payments tables.
 * For Payments table we need only "first_p_month'. Thhus, in Power BI we just add this column from another table by user_id key*/
/*with  user_Details as
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
*/
/* in this script we add to PAYMENTS table data from pdated User Table */
/* for MONTH data calculation we need here first_p_month from USERS table, 
 * but for PAYMENTS table it is not needed  */
with all_data as 
(
select 
gp.user_id,
gp.payment_date,
gp.revenue_amount_usd, 
date(date_trunc ('month', gp.payment_date)) as p_month,
gp.game_name
from project.games_payments as gp
--inner join project.games_payments as gp on gpu.user_id =gp.user_id 
group by 1,2,3,5
--,9,10,11,12
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
sum(revenue_amount_usd) as month_rev
from all_data
group by 1,2,3,4,5
)
/* In this script for each User are shown: month and revenue + previous month and the next month + their revenue. 
 * If there were no payments in previous/next month, NULL is shown  */
select
md.user_id,
md.game_name,
md.payment_date,
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
group by 1,2,3,4,5,7,9
--)