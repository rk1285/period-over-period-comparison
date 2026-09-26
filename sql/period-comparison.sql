WITH labelled AS (

    SELECT
        market,
        keyword,
        page,
        clicks,
        impressions,
        average_position,

        CASE
            WHEN report_date BETWEEN $1::DATE AND $2::DATE THEN 'P1'
            WHEN report_date BETWEEN $3::DATE AND $4::DATE THEN 'P2'
        END AS period

    FROM 'data/raw/synthetic_seo_snow_rock_dataset_v3.csv'

    WHERE
        report_date BETWEEN $1::DATE AND $2::DATE
        OR
        report_date BETWEEN $3::DATE AND $4::DATE

),

agg AS (
    SELECT
        market,
        keyword,
        page,

        SUM(CASE WHEN period = 'P1' THEN clicks ELSE 0 END) AS clicks_p1,
        SUM(CASE WHEN period = 'P2' THEN clicks ELSE 0 END) AS clicks_p2,

        SUM(CASE WHEN period = 'P1' THEN impressions ELSE 0 END) AS impressions_p1,
        SUM(CASE WHEN period = 'P2' THEN impressions ELSE 0 END) AS impressions_p2,

        SUM(CASE WHEN period = 'P1' THEN average_position * impressions END) 
            / NULLIF(SUM(CASE WHEN period = 'P1' THEN impressions END), 0) AS avg_position_p1,

        SUM(CASE WHEN period = 'P2' THEN average_position * impressions END) 
            / NULLIF(SUM(CASE WHEN period = 'P2' THEN impressions END), 0) AS avg_position_p2

    FROM labelled
    WHERE period IS NOT NULL
    GROUP BY market, keyword, page
),

changes AS (
    SELECT
        *,
        clicks_p2 - clicks_p1 AS clicks_diff,
        ROUND((clicks_p2 - clicks_p1) / NULLIF(clicks_p1, 0), 4) AS clicks_pct_change,
        impressions_p2 - impressions_p1 AS impressions_diff,
        ROUND((impressions_p2 - impressions_p1) / NULLIF(impressions_p1, 0), 4) AS impressions_pct_change,
        ROUND(avg_position_p2 - avg_position_p1, 2) AS position_diff
    FROM agg
),

contribution AS (
    SELECT
        *,
        SUM(clicks_diff) OVER() AS total_click_change,
        ROUND(clicks_diff / NULLIF(SUM(clicks_diff) OVER(), 0), 4) AS contribution_pct
    FROM changes
)

SELECT
    market,
    keyword,
    page,

    CONCAT($1, ' to ', $2) AS period_1,
    CONCAT($3, ' to ', $4) AS period_2,

    clicks_p1,
    clicks_p2,
    clicks_diff,
    clicks_pct_change,

    impressions_p1,
    impressions_p2,
    impressions_diff,
    impressions_pct_change,

    avg_position_p1,
    avg_position_p2,
    position_diff,

    contribution_pct,

    CASE
        WHEN clicks_pct_change >= 0.50 THEN 'Exceptional Growth'
        WHEN clicks_pct_change >= 0.20 THEN 'Strong Growth'
        WHEN clicks_pct_change > 0 THEN 'Growth'
        WHEN clicks_pct_change <= -0.50 THEN 'Severe Decline'
        WHEN clicks_pct_change <= -0.20 THEN 'Strong Decline'
        WHEN clicks_pct_change < 0 THEN 'Decline'
        ELSE 'Flat'
    END AS trend,

    ROUND(ABS(clicks_diff) * (1 + ABS(COALESCE(clicks_pct_change, 0))), 2) AS impact_score,

    CASE
        WHEN clicks_diff > 0 AND position_diff < 0 THEN 'Growth + Ranking Improvement'
        WHEN clicks_diff < 0 AND position_diff > 0 THEN 'Traffic Loss + Ranking Decline'
        WHEN clicks_diff > 0 AND position_diff > 0 THEN 'Growth Despite Position Loss'
        WHEN clicks_diff < 0 AND position_diff < 0 THEN 'Traffic Loss Despite Position Gain'
        ELSE 'Neutral'
    END AS performance_flag

FROM contribution
WHERE clicks_p1 >= 5 OR clicks_p2 >= 5
ORDER BY market, impact_score DESC