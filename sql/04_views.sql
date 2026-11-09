-- 04_views.sql
-- Analysis views that the dashboard reads.
-- Rates are always a ratio of sums: SUM(paid) / SUM(charge).
-- Averaging per-visit rates would let a $50 visit count as much as a $50,000 stay.

-- One row per payer: payer mix, coverage rate, out-of-pocket cost.
CREATE OR REPLACE VIEW v_payer_summary AS
SELECT p.payer_group,
       p.payer_name,
       COUNT(*)                                                  AS visits,
       SUM(f.total_charge)                                       AS total_charges,
       SUM(f.payer_paid)                                         AS payer_paid,
       SUM(f.patient_paid)                                       AS patient_paid,
       ROUND(RATIO_TO_REPORT(SUM(f.total_charge)) OVER (), 4)    AS share_of_charges,
       ROUND(SUM(f.payer_paid) / SUM(f.total_charge), 4)         AS coverage_rate,
       ROUND(SUM(f.patient_paid) / COUNT(*), 2)                  AS patient_paid_per_visit
  FROM fact_encounter f
  JOIN dim_payer p ON p.payer_key = f.payer_key
 GROUP BY p.payer_group, p.payer_name
/

-- One row per month, payer and visit type: the trend (and the dashboard's data source).
CREATE OR REPLACE VIEW v_monthly AS
SELECT d.month_start,
       d.cal_year,
       p.payer_group,
       p.payer_name,
       f.encounter_class,
       COUNT(*)            AS visits,
       SUM(f.total_charge) AS total_charges,
       SUM(f.payer_paid)   AS payer_paid,
       SUM(f.patient_paid) AS patient_paid
  FROM fact_encounter f
  JOIN dim_date  d ON d.date_key  = f.date_key
  JOIN dim_payer p ON p.payer_key = f.payer_key
 GROUP BY d.month_start, d.cal_year, p.payer_group, p.payer_name, f.encounter_class
/

-- One row with the headline numbers.
CREATE OR REPLACE VIEW v_kpi_summary AS
SELECT COUNT(*)                                           AS visits,
       COUNT(DISTINCT patient_id)                         AS patients,
       SUM(total_charge)                                  AS total_charges,
       SUM(payer_paid)                                    AS payer_paid,
       ROUND(SUM(payer_paid) / SUM(total_charge), 4)      AS coverage_rate,
       ROUND(SUM(patient_paid) / COUNT(*), 2)             AS patient_paid_per_visit
  FROM fact_encounter
/
