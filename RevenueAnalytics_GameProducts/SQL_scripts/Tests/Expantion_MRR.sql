--  Espansion MRR  --
--
-- In this script we create two tables - MRR and Retention Users Revenue, 
-- and then join them to calculate Espansion MRR --
--
-- START MRR table --
with 
user_rev as (
select 
user_id,
date(date_trunc ('month', payment_date)) as p_month,
sum(revenue_amount_usd) as month_rev
from project.games_payments 
group by 1,2
order by 1
)
, user_mont_rev as (
select 
user_id,
p_month as month,
sum(month_rev) as rev
from user_rev
group by 1,2
)
, mrr as (
select 
month,
sum(rev) as rev
from user_mont_rev
group by 1
)
--  END of MRR table  ----
, 
-- START Retention MRR --
joined_rev as 
(
select 
m.user_id,
m.p_month,
m.month_rev,
pm.p_month as prev_month
from user_rev as m
left join user_rev as pm on pm.p_month=m.p_month - interval '1 month' and pm.user_id=m.user_id
group by 1,2,3,4
)
, retained_users as (  
select --select [Users, who retained,] only! with specifying prev month, retention month, and revenue in ret month
user_id,
p_month,
month_rev,
prev_month
from joined_rev
where extract(month from p_month)-extract(month from prev_month)=1
group by 1,2,3,4
)
,
retension_rev as (
select 
p_month,
sum(month_rev) as month_rev
from retained_users as ru
--left join project.games_payments gp on date(date_trunc ('month', gp.payment_date))= ru.p_month-1
group by 1
)
-- END of Retention MRR table --
,
--  Start joint MRR and Retention MRR and calculate Expansion MRR --
retention_vs_mrr as (
select 
rr.p_month as month,
rr.month_rev as retention_mrr,
mrr.month as prev_month,
mrr.rev as prev_month_rev
from retension_rev as rr
join mrr as mrr on extract(month from mrr.month)=extract(month from rr.p_month)-1 
group by 1,2,3,4
order by 1
)
select 
month,
retention_mrr,
prev_month,
prev_month_rev,
retention_mrr-prev_month_rev,
round((retention_mrr-prev_month_rev)/prev_month_rev*100,2) as Expansion_mrr
from retention_vs_mrr
group by 1,2,3,4
order by 1
