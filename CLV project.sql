-- Values for both Average Revenue per Customer (ARPU) and Customer Lifetime Value (CLV) are shown in USD

WITH

registration_cohort AS (
  SELECT 
    user_pseudo_id,
    DATE_TRUNC(MIN(PARSE_DATE('%Y%m%d', event_date)), WEEK(SUNDAY)) AS cohort_week
  FROM `turing_data_analytics.raw_events`
  WHERE PARSE_DATE('%Y%m%d', event_date) < '2021-01-31'
  GROUP BY user_pseudo_id
),

revenue_data AS (
  SELECT
    user_pseudo_id,
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(SUNDAY)) AS weeks,
    SUM(purchase_revenue_in_usd) AS revenue
  FROM `turing_data_analytics.raw_events`
  WHERE event_name = 'purchase'
    AND PARSE_DATE('%Y%m%d', event_date) < '2021-01-31'
  GROUP BY user_pseudo_id, weeks
),

cohort_revenue AS (
  SELECT 
    rc.user_pseudo_id,
    rc.cohort_week,
    DATE_DIFF(rd.weeks, rc.cohort_week, WEEK) AS week_offset,
    SUM(COALESCE(rd.revenue, 0)) AS total_revenue
  FROM revenue_data rd
  LEFT JOIN registration_cohort rc 
    ON rc.user_pseudo_id = rd.user_pseudo_id
  GROUP BY rc.user_pseudo_id, rc.cohort_week, week_offset
),

cohort_sizes AS (
  SELECT
    cohort_week,
    COUNT(user_pseudo_id) AS total_customers
  FROM registration_cohort
  GROUP BY cohort_week
),

cohort_avg_revenue AS (
  SELECT
    cr.cohort_week,
    cr.week_offset,
    SUM(cr.total_revenue / cs.total_customers) AS arpu
  FROM cohort_revenue cr
  JOIN cohort_sizes cs 
    ON cs.cohort_week = cr.cohort_week
  GROUP BY cr.cohort_week, cr.week_offset
),

cumulative_values AS (
  SELECT
    cohort_week,
    week_offset,
    SUM(arpu) OVER (PARTITION BY cohort_week ORDER BY week_offset) AS cumulative_clv
  FROM cohort_avg_revenue
  GROUP BY cohort_week, week_offset, arpu
)

SELECT 
  cv.cohort_week,
  cv.week_offset,
  car.arpu,
  cv.cumulative_clv
FROM cohort_avg_revenue car
JOIN cumulative_values cv 
  ON cv.cohort_week = car.cohort_week 
  AND cv.week_offset = car.week_offset
ORDER BY cv.cohort_week, cv.week_offset
