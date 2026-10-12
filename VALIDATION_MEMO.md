# Validation memo
**Credit Risk Model Validation & Monitoring in R and SQL**  
**11 October 2026 · Educational portfolio review**  
**Recommendation: retain as a benchmark; do not deploy for lending.**

## Purpose
Assess a logistic credit classifier against a shallow decision tree and constant-score baseline. Training, validation, and test samples separate fitting, selection, and evaluation. This is an author-prepared assessment, not independent validation or regulatory approval.

## Evidence
| Area | Executed evidence | Interpretation |
|---|---|---|
| Discrimination | Test AUC 0.750; bootstrap interval 0.673–0.817 | Useful sample ranking; material uncertainty |
| Probability error | Brier 0.1757 versus baseline 0.2100 | Sample improvement, not population calibration |
| Decisions | 48/60 bad and 65/140 good credits flagged | 80% recall with substantial false flags |
| Robustness | Lower logistic Brier in 48/50 development splits | Descriptive consistency; splits overlap |
| Monitoring | PSI 0.027; designed shift 0.720 | Distribution sensitivity, not proven deterioration |
| Data controls | 12 SQL checks and five fault-injection tests pass | Basic data and split controls operate as intended |

## Material limitations and actions
**Population:** historical, oversampled data do not establish current population PDs or a defined 12-month outcome. Obtain current, representative observations with documented sampling and targets.

**Validation:** one small test set and overlapping resamples cannot establish production reliability. Add out-of-time and external validation, model-estimation uncertainty, and segment performance review.

**Decision use:** costs and profile shifts are illustrative. Confirm business costs, operational capacity, and calibration before selecting a policy.

**Governance:** explanations are associative; excluding demographics does not establish fairness. Review proxies, fairness, lineage, and implementation. Assign monitoring ownership and escalation criteria.

## Conclusion and reproduction
Keep the logistic model as the educational benchmark. No monetary-loss, regulatory-compliance, or deployment-readiness claim is supported. Run `Rscript analysis.R` followed by `python run_sql_checks.py`. R performs modeling; Python's standard-library SQLite driver executes the SQL files. See `results/run_log.txt` and `results/sql_execution.json`. Built with AI assistance; no employer affiliation.
