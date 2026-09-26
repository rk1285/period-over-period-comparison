import os
import duckdb

# File paths
sql_file = 'sql/period-comparison.sql'
output_file = 'outputs/period_comparison_all_markets.csv'

# Ensure directory exists
os.makedirs(os.path.dirname(output_file), exist_ok=True)

# Parameters ($1, $2, $3, $4)
p1_start = '2025-02-01'
p1_end   = '2025-04-30'
p2_start = '2026-02-01'
p2_end   = '2026-04-30'

with open(sql_file, 'r') as f:
    sql_query = f.read()

print("Running full dataset SQL transformation across all markets...")

con = duckdb.connect()

# Pass parameters safely into the COPY execution
export_query = f"COPY ({sql_query}) TO '{output_file}' (HEADER, DELIMITER ',')"
con.execute(export_query, [p1_start, p1_end, p2_start, p2_end])

print(f"Done! Results written to {output_file}")