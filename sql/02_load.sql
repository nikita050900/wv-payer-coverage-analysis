-- 02_load.sql
-- Moves data from staging into the star schema. Safe to re-run:
-- it clears the star tables first, then rebuilds them.

DELETE FROM fact_encounter
/
DELETE FROM dim_payer
/
DELETE FROM dim_date
/

-- Payers: give each one a numeric key and a reporting group.
INSERT INTO dim_payer (payer_key, payer_id, payer_name, payer_group)
SELECT ROW_NUMBER() OVER (ORDER BY payer_name),
       payer_id,
       CASE WHEN payer_name = 'NO_INSURANCE' THEN 'No insurance' ELSE payer_name END,
       CASE
         WHEN payer_name = 'Medicare'      THEN 'Medicare'
         WHEN payer_name = 'Medicaid'      THEN 'Medicaid'
         WHEN payer_name = 'Dual Eligible' THEN 'Dual Eligible'
         WHEN ownership  = 'PRIVATE'       THEN 'Commercial'
         WHEN ownership  = 'NO_INSURANCE'  THEN 'Self-pay'
         ELSE 'Other'
       END
  FROM stg_payer
/

-- Dates: one row for each day that has at least one visit.
INSERT INTO dim_date (date_key, cal_date, cal_year, cal_month, month_start)
SELECT DISTINCT
       TO_NUMBER(TO_CHAR(start_ts, 'YYYYMMDD')),
       TRUNC(CAST(start_ts AS DATE)),
       EXTRACT(YEAR FROM start_ts),
       EXTRACT(MONTH FROM start_ts),
       TRUNC(CAST(start_ts AS DATE), 'MM')
  FROM stg_encounter
/

-- Visits: look up the payer key and work out what the patient paid.
-- An inner join drops visits whose payer is missing; the data-quality
-- checks catch that by comparing staging and fact row counts.
INSERT INTO fact_encounter (encounter_id, date_key, payer_key, patient_id,
                            encounter_class, total_charge, payer_paid, patient_paid)
SELECT e.encounter_id,
       TO_NUMBER(TO_CHAR(e.start_ts, 'YYYYMMDD')),
       p.payer_key,
       e.patient_id,
       e.encounter_class,
       e.total_claim_cost,
       e.payer_coverage,
       e.total_claim_cost - e.payer_coverage
  FROM stg_encounter e
  JOIN dim_payer p ON p.payer_id = e.payer_id
/
COMMIT
/
