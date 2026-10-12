# Executed SQL controls

Run `python run_sql_checks.py` after `analysis.R` (Python 3.10+; no packages needed). It loads bundled data and the R split manifest into an in-memory SQLite database and executes `sql/quality_checks.sql` and `sql/portfolio_profile.sql`. Modeling remains in R.

All 12 controls passed: source count, source-row ID uniqueness, missing values, category domains, positive numeric values, outcome counts, split-ID uniqueness, split names, matching in both directions, split sizes, and split outcome balance.

Five fault-injection tests verified detection of a null amount, invalid category, negative duration, duplicate split ID, and missing split assignment. Each transaction is rolled back; source files never change. The script exits nonzero on control failure.

Outputs: `results/sql_quality_checks.csv`, `results/sql_portfolio_profile.csv`, and `results/sql_execution.json` (source SHA-256, SQLite version, and test outcomes).

IDs are ingestion positions, not verified borrower identities. Counts are benchmark-specific. These controls cannot establish source accuracy or catch every defect. Failure measures are counts or, for size checks, count deviations.
