/* ==========================================
USER INPUTS
========================================== */

SET PERIOD_1_START = '2025-02-01';
SET PERIOD_1_END = '2025-04-30';

SET PERIOD_2_START = '2026-02-01';
SET PERIOD_2_END = '2026-04-30';

SET MARKET = 'United Kingdom';


/* ==========================================
PERIOD COMPARISON ANALYSIS
========================================== */

WITH labelled AS (

SELECT
keyword,
page,
clicks,
impressions,
position,

CASE
WHEN report_date BETWEEN $PERIOD_1_START AND $PERIOD_1_END THEN 'P1'
WHEN report_date BETWEEN $PERIOD_2_START AND $PERIOD_2_END THEN 'P2'
END AS period

FROM '\data\raw\synthetic_seo_snow_rock_dataset_v3.csv'

WHERE
(
report_date BETWEEN $PERIOD_1_START AND $PERIOD_1_END
OR
report_date BETWEEN $PERIOD_2_START AND $PERIOD_2_END
)
AND market = $MARKET


),

/* ==========================================
AGGREGATED PERFORMANCE
========================================== */

agg AS (

SELECT

keyword,
page,

/* Clicks */
SUM(CASE WHEN period = 'P1' THEN clicks ELSE 0 END) AS clicks_p1,
SUM(CASE WHEN period = 'P2' THEN clicks ELSE 0 END) AS clicks_p2,

/* Impressions */
SUM(CASE WHEN period = 'P1' THEN impressions ELSE 0 END) AS impressions_p1,
SUM(CASE WHEN period = 'P2' THEN impressions ELSE 0 END) AS impressions_p2,

/* Weighted Average Position */
SUM(
CASE
WHEN period = 'P1'
THEN position * impressions
END
)
/
NULLIF(
SUM(
CASE
WHEN period = 'P1'
THEN impressions
END
),
0) AS avg_position_p1,

SUM(
CASE
WHEN period = 'P2'
THEN position * impressions
END
)
/
NULLIF(
SUM(
CASE
WHEN period = 'P2'
THEN impressions
END
),
0) AS avg_position_p2

FROM labelled

WHERE period IS NOT NULL

GROUP BY
keyword,
page

),

/* ==========================================
CHANGE CALCULATIONS
========================================== */

changes AS (

SELECT

*,

/* Absolute Click Change */
clicks_p2 - clicks_p1 AS clicks_diff,

/* Percentage Click Change */
ROUND(
(clicks_p2 - clicks_p1)
/ NULLIF(clicks_p1,0)
,4) AS clicks_pct_change,

/* Absolute Impression Change */
impressions_p2 - impressions_p1 AS impressions_diff,

/* Percentage Impression Change */
ROUND(
(impressions_p2 - impressions_p1)
/ NULLIF(impressions_p1,0)
,4) AS impressions_pct_change,

/* Position Movement */
ROUND(
avg_position_p2 - avg_position_p1
,2) AS position_diff

FROM agg

),

/* ==========================================
CONTRIBUTION ANALYSIS
========================================== */

contribution AS (

SELECT

*,

SUM(clicks_diff) OVER() AS total_click_change,

ROUND(clicks_diff / NULLIF(SUM(clicks_diff) OVER(),0),4) AS contribution_pct

FROM changes

)

/* ==========================================
FINAL OUTPUT
========================================== */

SELECT

keyword,
page,

CONCAT($PERIOD_1_START,' to ',$PERIOD_1_END) AS period_1,
CONCAT($PERIOD_2_START,' to ',$PERIOD_2_END) AS period_2,

/* ---------------------
Click Metrics
--------------------- */

clicks_p1,
clicks_p2,
clicks_diff,
clicks_pct_change,

/* ---------------------
Impression Metrics
--------------------- */

impressions_p1,
impressions_p2,
impressions_diff,
impressions_pct_change,

/* ---------------------
Visibility Metrics
--------------------- */

avg_position_p1,
avg_position_p2,
position_diff,

/* ---------------------
Growth Contribution
--------------------- */

contribution_pct,

/* ---------------------
Trend Classification
--------------------- */

CASE

WHEN clicks_pct_change >= 0.50 THEN 'Exceptional Growth'

WHEN clicks_pct_change >= 0.20 THEN 'Strong Growth'

WHEN clicks_pct_change > 0 THEN 'Growth'

WHEN clicks_pct_change <= -0.50 THEN 'Severe Decline'

WHEN clicks_pct_change <= -0.20 THEN 'Strong Decline'

WHEN clicks_pct_change < 0 THEN 'Decline'

ELSE 'Flat'

END AS trend,

/* ---------------------
Impact Score

Combines:
- Scale of change
- Relative change
--------------------- */

ROUND(ABS(clicks_diff) * (1 + ABS(COALESCE(clicks_pct_change,0))),2) AS impact_score,

/* ---------------------
Flags
--------------------- */

CASE
    WHEN clicks_diff > 0 AND position_diff < 0 THEN 'Growth + Ranking Improvement'
    WHEN clicks_diff < 0 AND position_diff > 0 THEN 'Traffic Loss + Ranking Decline'
    WHEN clicks_diff > 0 AND position_diff > 0 THEN 'Growth Despite Position Loss'
    WHEN clicks_diff < 0 AND position_diff < 0 THEN 'Traffic Loss Despite Position Gain'
    ELSE 'Neutral'
END AS performance_flag

FROM contribution

WHERE
clicks_p1 >= 5 OR clicks_p2 >= 5

ORDER BY
impact_score DESC;

