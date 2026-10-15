# SBA credit-risk project migration (15 October 2026)

This repository's current `main` branch contains the **South German Credit** exercise (1,000 observations). The updated CV-aligned project supplied separately is a **different US SBA 7(a) loan study** with 112,256 observations. The two projects must not be mixed or represented as the same validation.

## Updated study — source archive results

- **Data:** 112,256 curated SBA loans: 40,000 from 2016–2018 (train), 45,312 from 2021 (validation), and 26,944 from January–June 2024 (test).
- **Target:** recorded charge-off within 730 days of first disbursement, not a regulatory definition of PD.
- **Models:** logistic regression, shallow depth-three probability regression tree, and a constant training-prevalence baseline. Model selection uses validation Brier score.
- **Test discrimination:** selected logistic AUC approximately **0.735**; tree AUC approximately **0.812**.
- **Test Brier:** logistic approximately **0.014995**; tree **0.009312**; constant baseline **0.008537**. The baseline is best on this metric.
- **Calibration:** logistic mean test prediction about **5.07%** versus observed charge-off rate **0.86%**. The selected model materially overpredicts.
- **Monitoring:** training-reference score PSI about **0.146** on validation and **1.078** on test. PSI is descriptive; it does not prove drift causality.
- **Controls:** 14 SQL controls, eight intentional SQL faults, 12 output-corruption tests and repeated clean executions are reported as passing in the supplied local verification evidence. No hosted GitHub Actions pass is claimed.

## Material methodological qualifications

The SBA extract is a later administrative snapshot and not all features have independently verified origination-time immutability. Borrower identification relies on an approximate hashed name/ZIP proxy. The inspected 2024 test is not a sealed external validation. No production deployment, IFRS 9 compliance, regulatory PD calibration, causality or achieved business savings is claimed.

## Required repository migration

The full SBA archive is **not** contained in this migration note or branch. In particular, do not overwrite the main README or repurpose the old German-credit outputs as SBA evidence without importing and rerunning the actual SBA source, curated data and results.

To publish the complete updated project:

1. Keep a legacy branch or tag for the South German Credit version (Git history also preserves it).
2. From the supplied `sba-credit-risk-r-cv-aligned.zip`, extract the inner `sba-credit-risk-r/` directory and sync its files to a dedicated branch. Include `data/loans.csv`, `data/provenance.json`, `data/sba_dictionary.xlsx`, R and Python scripts, SQL scripts, documentation, report and selected result CSVs/figures.
3. Exclude `ci-results/` duplicates, transient logs, personal application documents and unnecessary model serialization before committing. Keep SHA-256 provenance and the exact 112,256-record study sample.
4. The archive already includes `.github/workflows/validate.yml`; install it at the repository root alongside the SBA project, after deciding whether to replace or preserve the German-credit project.
5. Run `Rscript analysis.R`, `python run_sql_checks.py`, `python ci/check_outputs.py`, and `python ci/run_checks.py` in the SBA project directory. Review the outputs and wait for hosted CI to report success before merging.

**Windows PowerShell import outline** (run from the extracted SBA project directory; review files before pushing):

```powershell
git clone https://github.com/tonykark1/credit-risk.git
cd credit-risk
git switch -c sba-full-import
# Copy the extracted SBA project files here, preserving directories.
# Do not copy the archive's top-level wrapper folder.
git status --short
git add -A
git commit -m "Migrate to SBA out-of-time credit-risk validation"
git push -u origin sba-full-import
```

This document is a *migration specification*, not evidence that code or data from the uploaded SBA archive have already been committed to GitHub.
