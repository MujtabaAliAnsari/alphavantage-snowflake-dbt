# Alphavantage → Snowflake → dbt: Stock Price ELT Pipeline
A full end-to-end ELT pipeline that extracts daily stock data from the Alpha Vantage API using Python, loads it raw into Snowflake's bronze layer, and transforms it through silver and gold layers using dbt, following a medallion architecture.

## Architecture

![alt text](<Data Lineage.png>)

A brief description of the medallion layers:
- **Bronze** (`STOCK_PRICES.BRONZE.RAW_STOCK_PRICES`): This is where the json data from the cached files are loaded in their raw form. Dates and numbers are all loaded as strings rather than their own data types
- **Silver** (`STOCK_PRICES.SILVER.stg_stock_prices`): Raw string values are cast into proper types — open, high, low, and close are cast to floats, volume is cast to a numeric integer type, and the date column is renamed to report_date (to avoid ambiguity with Snowflake's reserved DATE keyword) and cast to an actual date type.
- **Gold** (`STOCK_PRICES.GOLD.fct_daily_prices`): This is the final form of the data, here each row defines each ticker once per day showing its recorded values for that date along with two aggregated fields 'percent_change' which shows a percent increase or decrease of the current days close value against the previous date and 'prev_seven_day_avg' which is a rolling average of the closing value for each ticker for the past 7 days. 

**Stack:** Python (extract) → Snowflake (storage) → dbt (transform)

## Design Decisions

- **Why no dimension table** — Considering the level of detail provided by the API, there was not enough describing data to build a dimension table. If there was information like region, state, department etc then that would definitely require a dimension table.
- **Why this grain** — Considering that the audience for this data would be stake holders, analysts or investors they would definitely at some point like to see the daily value for each ticker, aggregating the values like close or open per month would not make sense nor would it have signigicant value for decision making. Also a row per ticker per day helps learning against anomolies like sudden drops which I noticed for IBM 
- **Why a 7-day rolling average / day-over-day % change** — A seven day average is something investors or stakeholders like to see before deciding how they want to manage their investments, they may not always go into deeper details like daily activity very often which is why this 7 day average summary gives a good picture. The day over day change percent is more for Analysts since they are often working with the grain level details more closely.
- **Compound uniqueness test on (ticker, report_date)** — As mentioned before, due to less information and identifiers in the provided data, it was not ideal to use ticker or date as a unique identifer but using the logic of a composite key where we combine the report_date and ticker fields as an identifier made more sense specially since the grain of the table was row per ticker per day.

## Data Quality Notes

- **IBM price anomaly (mid-July 2026):** IBM's closing price dropped approximately 25% in a single day, from $290.23 on 2026-07-13 to $217.07 on 2026-07-14, correctly captured by the percent_change field. This kind of move is large enough to warrant investigation before treating it as clean data — in a production setting, this would involve checking for corporate actions (splits, spin-offs) via the vendor or an official source, and cross-referencing market news for the date. Since this is a portfolio project using historical data, the value has been left as-is and flagged here as a known, notable data point rather than corrected or removed.
- **Partial rolling windows:** The rolling average uses a 7-day window (6 preceding days plus the current day). Since each ticker's data begins on a fixed start date, the first 6 rows per ticker don't have a full 7 days of history available — Snowflake computes the average using however many prior rows actually exist, so these early values represent a shorter window, not a true 7-day average.


## Bugs Caught During Development

- **Silent overwrite in early extract loop:** An initial version of the fetch script reassigned a single `data` variable inside the ticker loop instead of accumulating results, so only the last ticker's response was ever retained. Fixed by collecting each ticker's response into a dictionary/list instead of overwriting a single variable.
- **Caching failed API responses:** The extract script initially cached whatever the API returned, including rate-limit error responses, which meant a failed fetch could get "stuck" as permanently cached bad data. Fixed by validating that `'Time Series (Daily)'` was present in the response before writing it to the cache file.
- **`.env` key name mismatches:** Several early runs failed silently (`None` values, not exceptions) because the string passed to `os.getenv()` didn't exactly match the key name in the `.env` file. Resolved by aligning variable names exactly and adopting clearer, prefixed naming (e.g., `sn_account`) going forward.
- **Curly-brace vs. f-string confusion in the Snowflake connection:** Connection parameters were briefly wrapped in `{}`, which Python interpreted as set literals rather than variable references, causing a `'set' object has no attribute 'find'` error. Fixed by passing the variables directly as keyword arguments.
- **Column reference ordering in `fct_daily_prices`:** An early version of the day-over-day `percent_change` calculation tried to reference a `prev_close` alias within the same `SELECT` list it was defined in. Snowflake actually supports this (lateral column referencing), but the logic was restructured into layered CTEs for clarity and portability to other SQL engines that don't support this behavior.
- **Rolling window off-by-one:** `ROWS BETWEEN 7 PRECEDING AND CURRENT ROW` was initially used for a "7-day" rolling average, which actually includes 8 rows (7 prior + current). Corrected to `6 PRECEDING AND CURRENT ROW` for a true 7-day window.
- **Broken lineage from hardcoded table reference:** `fct_daily_prices.sql` initially referenced `stg_stock_prices` via its fully-qualified Snowflake path instead of `{{ ref('stg_stock_prices') }}`. The model still ran correctly, but dbt's lineage graph showed it as disconnected from the rest of the pipeline, since dbt tracks dependencies through `ref()`/`source()` calls, not literal table names. Fixed by switching to `ref()`.

## Security & Access

- Dedicated least-privilege Snowflake role (`STOCK_PIPELINE_ROLE`), scoped to only the specific schemas (`BRONZE`, `SILVER`, `GOLD`) and warehouse this pipeline needs — replacing the broader default role used during initial development.
- All secrets (API key, Snowflake credentials) are loaded via environment variables (`.env`) and never hardcoded in source files.
- `.env`, `profiles.yml`, and cached API responses (`cache/`) are excluded from version control via `.gitignore`.


## Setup / How to Run

1. Clone the repo
2. Install dependencies: `pip install -r requirements.txt`
3. Create a `.env` file in the project root with:
    API_KEY=your_alphavantage_key
    sn_account=your_snowflake_account
    sn_user=your_snowflake_user
    sn_password=your_snowflake_password
    sn_role=your_snowflake_role
    sn_warehouse=your_warehouse
    sn_database=STOCK_PRICES
    sn_schema=BRONZE
4. Create `~/.dbt/profiles.yml` (outside this project folder) pointing to your Snowflake account, using `env_var()` to reference the same variables from `.env`. See `profiles.yml.example` for a template.
5. Run the extract script to fetch and load raw data: `python alphavantage_api_data_fetch.py`
6. Install dbt packages: `dbt deps`
7. Build the models: `dbt run`
8. Run tests: `dbt test`
9. Generate and view documentation: `dbt docs generate && dbt docs serve`

## Tech Stack

Python · Snowflake · dbt (Fusion engine, dbt Core 1.12) · Alpha Vantage API
