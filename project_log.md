# Project Log

> **For Claude Code:** Read this file at the start of every session before doing anything else. It records exactly where the project stands. After every `git commit`, update this file and commit the update in the same commit (or immediately after).

---

## Current State

| Field | Value |
|---|---|
| **Current phase** | Phase 7 complete — ready for Phase 8 |
| **Next action** | README polish + portfolio wrap-up (Phase 8) |
| **Last commit** | `(see below)` — feat: Phase 7 analysis + A/B design |
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

### Phase 3 — Intermediate + Dimensional Core ✅
**Commit:** `7644898`

**Completed:**
- `int_orders_enriched`: delivery_days, estimated_vs_actual_days, is_late derived from order timestamps
- `int_order_items_priced`: item_total = price + freight_value
- `dim_customers` (96,096 rows): deduped to customer_unique_id grain via qualify row_number()
- `dim_products` (32,951 rows): English category joined from raw translation table
- `dim_sellers` (3,095 rows): lat/lng added from stg_geolocation
- `fct_orders` (99,441 rows): order grain with payment + item aggregates
- `fct_order_items` (112,650 rows): **incremental (merge)** on _loaded_date; second run = MERGE (0 rows) ✓
- `seller_status_snapshot` (3,095 rows): check strategy on is_active flag; re-run = no changes ✓
- Full docs in _intermediate.yml and _marts.yml

**dbt build: 96/96 PASS** (80 tests + 14 models + 1 snapshot + 1 incremental)

**BigQuery datasets created:** `dev_intermediate`, `dev_marts`, `snapshots`

### Phase 4 — Analytics Marts ✅
**Commit:** `a1c81a5`

**Completed:**
- `mart_gmv_daily` (18,900 rows): grain (order_date, product_category). Includes category_gmv_share and daily_aov computed via window functions.
- `mart_delivery_performance` (556 rows): grain (order_month, customer_state). Delivered orders only.
- `mart_customer_cohorts` (220 rows): grain (cohort_month, order_month). Classic retention table.
- `_marts.yml` fully extended with all metric definitions.

**Spot-check values (for resume/README):**
| Metric | Value |
|---|---|
| Total GMV (2016-2018) | R$ 15,739,137 |
| Overall late-delivery rate | 8.1% |
| Repeat-purchase rate | ~2% (dataset-level) |
| Top category by GMV | health_beauty (R$1.44M) |
| Highest late-delivery state | AL (Alagoas) — 23.9% |

**Known quirk:** `dbt build` with 4 threads sporadically times out the snapshot due to BigQuery concurrency.
Run as two steps: `dbt build --exclude resource_type:snapshot` then `dbt snapshot`.
119/119 models+tests PASS; snapshot PASS when run standalone.

### Phase 5 — Test Hardening + Docs ✅
**Commit:** `04064e1`

**Completed:**
- Singular test: `tests/assert_delivery_after_purchase.sql` — delivered date never before purchase date
- Exposure: `models/_exposures.yml` — Looker Studio dashboard with URL placeholder
- New tests added across all layers:
  - `dbt_utils.unique_combination_of_columns`: stg_order_items, stg_order_payments, fct_order_items, mart_gmv_daily, mart_delivery_performance, mart_customer_cohorts
  - `dbt_utils.accepted_range`: price ≥0, freight ≥0, payment_value ≥0, late_delivery_rate 0-1, retention_rate 0-1, category_gmv_share 0-1
  - `dbt_utils.expression_is_true`: delivery_days ≥ 0, item_total = price + freight (×2), order_value ≥ 0, item_count ≥ 0
  - `dbt_expectations.expect_column_values_to_be_between`: review_score 1-5
  - `dbt_expectations.expect_column_mean_to_be_between`: review_score 3.5-4.5
  - `dbt_expectations.expect_table_row_count_to_be_between`: stg_geolocation, fct_orders, fct_order_items
- Documented known dirty GPS data in stg_geolocation (~8-9 rows with invalid coordinates)
- `dbt docs generate` → catalog.json written successfully

**Final counts (resume numbers):**
| Metric | Count |
|---|---|
| Models | 18 |
| Data tests | 124 |
| Snapshot | 1 |
| Sources | 9 |
| Exposures | 1 |
| dbt build result | 142/142 PASS |
### Phase 6 — CI ✅
**Commit:** `72de1ae`

**Completed:**
- `.github/workflows/ci.yml` — triggers on pull_request to master/main
  - Step 1: SQLFluff lint (`models/`, dbt templater, 2 processes)
  - Step 2: `dbt build --target ci --exclude resource_type:snapshot`
  - Step 3: `dbt source freshness --target ci` (continue-on-error for historical data)
- README CI Setup section — copy-pasteable instructions for:
  - `GCP_SA_KEY` repository secret (full SA JSON)
  - `DBT_BQ_PROJECT` repository variable
  - Required IAM roles (BigQuery Data Editor + Job User)
  - Note: `ci_staging`, `ci_intermediate`, `ci_marts` datasets auto-created by dbt on first run

**Human step required before first CI run:**
  1. Add `GCP_SA_KEY` secret (full SA JSON) → GitHub repo Settings → Secrets
  2. Add `DBT_BQ_PROJECT` variable = `olist-analytics-498115` → GitHub repo Settings → Variables
  3. Open a PR to trigger the workflow

**YAML validation:** passed (`yaml.safe_load` ✓)

### Phase 7 — Analysis + Experiment Design ✅
**Commit:** `(see below)`

**Completed:**
- `analysis/delivery_review_causal.ipynb` — 13-cell notebook, runs top to bottom
  - Data: 95,604 delivered orders with reviews from BigQuery
  - 3 figures saved to `analysis/figures/`
  - OLS: is_late coef = **−1.18 stars** (p<0.001); delivery_days = **−0.028/day** (p<0.001); R²=0.176
  - Logit AME: is_late = **−18.7 pp** on P(satisfied); delivery_days = **−0.77 pp/day** (both p<0.001)
  - Explicit DAG, backdoor path (seller quality), causal assumptions discussion
- `analysis/ab_test_design.md` — full experiment design
  - MDE: +2 pp satisfaction (77%→79%); n≈5,300/arm; duration ≥4 weeks; ITT analysis

**Key findings (resume-ready):**
| Metric | Value |
|---|---|
| Late-delivery rate | 8.0% |
| OLS is_late effect (controlled) | −1.18 stars *** |
| Logit AME of is_late | −18.7 pp on P(satisfied) *** |
| A/B test sample needed | ~10,600 orders (~4 weeks) |

### Phase 8 — README + Portfolio Polish ⏳ not started
