-- 03_dq_checks.sql
-- Five data-quality checks. Each returns how many rows fail; 0 means pass.
-- (run.py also checks that every CSV row reached staging.)

SELECT 'Staging rows = fact rows' AS check_name,
       ABS((SELECT COUNT(*) FROM stg_encounter) - (SELECT COUNT(*) FROM fact_encounter)) AS failed_rows
  FROM dual
UNION ALL
SELECT 'No duplicate visit IDs',
       COUNT(*)
  FROM (SELECT encounter_id FROM stg_encounter GROUP BY encounter_id HAVING COUNT(*) > 1)
UNION ALL
SELECT 'Every visit has a known payer',
       COUNT(*)
  FROM stg_encounter e
 WHERE NOT EXISTS (SELECT 1 FROM stg_payer p WHERE p.payer_id = e.payer_id)
UNION ALL
SELECT 'No negative amounts',
       COUNT(*)
  FROM fact_encounter
 WHERE total_charge < 0 OR payer_paid < 0
UNION ALL
SELECT 'Payer never pays more than the charge',
       COUNT(*)
  FROM fact_encounter
 WHERE payer_paid > total_charge + 0.01
/
