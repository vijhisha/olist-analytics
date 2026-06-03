# Project Log

> **For Claude Code:** Read this file at the start of every session before doing anything else. It records exactly where the project stands. After every `git commit`, update this file and commit the update in the same commit (or immediately after).

---

## Current State

| Field | Value |
|---|---|
| **Current phase** | Phase 2 complete — ready for Phase 3 |
| **Next action** | Implement intermediate + dimensional models (Phase 3) |
| **Last commit** | `81166b4` — feat: Phase 2 staging |
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

### Phase 1 — Ingestion ✅
**Commit:** `c8af8ca`

**Completed:**
- `ingestion/load_raw.py` — reads all 9 CSVs, loads into `olist-analytics-498115.raw`
- Orders loaded month-by-month (25 batches, 2016-09 → 2018-10), `_loaded_date` column added
- All other tables use WRITE_TRUNCATE (full-replace, idempotent)
- Timestamp columns coerced: orders (5 cols), order_items (1 col), order_reviews (2 cols)
- BOM stripped from product_category_name_translation headers

**Row counts (verified idempotent on two runs):**
| Table | Rows |
|---|---|
| raw_customers | 99,441 |
| raw_geolocation | 1,000,163 |
| raw_order_items | 112,650 |
| raw_order_payments | 103,886 |
| raw_order_reviews | 99,224 |
| raw_orders | 99,441 |
| raw_products | 32,951 |
| raw_sellers | 3,095 |
| raw_product_category_name_translation | 71 |

---

### Phase 2 — Staging ✅
**Commit:** `81166b4`

**Completed:**
- 8 staging views in `dev_staging` dataset (BigQuery)
- `_sources.yml` — all 9 raw tables declared with descriptions; freshness on raw_orders (`_loaded_date`), raw_order_items (`shipping_limit_date`), raw_order_reviews (`review_answer_timestamp`)
- `_staging.yml` — full column descriptions + tests for all 8 models
- All casts: price/freight/payment_value → FLOAT64, order_item_id/review_score/installments → INT64
- `stg_geolocation`: deduped 1 000 163 rows → 19 015 unique zip prefixes via AVG lat/lng + ANY_VALUE city/state
- `stg_order_reviews`: deduped 789 duplicate review_ids (known source data issue) via `qualify row_number()`
- `stg_products`: fixed two source typos (`product_name_lenght` → `product_name_length`, etc.)
- `stg_customers` / `stg_sellers`: city lowercased + trimmed

**Tests: 52/52 passed**
- 20 not_null, 7 unique, 6 relationships, 2 accepted_values (order_status, payment_type), 1 accepted_values (review_score, quote:false)

**dbt datasets created:** `dev_staging`

### Phase 3 — Intermediate + Dimensional Core ⏳ not started
### Phase 3 — Intermediate + Dimensional Core ⏳ not started
### Phase 4 — Analytics Marts ⏳ not started
### Phase 5 — Test Hardening + Docs ⏳ not started
### Phase 6 — CI ⏳ not started
### Phase 7 — Analysis + Experiment Design ⏳ not started
### Phase 8 — README + Portfolio Polish ⏳ not started
