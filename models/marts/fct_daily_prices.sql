WITH AGGREGATED AS (
    select
        ticker,
        report_date,
        open,
        high,
        low,
        volume,
        close,
        lag(close) over (partition by ticker order by report_date) as prev_close,
        (CLOSE-PREV_CLOSE)/PREV_close as PERCENT_CHANGE,
        AVG(CLOSE) OVER (PARTITION BY TICKER ORDER BY REPORT_DATE ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS PREV_SEVEN_DAY_AVG
    from {{ ref('stg_stock_prices') }} )

SELECT
    report_date,
    ticker,
    open,
    low,
    high,
    volume,
    close,
    percent_change,
    prev_seven_day_avg
FROM aggregated