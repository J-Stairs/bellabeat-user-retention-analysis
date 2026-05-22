/*
===============================================================================
This query calculates device compliance and tracking habits across a 30-day window.
It aims to pinpoint exactly when and where users abandon their trackers, 
differentiating between active use, passive abandonment (leaving the device 
on a surface), and a complete drop-off in data logging.

CHANGELOG:
  - Standardized user IDs to STRING to resolve cross-table JOIN type mismatches.
===============================================================================
*/

WITH activity_summary AS (
  SELECT 
    CAST(Id AS STRING) AS fitbit_user_id, -- Standardized to STRING
    -- Count how many unique days this user actually logged data
    COUNT(DISTINCT ActivityDate) AS total_days_activity_logged,
    
    -- Track 'Passive Abandonment': Count days where the device was turned on 
    -- but recorded exactly 0 steps and nearly 24 hours of sedentary time
    COUNT(CASE 
            WHEN CAST(TotalSteps AS INT64) = 0 
             AND CAST(SedentaryMinutes AS FLOAT64) >= 1380 -- 1380 mins = 23 hours
            THEN 1 
          END) AS passive_abandonment_days,
          
    -- Calculate their average steps strictly on the days they actually wore it
    ROUND(AVG(CASE WHEN CAST(TotalSteps AS INT64) > 0 THEN CAST(TotalSteps AS INT64) END), 0) AS avg_steps_on_active_days
  FROM 
    `smooth-aura-494613-b7.bellabeat_wellness.daily_activity_raw`
  GROUP BY 
    Id
),

sleep_summary AS (
  SELECT 
    CAST(Id AS STRING) AS fitbit_user_id, -- Standardized to STRING
    -- Count how many unique nights this user wore the tracker to bed
    COUNT(DISTINCT SleepDay) AS total_days_sleep_logged
  FROM 
    `smooth-aura-494613-b7.bellabeat_wellness.daily_sleep_raw`
  GROUP BY 
    Id
)

-- Combine activity tracking and sleep tracking behavior side-by-side
SELECT 
  act.fitbit_user_id,
  act.total_days_activity_logged,
  
  -- If a user never logged sleep, replace the null value with 0 to keep data clean
  COALESCE(slp.total_days_sleep_logged, 0) AS total_days_sleep_logged,
  act.passive_abandonment_days,
  act.avg_steps_on_active_days,
  
  -- Logical Flag: Highlight users who dropped off before the full 30 days ended
  CASE 
    WHEN act.total_days_activity_logged < 25 THEN 'High Churn Risk (<25 Days Logged)'
    ELSE 'Consistent Logger'
  END AS user_retention_segment

FROM 
  activity_summary AS act
LEFT JOIN 
  sleep_summary AS slp 
  ON act.fitbit_user_id = slp.fitbit_user_id
ORDER BY 
  total_days_activity_logged ASC, 
  total_days_sleep_logged ASC;