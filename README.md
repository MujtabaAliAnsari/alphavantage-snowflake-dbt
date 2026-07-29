# alphavantage-snowflake-dbt
A full end-to-end ELT pipeline that extracts daily stock data from the Alpha Vantage API using Python, loads it raw into Snowflake's bronze layer, and transforms it through silver and gold layers using dbt, following a medallion architecture.
