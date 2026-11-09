"""
Load the CSVs into Oracle, build the star schema, run the data-quality
checks, and export the analysis views for Tableau.

    python run.py

Connection settings come from environment variables:
    ORA_USER, ORA_PASSWORD, ORA_DSN
    ORA_WALLET_DIR, ORA_WALLET_PASSWORD   (only for an Oracle Cloud wallet)
"""
import os
import sys
from pathlib import Path

import oracledb
import pandas as pd

HERE = Path(__file__).resolve().parent


def connect():
    try:
        args = dict(user=os.environ["ORA_USER"], password=os.environ["ORA_PASSWORD"],
                    dsn=os.environ["ORA_DSN"])
    except KeyError as missing:
        sys.exit(f"Set the environment variable {missing} first (see README).")
    wallet = os.environ.get("ORA_WALLET_DIR")
    if wallet:
        args.update(config_dir=wallet, wallet_location=wallet,
                    wallet_password=os.environ.get("ORA_WALLET_PASSWORD"))
    return oracledb.connect(**args)


def statements(sql_file):
    """Split a .sql file into statements on lines that contain only '/'."""
    text = (HERE / "sql" / sql_file).read_text()
    parts = [p.strip() for p in text.split("\n/\n")]
    keep = []
    for p in parts:
        code = [line for line in p.splitlines() if line.strip() and not line.strip().startswith("--")]
        if code:
            keep.append(p)
    return keep


def run_file(cur, sql_file):
    for stmt in statements(sql_file):
        cur.execute(stmt)


def drop_old_tables(cur):
    for table in ["fact_encounter", "dim_date", "dim_payer", "stg_encounter", "stg_payer"]:
        try:
            cur.execute(f"DROP TABLE {table} PURGE")
        except oracledb.DatabaseError:
            pass  # table did not exist yet


def load_csv(cur, csv_name, table, ts_cols=()):
    df = pd.read_csv(HERE / "data" / csv_name)
    for col in ts_cols:
        df[col] = pd.to_datetime(df[col]).dt.to_pydatetime()
    df = df.astype(object).where(df.notna(), None)
    cols = list(df.columns)
    sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({', '.join(':' + c for c in cols)})"
    cur.executemany(sql, df.to_dict("records"))
    cur.execute(f"SELECT COUNT(*) FROM {table}")
    staged = cur.fetchone()[0]
    status = "PASS" if staged == len(df) else "FAIL"
    print(f"  {status}  {csv_name}: {len(df):,} rows in file, {staged:,} in {table}")


def main():
    con = connect()
    cur = con.cursor()

    print("1. Creating tables")
    drop_old_tables(cur)
    run_file(cur, "01_tables.sql")

    print("2. Loading CSVs into staging")
    load_csv(cur, "payers.csv", "stg_payer")
    load_csv(cur, "encounters.csv", "stg_encounter", ts_cols=["start_ts"])
    con.commit()

    print("3. Building the star schema")
    run_file(cur, "02_load.sql")

    print("4. Data-quality checks")
    cur.execute(statements("03_dq_checks.sql")[0])
    for name, failed in cur.fetchall():
        print(f"  {'PASS' if failed == 0 else 'FAIL'}  {name} ({failed} failing rows)")

    print("5. Creating analysis views and exporting them for Tableau")
    run_file(cur, "04_views.sql")
    out = HERE / "tableau"
    out.mkdir(exist_ok=True)
    for view in ["v_payer_summary", "v_monthly", "v_kpi_summary"]:
        cur.execute(f"SELECT * FROM {view}")
        cols = [c[0].lower() for c in cur.description]
        df = pd.DataFrame(cur.fetchall(), columns=cols)
        df.to_csv(out / f"{view}.csv", index=False)
        print(f"  {view}.csv ({len(df):,} rows)")

    print("\nHeadline numbers")
    print(pd.read_csv(out / "v_kpi_summary.csv").to_string(index=False))


if __name__ == "__main__":
    main()
