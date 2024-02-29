-------- ABOUT --------------------
/* In this script we update USER table "games_paid_users" 
 * with SUMMARY details on user activities 
 * at the END of period */

/* I includes:
 * - function to calculate the last month of the period
 * - scripd adding to User their LT and LTV data: 
 * LT: First and Last payment date, LT days, count of Month paid, 
 * LTV: count of tranzactions (tayment dates for the entire period), LTV (sum of payments for the entire period).  
 * - script calculating LT_months, U_Status, Churn_status (if was returned from churn at least once during the period)
 */
-------- END of About -----
/* Functuion returns the last month of the period 
 * We need it to calculate User Status at the end of the period */
/*
create function f_PeriodLastMonth()
returns date 
language plpgsql
as $$
declare period_end date;
begin
select max(date(date_trunc ('month', payment_date))) into period_end FROM project.games_payments;
return period_end;
end;$$
*/
/* Crete a table with additional information on User */
with user_Details as
(
select 
gpu.user_id,
gpu.game_name,
gpu.language,
gpu.age,
min(date(date_trunc ('month', gp.payment_date))) as first_p_month,
max(date(date_trunc ('month', gp.payment_date))) as last_p_month,
(max(gp.payment_date)-min(gp.payment_date))+1 as LT_days, 
count(distinct date(date_trunc ('month', gp.payment_date))) as months_paid,
count(gp.payment_date) as transactions,
sum(gp.revenue_amount_usd) as LTV
from project.games_paid_users gpu
inner join project.games_payments gp on gpu.user_id =gp.user_id 
group by 1,2,3,4
)
/* add to the table caclulated measures - LT_months, U_Status, Churn_status */
select 
user_id,
game_name,
language,
age,
first_p_month,
last_p_month,
LT_days, -- period between max and min
extract(month from last_p_month)-extract(month from first_p_month)+1 as LT_months, --number of calendar months (bins) including the month of min and the month of max
months_paid, -- number of monthes where were transactions
transactions, -- number of payments made by user during the period
LTV,
case 
	when last_p_month<f_PeriodLastMonth() then 'Churned'
	else 'Active' end
	as U_Status,
case 
	when extract(month from last_p_month)-extract(month from first_p_month)+1 >months_paid then 'Returned'
else null 
end 
as Churn_status
from user_Details

