import os
import duckdb

# File paths
sql_file = 'sql/period-comparison.sql'
output_file = 'outputs/period_comparison_all_markets.csv'

# Ensure the destination output directory exists
os.makedirs(os.path.dirname(output_file), exist_ok=True)

# Read the SQL query
with open(sql_file, 'r') as f:
    sql_query = f.read()

print("Running full dataset SQL transformation across all markets...")

# Create a connection instance to handle multi-statement variables and COPY execution
con = duckdb.connect()

# Wrap and execute the query script
export_query = f"COPY ({sql_query}) TO '{output_file}' (HEADER, DELIMITER ',')"
con.execute(export_query)

print(f"Done! Results written to {output_file}")