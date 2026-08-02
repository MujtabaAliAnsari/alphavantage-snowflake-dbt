import os
from dotenv import load_dotenv
import requests
import json
import pandas as pd
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas

load_dotenv()
API_KEY = os.getenv("API_KEY")
sn_account = os.getenv("sn_account")
sn_user = os.getenv("sn_user")
sn_role = os.getenv("sn_role")
sn_warehouse = os.getenv("sn_warehouse")
sn_database = os.getenv("sn_database")
sn_schema = os.getenv("sn_schema")
sn_password = os.getenv("sn_password")

tickers = ["AAPL", "GOOGL", "IBM"]
flattened_rows = []

for ticker in tickers:

    if os.path.isfile(f'cache/{ticker}.json') == False:
        # replace the "demo" apikey below with your own key from https://www.alphavantage.co/support/#api-key
        url = f'https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol={ticker}&apikey={API_KEY}'
        r = requests.get(url)

        response_data = r.json()

        if 'Time Series (Daily)' in response_data:

            with open(f'cache/{ticker}.json','w') as f:
                json.dump(response_data,f)

    
    if os.path.isfile(f'cache/{ticker}.json'):
        with open(f'cache/{ticker}.json','r') as f:
            response_data = json.load(f)

        for key, value in response_data["Time Series (Daily)"].items():
                        flattened_rows.append( {
                            'Ticker' : ticker,
                            'Date': key,
                            'Open': value['1. open'],
                            'High': value['2. high'],
                            'Low' : value['3. low'],
                            'Close' : value['4. close'],
                            'Volume' : value['5. volume']
                        })

df = pd.DataFrame(flattened_rows)

df.columns = [c.upper() for c in df.columns]
print(df)

conn = snowflake.connector.connect(
    user= sn_user, 
    password= sn_password, 
    account= sn_account, 
    warehouse= sn_warehouse, 
    database= sn_database, 
    schema= sn_schema
)

success, nchunks, nrows, _ = write_pandas(conn, df, table_name='RAW_STOCK_PRICES', auto_create_table=True)
    