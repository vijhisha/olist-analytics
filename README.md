# Olist Analytics Platform

[![CI](https://github.com/vijhisha/olist-analytics/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/vijhisha/olist-analytics/actions/workflows/ci.yml)

> An end-to-end analytics-engineering project on the [Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — built as a portfolio showcase for analytics-engineer and data-analyst roles.

<!-- ARCHITECTURE DIAGRAM — drop your image at docs/architecture.png and uncomment:
![Architecture](docs/architecture.png)
-->

---

## Overview

This project ingests 100k+ marketplace orders (2016–2018, R$15.7M GMV) from nine raw CSVs into BigQuery, transforms them through a three-layer dbt pipeline, validates the data with 124 automated tests, and surfaces the results in a Looker Studio dashboard. A causal regression notebook quantifies the late-delivery effect on customer reviews, and a companion A/B test design document lays out how you would validate that finding with a randomised experiment.

**Why it matters for a hiring manager:** the repo demonstrates the full workflow an analytics engineer owns in production — ingestion, modelling, testing, CI, and analysis — with the code quality and documentation rigour you'd expect in a team setting.

---

## Tech Stack

| Layer | Tool |
|---|---|
| **Ingestion** | Python 3.12 + `google-cloud-bigquery` |
| **Warehouse** | BigQuery (GCP) |
| **Transformation** | dbt 1.11 (`dbt-bigquery`) |
| **Testing** | dbt generic tests + `dbt-utils` + `dbt-expectations` |
| **Linting** | SQLFluff 3.3 (BigQuery dialect, dbt templater) |
| **CI** | GitHub Actions |
| **Analysis** | Jupyter, pandas, statsmodels, seaborn |
| **Dashboard** | Looker Studio |

---

## Data Flow

```
9 Olist CSVs (data/)
        │
        ▼
Python ingestion script          ← load_raw.py
        │   month-by-month batch load (orders)
        │   idempotent full-replace (all other tables)
        ▼
BigQuery: raw dataset            ← 9 raw_* tables, 99k–1M rows each
        │
        ▼
dbt staging layer                ← dev_staging dataset
        │   rename, cast, clean, dedupe
        │   8 stg_* views, 52 tests
        ▼
dbt intermediate layer           ← dev_intermediate dataset
        │   delivery metrics, price roll-ups
        ▼
dbt marts layer                  ← dev_marts dataset
        │   star schema dims + facts (incremental fct_order_items)
        │   3 analytics marts (GMV, delivery, cohorts)
        ▼
Looker Studio dashboard          ← see docs/dashboard_spec.md
        │
        ▼
Analysis notebook                ← analysis/delivery_review_causal.ipynb
```

---

## Repository Structure

```
.
├── Makefile                        # common commands: load / build / test / docs
├── requirements.txt                # pinned Python deps (Python 3.12)
├── .env.example                    # env var template — copy to .env
├── .sqlfluff                       # BigQuery dialect, dbt templater
├── .pre-commit-config.yaml         # sqlfluff + standard hooks
├── .github/workflows/ci.yml        # PR checks: lint → build → freshness
│
├── ingestion/
│   └── load_raw.py                 # CSV → BigQuery raw dataset (idempotent)
│
├── dbt/
│   ├── dbt_project.yml
│   ├── packages.yml                # dbt-utils 1.3 + dbt-expectations 0.10
│   ├── profiles.example.yml        # env-var-driven profile (copy to ~/.dbt/)
│   ├── models/
│   │   ├── _exposures.yml          # Looker Studio exposure
│   │   ├── staging/                # 8 stg_* views + sources + tests
│   │   ├── intermediate/           # int_orders_enriched, int_order_items_priced
│   │   └── marts/                  # dims, fcts, 3 analytics marts
│   ├── snapshots/
│   │   └── seller_status_snapshot.sql
│   └── tests/
│       └── assert_delivery_after_purchase.sql
│
├── analysis/
│   ├── delivery_review_causal.ipynb   # OLS/logit: does late delivery hurt scores?
│   ├── ab_test_design.md              # RCT design for the delivery intervention
│   └── figures/                       # saved notebook outputs
│
└── docs/
    └── dashboard_spec.md              # exact chart specs for Looker Studio
```

---

## Quick Start

### Prerequisites

- Python 3.12
- A GCP project with BigQuery enabled
- A service-account JSON key with `BigQuery Data Editor` + `BigQuery Job User` roles
- The 9 Olist CSVs in `data/` (download from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce))

### 1. Clone and create virtual environment

```bash
git clone https://github.com/vijhisha/olist-analytics.git
cd olist-analytics

# Linux / macOS
python3.12 -m venv .venv && source .venv/bin/activate

# Windows (PowerShell)
py -3.12 -m venv .venv && .\.venv\Scripts\Activate.ps1

pip install -r requirements.txt
```

### 2. Set environment variables

```bash
cp .env.example .env
# Edit .env — three variables required:
```

| Variable | Example value | Notes |
|---|---|---|
| `DBT_BQ_PROJECT` | `olist-analytics-498115` | Your GCP project ID |
| `DBT_BQ_DATASET` | `dev` | Target dbt dataset prefix |
| `GOOGLE_APPLICATION_CREDENTIALS` | `/path/to/olist-sa-key.json` | Absolute path to SA key |

> On Linux/macOS: `export $(cat .env | xargs)` to load the file into your shell.

### 3. Configure dbt profile

```bash
mkdir -p ~/.dbt
cp dbt/profiles.example.yml ~/.dbt/profiles.yml
# profiles.yml reads directly from env vars — no further edits needed
```

### 4. Verify the BigQuery connection

```bash
cd dbt
dbt deps    # install dbt-utils + dbt-expectations
dbt debug   # should print "All checks passed"
cd ..
```

### 5. Load raw data into BigQuery

```bash
make load
# or: python ingestion/load_raw.py --source-dir data/
```

Expected output: 9 tables in the `raw` dataset, orders ≈ 99k rows, order_items ≈ 113k rows.

### 6. Build the dbt pipeline

```bash
make build
# or: cd dbt && dbt build --exclude resource_type:snapshot
```

Expected: **142 steps — 0 errors, 0 warnings.**

### 7. Run snapshots

```bash
make snapshot
# Run separately from build to avoid a BigQuery concurrency timeout
```

### 8. (Optional) Explore dbt docs

```bash
make docs
# Opens http://localhost:8080 — full lineage graph + data dictionary
```

---

## Common Commands

```bash
make load        # ingest raw CSVs → BigQuery
make build       # dbt deps + dbt build (models + tests, no snapshots)
make test        # dbt test only
make snapshot    # dbt snapshot
make freshness   # dbt source freshness (will warn — historical data)
make docs        # generate + serve dbt docs
make all         # load + build + snapshot end to end
make clean       # remove dbt build artefacts
```

---

## CI / GitHub Actions

CI runs on every pull request via `.github/workflows/ci.yml`:

1. **SQLFluff lint** — BigQuery dialect, dbt templater
2. **`dbt build --target ci`** — full model + test run against the `ci` dataset
3. **`dbt source freshness`** — informational; `continue-on-error: true` for this historical dataset

---

## CI Setup

**One-time setup before your first PR:**

### 1. Add the `GCP_SA_KEY` repository secret

Go to **Settings → Secrets and variables → Actions → New repository secret**

- Name: `GCP_SA_KEY`
- Value: paste the full contents of your service-account JSON key file

### 2. Add the `DBT_BQ_PROJECT` repository variable

Same page → **Variables tab → New repository variable**

- Name: `DBT_BQ_PROJECT`
- Value: `olist-analytics-498115`

### 3. Required IAM roles for the service account

| Role | Purpose |
|---|---|
| `BigQuery Data Editor` | Create / write datasets and tables |
| `BigQuery Job User` | Submit query jobs |

The `ci_staging`, `ci_intermediate`, and `ci_marts` BigQuery datasets are created automatically by dbt on the first CI run.

---

## Key Insights

These numbers come from the marts built by this pipeline and are reproducible by anyone who follows the Quick Start above.

### 1. GMV and scale (2016–2018)

| Metric | Value |
|---|---|
| Total GMV | **R$15.7M** |
| Total orders | **99,441** |
| Average order value | **R$158** |
| Top category by GMV | **health_beauty** (R$1.44M, 9.1% of GMV) |

GMV grew ~5× from 2017 Q1 to 2018 Q2 before the dataset ends.

### 2. Late delivery and its effect on reviews

| Metric | Value |
|---|---|
| Overall late-delivery rate | **8.1%** |
| Raw score gap (on-time vs late) | **−1.7 stars** |
| Controlled OLS estimate (`is_late`) | **−1.18 stars** (p < 0.001) |
| Logit marginal effect on P(satisfied ≥ 4) | **−18.7 percentage points** (p < 0.001) |
| Worst state (late rate, min 100 orders) | **Alagoas — 23.9%** |

The controlled effect is smaller than the raw gap, consistent with seller quality being a partial confounder. See `analysis/delivery_review_causal.ipynb` for the full regression and causal assumptions.

### 3. Repeat-purchase rate

Olist's customer base is almost entirely single-purchase: **~3% of unique customers ever make a second order**. This is a real property of the marketplace (short dataset window + single-category shopping), not a data quality issue. It is documented in the dbt model descriptions and surfaces clearly in `mart_customer_cohorts`.

---

## Data Dictionary

The dbt marts layer exposes five tables for analysis and dashboarding:

| Model | Grain | Key metrics |
|---|---|---|
| `mart_gmv_daily` | order_date × category | `daily_gmv`, `daily_aov`, `category_gmv_share` |
| `mart_delivery_performance` | order_month × customer_state | `late_delivery_rate`, `avg_delivery_days`, `avg_days_early` |
| `mart_customer_cohorts` | cohort_month × order_month | `cohort_size`, `active_customers`, `retention_rate` |
| `fct_orders` | order | `order_value`, `delivery_days`, `is_late`, `item_count` |
| `fct_order_items` | order × item (incremental) | `price`, `freight_value`, `item_total` |

For full column-level definitions, descriptions, and lineage, run `make docs` locally or browse the hosted dbt docs (link coming after first build).

---

## Dashboard

The Looker Studio dashboard covers GMV trends, delivery performance by state, and monthly customer cohorts.

<!-- Add the live link once published:
[View Dashboard](https://lookerstudio.google.com/reporting/PLACEHOLDER)
-->

<!-- Screenshot placeholder:
![Dashboard](docs/dashboard_screenshot.png)
-->

See [`docs/dashboard_spec.md`](docs/dashboard_spec.md) for the exact chart specifications, field names, and filter configurations needed to rebuild it.

---

## Analysis

- **[`analysis/delivery_review_causal.ipynb`](analysis/delivery_review_causal.ipynb)** — OLS and logit regression on 95k delivered orders; causal DAG; figures
- **[`analysis/ab_test_design.md`](analysis/ab_test_design.md)** — full RCT design for a priority-shipping intervention: hypothesis, MDE, sample size (~10k orders), ITT analysis plan, decision rule

---

## dbt Docs

Run locally:

```bash
make docs
# → http://localhost:8080
```

The docs site includes the full DAG lineage (raw → staging → intermediate → marts → Looker Studio exposure), column-level descriptions for all 18 models, and the 124 data-quality test definitions.
