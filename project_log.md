# Project Log

> **For Claude Code:** Read this file at the start of every session before doing anything else. It records exactly where the project stands. After every `git commit`, update this file and commit the update in the same commit (or immediately after).

---

## Current State

| Field | Value |
|---|---|
| **Current phase** | Phase 0 complete — ready for Phase 1 |
| **Next action** | Implement `ingestion/load_raw.py` (Phase 1) |
| **Last commit** | `532cc68` — chore: run dbt deps and fix deprecated package names |
| **Branch** | `master` |
| **Remote** | https://github.com/vijhisha/olist-analytics-platform |

---

## Environment

| Setting | Value |
|---|---|
| Python | 3.12.10 (`.venv/`) — created with `py -3.12 -m venv .venv` |
| dbt | 1.11.11 |
| sqlfluff | 3.3.1 |
| Warehouse | BigQuery — project `olist-analytics-498115` |
| dbt target (dev) | dataset `dev` |
| dbt target (ci) | dataset `ci` |
| Key file | `C:\Users\bhand\.gcp\olist-sa-key.json` (git-ignored) |
| dbt profile | `~/.dbt/profiles.yml` (copied from `dbt/profiles.example.yml`) |

**Required env vars (set before running dbt or the ingestion script):**
```
DBT_BQ_PROJECT=olist-analytics-498115
DBT_BQ_DATASET=dev
GOOGLE_APPLICATION_CREDENTIALS=C:\Users\bhand\.gcp\olist-sa-key.json
```

**How to activate the venv (PowerShell):**
```powershell
.\.venv\Scripts\Activate.ps1
```

**How to run dbt (AppLocker blocks the dbt.exe directly — use python -m):**
```powershell
# From the dbt/ directory:
..\\.venv\Scripts\python -m dbt.cli.main <command>
# e.g.:
..\\.venv\Scripts\python -m dbt.cli.main debug
..\\.venv\Scripts\python -m dbt.cli.main build
```

---

## Phase History

### Phase 0 — Scaffolding ✅
**Commit:** `4ac1f13` (initial), `532cc68` (dbt deps)

**Completed:**
- Git repo initialized; connected to `origin` (GitHub)
- `.gitignore`, `requirements.txt`, `.env.example`, `README.md` skeleton
- Python 3.12 venv at `.venv/`; all deps installed
- `dbt/dbt_project.yml` — staging/intermediate → views, marts → tables
- `dbt/packages.yml` — dbt-utils 1.3.0 + metaplane/dbt_expectations 0.10.4
- `dbt/profiles.example.yml` — env-var-driven dev + ci targets; copied to `~/.dbt/profiles.yml`
- `.sqlfluff` — bigquery dialect, dbt templater, lower-case, trailing commas
- `.pre-commit-config.yaml` — sqlfluff-lint + standard hooks
- Directory stubs created for all model layers, snapshots, tests, ingestion, analysis, docs

**Acceptance checks passed:**
- `dbt debug` → All checks passed (BigQuery connection OK)
- `sqlfluff --version` → 3.3.1
- `pre-commit` installed

**Known quirk:** `dbt.exe` / `pip.exe` are blocked by Windows AppLocker in this environment. Always use `python -m dbt.cli.main` and `python -m pip` instead of the bare executables.

---

### Phase 1 — Ingestion ⏳ not started
- `ingestion/load_raw.py`: reads all 9 CSVs → BigQuery `raw` dataset as `raw_<table>`
- Simulate batch loads by partitioning orders on `order_purchase_timestamp`
- Idempotent; log per-table row counts
- **Acceptance:** 9 raw tables in BQ, orders ≈ 99k, order_items ≈ 112k; re-run safe

---

### Phase 2 — Staging ⏳ not started
### Phase 3 — Intermediate + Dimensional Core ⏳ not started
### Phase 4 — Analytics Marts ⏳ not started
### Phase 5 — Test Hardening + Docs ⏳ not started
### Phase 6 — CI ⏳ not started
### Phase 7 — Analysis + Experiment Design ⏳ not started
### Phase 8 — README + Portfolio Polish ⏳ not started
