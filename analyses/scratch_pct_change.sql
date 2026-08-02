-- Exploration/scratch file used to prototype and debug the LAG() and rolling
-- average window function logic before finalizing it in models/marts/fct_daily_prices.sql.
-- Kept as a record of the iterative development process, not part of the build DAG.

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
    from STOCK_PRICES.silver.stg_stock_prices )

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