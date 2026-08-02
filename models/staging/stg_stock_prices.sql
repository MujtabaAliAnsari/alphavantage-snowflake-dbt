with source as (
    select * from {{ source('raw_stock_prices', 'RAW_STOCK_PRICES') }}
),

renamed as (
    select
        TICKER as ticker,
        TO_DATE(date,'YYYY-MM-DD') as report_date,
        cast(OPEN as float) as open,
        cast(HIGH as float) as high,
        cast(LOW as float) as low,
        cast(CLOSE as float) as close,
        cast(VOLUME as number(38,0)) as volume
    from source
)

select * from renamed