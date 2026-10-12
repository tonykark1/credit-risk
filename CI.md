# Automated validation

`.github/workflows/validate.yml` runs on pushes, pull requests, and manual dispatch. It provisions release R and Python 3.12, ensures `rpart` is available, and executes `python ci/run_checks.py`. The job has read-only repository permissions and a 15-minute timeout. It does not publish or commit generated files.

The runner copies only scripts, raw data, and SQL into a fresh temporary folder. Bundled results cannot satisfy checks. It executes every R module and the SQL controls, verifies SQL status and fault-injection outcomes, counts robustness results, and confirms all five chart files were generated. Nonzero script exits and failed assertions fail the job. Generated results and logs are retained as a `validation-evidence` artifact for 14 days.

## Enable on GitHub

Upload the **contents** of this project folder at repository root, including the hidden `.github/workflows/validate.yml` file. Do not place the project inside an extra folder. Open the repository's Actions tab and inspect the first run. If organization settings disable Actions, an owner must enable it. No secrets are required.

Replace `OWNER` and `REPOSITORY` in this badge template, then paste it below the README title:

```markdown
[![Validate R and SQL](https://github.com/OWNER/REPOSITORY/actions/workflows/validate.yml/badge.svg)](https://github.com/OWNER/REPOSITORY/actions/workflows/validate.yml)
```

The badge reports actual GitHub status. No repository URL was supplied, so no live badge or hosted run is claimed. The workflow and its local runner have been prepared; a local pass is not evidence of a GitHub-hosted pass.

## Local equivalent

```bash
python ci/run_checks.py
```

If Rscript is not on PATH, pass `--rscript` with its full executable path. Logs and fresh outputs appear in `ci-results/`, which is excluded from Git. The job uses release R and the available `rpart` version; this checks current compatibility, not bit-for-bit environment locking. Run-specific versions are recorded in the generated `sessionInfo.txt` and SQL execution metadata.

Action references: [R setup](https://github.com/r-lib/actions), [Python setup](https://github.com/actions/setup-python).
