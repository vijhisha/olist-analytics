# Build brief: Marketplace Analytics Platform

> This document is the build plan for **Claude Code**. Read it fully, then work **one phase at a time**, in order. After each phase: run the phase's acceptance checks, summarize what you did, make a git commit, and stop for my review before starting the next phase. Do **not** skip ahead or do everything in one pass.

---

## 1. What we're building and why

A complete, reproducible **analytics-engineering project** on the Olist Brazilian e-commerce dataset, built as a job-portfolio piece. The goal is to demonstrate end-to-end rigor: raw data → warehouse → tested + documented dbt models (star schema) → analytics marts → a BI dashboard, with CI on every pull request, plus a short causal-analysis + A/B-design write-up.

**Definition of done:** someone can clone the repo, follow the README, and get a green `dbt build` with passing tests; CI runs on PRs; the marts power a dashboard; and there is a documented insight write-up.

**Audience for the final repo:** hiring managers for hybrid analytics-engineer / data-analyst roles. Optimize the repo for *readability and credibility*, not cleverness.

---

## 2. Tech stack

- **Ingestion:** Python 3.11+ (pandas + the BigQuery client, or DuckDB — see §3).
- **Warehouse:** BigQuery (default). DuckDB is a supported drop-in — see the note at the end of §3.
- **Transformation:** dbt (`dbt-bigquery`), with packages `dbt-utils` and `dbt-expectations`.
- **Linting:** `sqlfluff` (dbt templater).
- **CI:** GitHub Actions.
- **Analysis:** a Python notebook (pandas, statsmodels, matplotlib/seaborn).
- **Dashboard:** Looker Studio — built manually by me; you only prepare the marts and a spec doc.

---

## 3. Environment, credentials, and warehouse config

- Python venv at `.venv/`, dependencies pinned in `requirements.txt`.
- **All credentials come from environment variables. Never hardcode or commit secrets.** dbt `profiles.yml` reads the BigQuery project, dataset, and key-file path from env vars (`DBT_BQ_PROJECT`, `DBT_BQ_DATASET`, `GOOGLE_APPLICATION_CREDENTIALS`). Provide a committed `profiles.example.yml` and a `.env.example`; the real `profiles.yml`/`.env`/JSON key are git-ignored.
- Two target datasets: `dev` (default) and `ci` (used by GitHub Actions).
- `.gitignore` must cover: `.venv/`, `.env`, `*.json` credential keys, `target/`, `dbt_packages/`, `logs/`, `.DuckDB`/`*.duckdb`, and `__pycache__/`.

**DuckDB alternative (if I say "use DuckDB"):** swap `dbt-bigquery` for `dbt-duckdb`, point the profile at a local `olist.duckdb` file, and have the Python loader write to DuckDB instead of BigQuery. Keep all model SQL ANSI-standard where possible; isolate any dialect-specific SQL (date functions, `qualify`, etc.) so switching warehouses is a small diff. CI for DuckDB needs no secret — it just builds against a fresh local file.

---

## 4. Target repo structure

```
.
├── PLAN.md
├── README.md
├── requirements.txt
├── .gitignore
├── .env.example
├── .sqlfluff
├── .pre-commit-config.yaml
├── .github/workflows/ci.yml
├── ingestion/
│   └── load_raw.py
├── analysis/
│   ├── delivery_review_causal.ipynb
│   └── ab_test_design.md
├── docs/
│   └── dashboard_spec.md
└── dbt/
    ├── dbt_project.yml
    ├── packages.yml
    ├── profiles.example.yml
    ├── models/
    │   ├── staging/
    │   │   ├── _sources.yml
    │   │   ├── _staging.yml
    │   │   ├── stg_orders.sql
    │   │   ├── stg_order_items.sql
    │   │   ├── stg_order_payments.sql
    │   │   ├── stg_order_reviews.sql
    │   │   ├── stg_customers.sql
    │   │   ├── stg_products.sql
    │   │   ├── stg_sellers.sql
    │   │   └── stg_geolocation.sql
    │   ├── intermediate/
    │   │   ├── int_orders_enriched.sql
    │   │   └── int_order_items_priced.sql
    │   └── marts/
    │       ├── _marts.yml
    │       ├── dim_customers.sql
    │       ├── dim_products.sql
    │       ├── dim_sellers.sql
    │       ├── fct_orders.sql
    │       ├── fct_order_items.sql        # incremental
    │       ├── mart_gmv_daily.sql
    │       ├── mart_delivery_performance.sql
    │       └── mart_customer_cohorts.sql
    ├── snapshots/
    │   └── seller_status_snapshot.sql
    └── tests/
        └── assert_delivery_after_purchase.sql
```

---

## 5. Source data reference

Nine CSVs (Kaggle: `olistbr/brazilian-ecommerce`), already downloaded to a folder I will give you:

| File | Grain | Key columns |
|---|---|---|
| `olist_orders_dataset.csv` | one row per order | `order_id`, `customer_id`, `order_status`, purchase/approved/delivered/estimated timestamps |
| `olist_order_items_dataset.csv` | one row per item per order | `order_id`, `order_item_id`, `product_id`, `seller_id`, `price`, `freight_value` |
| `olist_order_payments_dataset.csv` | one row per payment | `order_id`, `payment_type`, `payment_value` |
| `olist_order_reviews_dataset.csv` | one row per review | `review_id`, `order_id`, `review_score`, timestamps |
| `olist_customers_dataset.csv` | one row per customer key | `customer_id`, `customer_unique_id`, zip/city/state |
| `olist_products_dataset.csv` | one row per product | `product_id`, `product_category_name`, dimensions |
| `olist_sellers_dataset.csv` | one row per seller | `seller_id`, zip/city/state |
| `olist_geolocation_dataset.csv` | zip-prefix → lat/lng | `geolocation_zip_code_prefix` |
| `product_category_name_translation.csv` | category PT → EN | `product_category_name`, `_english` |

Note for modeling: `customer_id` is per-order; `customer_unique_id` is the true person — use the latter for cohort/retention logic. Repeat-purchase rate in this dataset is very low (~3%); that's a real insight, not a bug.

---

## 6. Conventions

- Model layers and prefixes: `stg_` (one model per source, cleaning only), `int_` (joins/logic), `dim_`/`fct_` (dimensional), `mart_` (analytics-ready).
- One model per file. Reference upstream only via `ref()` and `source()` — never hardcode dataset/table names.
- Staging models do **only** renaming, casting, light cleaning. No joins, no business logic.
- Every model and column documented in the relevant `.yml`.
- SQL style enforced by `sqlfluff`; CTEs over nested subqueries; lower-case keywords; trailing commas leading-style is fine — set it in `.sqlfluff` and be consistent.
- Git: conventional commit messages (`feat:`, `chore:`, `test:`, `docs:`), one commit per phase minimum.
- When you hit a **human-owned step** (see §15), stop and tell me exactly what to do; do not fake credentials or invent data.

---

## 7. Phase 0 — Scaffolding

- Initialize git (if not already), create `.gitignore`, `requirements.txt`, `.env.example`, `README.md` skeleton.
- Create the Python venv and install deps.
- `dbt init` (or hand-create) the `dbt/` project; add `packages.yml` with `dbt-utils` and `dbt-expectations`; `dbt deps`.
- Create `profiles.example.yml` (env-var driven) and document the env vars in `.env.example` and README.
- Add `.sqlfluff` and `.pre-commit-config.yaml` (sqlfluff lint hook).
- **Acceptance:** `dbt debug` passes against the `dev` target; `sqlfluff --version` works; `pre-commit run --all-files` runs (may be no-op).

## 8. Phase 1 — Ingestion

- `ingestion/load_raw.py`: reads all 9 CSVs from a configurable `--source-dir`, loads each into a `raw` dataset/schema as `raw_<table>`.
- **Simulate batch loads:** partition the orders load by `order_purchase_timestamp` (e.g. write a `_loaded_date` and load month-by-month) so downstream incremental models are meaningful.
- Idempotent (safe re-runs), with logging of per-table row counts and basic type coercion for the timestamp columns.
- **Acceptance:** all 9 raw tables exist with sensible row counts (orders ≈ 99k, order_items ≈ 112k); counts printed to log; re-running doesn't duplicate rows.

## 9. Phase 2 — Staging

- One `stg_*` model per source: rename to snake_case, cast types (esp. timestamps), trim strings, dedupe geolocation to one row per zip prefix.
- `_sources.yml`: declare all raw tables with `loaded_at_field` + freshness thresholds.
- `_staging.yml`: descriptions for every model/column; tests — `not_null` + `unique` on keys, `relationships` where applicable, `accepted_values` on `order_status` and `payment_type`.
- **Acceptance:** `dbt build --select staging` is green; all staging tests pass.

## 10. Phase 3 — Intermediate + dimensional core

- `int_orders_enriched`: orders joined to delivery timestamps + derived fields (`delivery_days`, `estimated_vs_actual_days`, `is_late` boolean).
- `int_order_items_priced`: items with price + freight rolled to the needed grain.
- Dimensions: `dim_customers` (keyed on `customer_unique_id`), `dim_products` (with English category), `dim_sellers`.
- Facts: `fct_orders` (order grain), `fct_order_items` (item grain, **materialized incremental** on a load/purchase date with a sensible unique key).
- Snapshot: `seller_status_snapshot` capturing a slowly-changing seller attribute (derive an "active/inactive" flag from recent order activity) to demonstrate snapshots.
- **Acceptance:** `dbt build` green; incremental model does a correct incremental run on second invocation; snapshot creates and updates.

## 11. Phase 4 — Analytics marts

- `mart_gmv_daily`: daily GMV, order count, AOV; category mix.
- `mart_delivery_performance`: late-delivery rate, avg delivery days, estimated-vs-actual, sliced by customer state.
- `mart_customer_cohorts`: monthly acquisition cohorts and repeat-purchase behavior (expect the ~3% repeat finding).
- Document every metric definition in `_marts.yml`.
- **Acceptance:** `dbt build` green; spot-check a couple of metric values against a manual query and note them in the commit message.

## 12. Phase 5 — Test hardening + docs

- Add `dbt-utils` tests (e.g. `expression_is_true`, `accepted_range`) and `dbt-expectations` distribution tests (e.g. review_score in 1–5, non-negative prices).
- Add the singular test `tests/assert_delivery_after_purchase.sql` (delivered date never before purchase date).
- Add `exposures` pointing at the Looker Studio dashboard (URL placeholder for now).
- `dbt docs generate`; ensure the lineage graph is complete and descriptions render.
- **Acceptance:** total test count is meaningful (aim 60+); `dbt build` green; `dbt docs generate` succeeds. Report the final model and test counts so I can use the real numbers on my resume.

## 13. Phase 6 — CI

- `.github/workflows/ci.yml`: on `pull_request`, run (1) `sqlfluff lint`, (2) `dbt deps` + `dbt build --target ci`, (3) `dbt source freshness`.
- CI authenticates to BigQuery via a repo secret `GCP_SA_KEY` (the service-account JSON) written to a temp file and pointed to by `GOOGLE_APPLICATION_CREDENTIALS`; project/dataset from repo variables.
- Document in the README exactly how I add the secret/variables.
- **Acceptance:** workflow YAML is valid and lints locally; README documents the secret setup. (The first real CI run happens after I add the secret — flag this as a human step.)

## 14. Phase 7 — Analysis + experiment design

- `analysis/delivery_review_causal.ipynb`: pull from the marts and test **does late delivery lower review scores?** Use an OLS/logit regression with controls (price, freight, product category, customer state, delivery distance proxy). Be explicit that this is **observational** causal inference, state assumptions and confounders, and report the estimated effect with confidence intervals and clear figures.
- `analysis/ab_test_design.md`: design the experiment that would *validate* a faster-delivery intervention — hypothesis, primary + guardrail metrics, randomization unit, MDE, baseline rate, required sample size and test duration, and how you'd analyze it. Keep it concise and rigorous.
- **Acceptance:** notebook runs top to bottom; figures saved to `analysis/figures/`; `ab_test_design.md` complete.

## 15. Phase 8 — README + portfolio polish

- README must include: one-paragraph project pitch, architecture diagram (I'll provide an image — leave a placeholder), the data flow, how to run it locally end to end, the env-var/secret setup, a data dictionary / link to dbt docs, a short "key insights" section (GMV trend, late-delivery effect, ~3% repeat rate), the dashboard link, and screenshots (placeholders).
- Add a `make`-style task list or a short `Taskfile`/shell script for the common commands (`load`, `build`, `test`, `docs`).
- **Acceptance:** a newcomer could follow the README from clone to green build.

---

## 16. Human-owned steps — stop and prompt me, don't attempt these

1. Downloading the Kaggle CSVs (done before you start; I'll give you the folder path).
2. Creating the Google Cloud project, enabling BigQuery, and creating/downloading the service-account JSON key.
3. Adding the `GCP_SA_KEY` secret and project/dataset variables to the GitHub repo (Phase 6).
4. Building the Looker Studio dashboard (Phase 8) — you only produce the marts and `docs/dashboard_spec.md` describing the exact charts, fields, and filters to create.
5. Creating the public GitHub repo and the first `git remote add`.

At each of these points, pause, give me copy-pasteable instructions, and wait.

---

## 17. Working style

- Default to dbt **best practices** over shortcuts; this repo is a craftsmanship showcase.
- Prefer fewer, well-named, well-documented models over many thin ones.
- Keep commits clean and messages descriptive.
- After every phase, post: what changed, the acceptance-check output, and the suggested resume-relevant numbers (model count, test count, row counts, headline metric values).
