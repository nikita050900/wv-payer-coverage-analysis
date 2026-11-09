# Building the dashboard in Tableau Public (about 1.5 hours)

Tableau Public is free (Mac and Windows) and reads files, so it uses the CSVs that
`run.py` exports into this folder.

## Connect

1. Install Tableau Public and create a free account.
2. **Connect > Text file > `v_monthly.csv`**.
3. **Data > New Data Source > Text file > `v_payer_summary.csv`**.
4. Check that `month_start` shows as a date and the money columns as numbers.

## Calculated fields (in the `v_monthly` source)

| Name | Formula |
|---|---|
| Coverage Rate | `SUM([Payer Paid]) / SUM([Total Charges])` |
| Patient Paid per Visit | `SUM([Patient Paid]) / SUM([Visits])` |

Format Coverage Rate as a percentage with one decimal and money as currency with no
decimals. Always use these calculations, never an average of the `coverage_rate` column:
averaging rates gives a $50 office visit the same weight as a $50,000 hospital stay.

## Sheets

1. **KPI tiles** (four small sheets, big numbers): Total Charges, Payer Paid,
   Coverage Rate, Patient Paid per Visit.
2. **Monthly trend**: `MONTH(Month Start)` on Columns, Total Charges and Payer Paid on Rows
   as two lines (use Measure Values).
3. **Coverage by payer group**: bars of Coverage Rate by Payer Group, sorted descending.
4. **Out-of-pocket by payer**: bars of Patient Paid per Visit by Payer Name, colored by
   Payer Group, sorted descending.

Everything above can be built from `v_monthly.csv` alone; `v_payer_summary.csv` holds the
same payer totals already aggregated, for a quick check.

## Dashboard

* Size: Automatic, or 1200 x 800.
* Top row: the four KPI tiles. Middle: monthly trend. Bottom: the two bar charts side by side.
* Add filters for Cal Year, Payer Group and Encounter Class, and set them to apply to all
  sheets that use `v_monthly`.
* Title: "Who Pays for Hospital Visits? West Virginia, 2023 to 2025 (synthetic data)".
* Footer: "Synthetic data generated with Synthea. Coverage rate = payer paid / total charges."

## Publish

**File > Save to Tableau Public**. Copy the link into the README and your resume.
