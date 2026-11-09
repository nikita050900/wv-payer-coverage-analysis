-- 01_tables.sql
-- Staging tables hold the CSV files as they arrive.
-- The star schema (one fact table, two dimension tables) is what the analysis reads.
-- Each statement ends with a line containing only "/".

-- Staging: one table per CSV file
CREATE TABLE stg_payer (
  payer_id    VARCHAR2(36),
  payer_name  VARCHAR2(100),
  ownership   VARCHAR2(30)
)
/
CREATE TABLE stg_encounter (
  encounter_id      VARCHAR2(36),
  patient_id        VARCHAR2(36),
  payer_id          VARCHAR2(36),
  start_ts          TIMESTAMP,
  encounter_class   VARCHAR2(20),
  total_claim_cost  NUMBER(12,2),
  payer_coverage    NUMBER(12,2)
)
/

-- Dimension: who pays
CREATE TABLE dim_payer (
  payer_key    NUMBER        PRIMARY KEY,
  payer_id     VARCHAR2(36)  NOT NULL UNIQUE,
  payer_name   VARCHAR2(100) NOT NULL,
  payer_group  VARCHAR2(20)  NOT NULL      -- Medicare, Medicaid, Dual Eligible, Commercial, Self-pay
)
/

-- Dimension: when (one row per calendar day that has a visit)
CREATE TABLE dim_date (
  date_key     NUMBER(8)  PRIMARY KEY,     -- YYYYMMDD, e.g. 20240315
  cal_date     DATE       NOT NULL,
  cal_year     NUMBER(4)  NOT NULL,
  cal_month    NUMBER(2)  NOT NULL,
  month_start  DATE       NOT NULL
)
/

-- Fact: one row per visit (encounter), with its dollars
CREATE TABLE fact_encounter (
  encounter_id     VARCHAR2(36) PRIMARY KEY,
  date_key         NUMBER(8)    NOT NULL REFERENCES dim_date (date_key),
  payer_key        NUMBER       NOT NULL REFERENCES dim_payer (payer_key),
  patient_id       VARCHAR2(36) NOT NULL,
  encounter_class  VARCHAR2(20) NOT NULL,  -- ambulatory, emergency, inpatient, ...
  total_charge     NUMBER(12,2) NOT NULL,  -- billed amount
  payer_paid       NUMBER(12,2) NOT NULL,  -- amount the insurer covered
  patient_paid     NUMBER(12,2) NOT NULL   -- total_charge - payer_paid (out of pocket)
)
/
