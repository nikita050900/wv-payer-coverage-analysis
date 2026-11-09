# Payer Mix and Coverage Analysis (Oracle SQL, Tableau)

Who pays for hospital visits, how much insurers cover, and what patients pay out of pocket,
across three years (2023 to 2025) of **synthetic** West Virginia visit data.

The data is modeled in Oracle as a small star schema, checked with SQL data-quality rules
on every load, summarized in SQL views, and shown in a Tableau Public dashboard.

> All data is synthetic, generated with [Synthea](https://github.com/synthetichealth/synthea).
> No real patients or claims are involved.

## Findings

22,907 visits by 1,521 patients, $56.98M in charges. Insurers covered 75.9% overall.

| Payer group | Coverage rate | Patient pays per visit |
|---|---:|---:|
| Medicaid | 98.0% | $55 |
| Dual Eligible | 98.6% | $31 |
| Medicare | 81.3% | $363 |
| Commercial (6 insurers) | 65.0% | $1,002 |
| Self-pay (uninsured) | 0.0% | $3,485 |

Commercial coverage varies widely by insurer, from 50.7% (Aetna) to 77.1% (Anthem).

## How it works

```
data/payers.csv, data/encounters.csv
        |  run.py loads them
        v
staging tables (stg_payer, stg_encounter)
        |  sql/02_load.sql
        v
star schema:  fact_encounter  --  dim_payer, dim_date
        |  sql/03_dq_checks.sql (5 checks)   sql/04_views.sql
        v
views: v_payer_summary, v_monthly, v_kpi_summary
        |  exported to tableau/*.csv
        v
Tableau Public dashboard
```

| File | What it does |
|---|---|
| `sql/01_tables.sql` | staging tables, one fact table (one row per visit), two dimensions (payer, date) |
| `sql/02_load.sql` | builds the star schema from staging; re-runnable |
| `sql/03_dq_checks.sql` | 5 data-quality checks: staging vs fact row counts, duplicate IDs, unknown payers, negative amounts, payer paying more than the charge |
| `sql/04_views.sql` | payer summary (mix, coverage rate, out-of-pocket), monthly trend, headline KPIs |
| `run.py` | runs everything in order, confirms every CSV row reached Oracle, exports the views |

Coverage rates are computed as a ratio of sums, `SUM(payer_paid) / SUM(total_charge)`, so
large inpatient stays weigh more than small office visits, as they should.

## Run it

Needs Python 3.9+ and an Oracle database: Oracle Database Free in Docker on your laptop,
or an Oracle Autonomous Database (Always Free tier).

```bash
pip install -r requirements.txt

# Option A: Oracle Database Free in Docker
docker run -d --name orcl -p 1521:1521 -e ORACLE_PASSWORD=Sys_Pass_1 \
  -e APP_USER=payer -e APP_USER_PASSWORD=Payer_Pass_1 gvenzl/oracle-free:23-slim
# wait until `docker logs orcl` says DATABASE IS READY TO USE!
export ORA_USER=payer ORA_PASSWORD=Payer_Pass_1 ORA_DSN=localhost:1521/FREEPDB1

# Option B: Oracle Autonomous Database, using the downloaded wallet
# export ORA_USER=... ORA_PASSWORD=... ORA_DSN=yourdb_low
# export ORA_WALLET_DIR=~/wallet ORA_WALLET_PASSWORD=...

python run.py
```

The database user needs only `CREATE SESSION`, `CREATE TABLE` and `CREATE VIEW`
(plus tablespace quota).

## Limitations

Synthea settles nearly every bill in full on the day of the visit and does not model
denials, so this project does not cover A/R aging or denial rates.
