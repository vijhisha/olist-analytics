# Olist Analytics Platform

> An end-to-end analytics-engineering project on the [Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), built as a portfolio piece for analytics-engineer / data-analyst roles.

<!-- ARCHITECTURE DIAGRAM PLACEHOLDER -->
<!-- ![Architecture](docs/architecture.png) -->

---

## Project Overview

_One-paragraph pitch coming in Phase 8._

**Stack:** Python · BigQuery · dbt · Looker Studio · GitHub Actions

---

## Data Flow

```
Raw CSVs → Python ingestion → BigQuery raw dataset
         → dbt staging → dbt intermediate → dbt marts
         → Looker Studio dashboard
```

---

## Repository Structure

```
.
├── ingestion/          # Python loader — raw CSVs → BigQuery
├── dbt/                # dbt project (staging → intermediate → marts)
│   ├── models/
│   │   ├── staging/
│   │   ├── intermediate/
│   │   └── marts/
│   ├── snapshots/
│   └── tests/
├── analysis/           # Causal analysis notebook + A/B test design
└── docs/               # Dashboard spec
```

---

## Quick Start

### Prerequisites

- Python 3.11+
- A GCP project with BigQuery enabled and a service-account JSON key
- A `dev` dataset created in BigQuery (e.g. `olist_dev`)

### 1. Clone and set up Python environment

```bash
git clone https://github.com/vijhisha/olist-analytics-platform.git
cd olist-analytics-platform

python -m venv .venv
# Windows
.venv\Scripts\activate
# macOS/Linux
source .venv/bin/activate

pip install -r requirements.txt
```

### 2. Configure environment variables

```bash
cp .env.example .env
# Edit .env with your real values
```

| Variable | Description |
|---|---|
| `DBT_BQ_PROJECT` | GCP project ID (e.g. `olist-analytics-498115`) |
| `DBT_BQ_DATASET` | BigQuery dataset for dbt output (e.g. `dev`) |
| `GOOGLE_APPLICATION_CREDENTIALS` | Absolute path to your service-account JSON key |

### 3. Configure dbt profile

```bash
cp dbt/profiles.example.yml ~/.dbt/profiles.yml
# profiles.yml reads from env vars — no edits needed if .env is set
```

### 4. Install dbt packages and verify connection

```bash
cd dbt
dbt deps
dbt debug
```

### 5. Load raw data

```bash
cd ..
python ingestion/load_raw.py --source-dir data/
```

### 6. Run the full dbt pipeline

```bash
cd dbt
dbt build
```

---

## CI / GitHub Actions

CI runs on every pull request via `.github/workflows/ci.yml`. The pipeline:

1. **SQLFluff lint** — checks all SQL in `dbt/models/` against the BigQuery dialect
2. **`dbt build --target ci`** — runs all models and tests against a dedicated `ci` BigQuery dataset
3. **`dbt source freshness`** — checks source staleness (runs but doesn't fail CI; see note below)

> **Note on source freshness:** The Olist dataset is historical (2016–2018), so freshness checks always report stale data. The step is set to `continue-on-error: true` intentionally — it demonstrates the pattern without breaking CI on known-static data. A live pipeline would remove that flag.

---

## CI Setup

**This is a one-time human step — do this before opening your first PR.**

### 1. Add the `GCP_SA_KEY` repository secret

This is the full contents of your service-account JSON key file.

1. Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `GCP_SA_KEY`
4. Value: paste the entire contents of `olist-sa-key.json` (the JSON object, starting with `{`)
5. Click **Add secret**

### 2. Add the `DBT_BQ_PROJECT` repository variable

1. On the same page, click the **Variables** tab
2. Click **New repository variable**
3. Name: `DBT_BQ_PROJECT`
4. Value: `olist-analytics-498115`
5. Click **Add variable**

### 3. Verify the service-account permissions

The service account needs these BigQuery IAM roles on the project:

| Role | Purpose |
|---|---|
| `BigQuery Data Editor` | Create/write to datasets and tables |
| `BigQuery Job User` | Submit query jobs |

### 4. First CI run

Push a branch and open a pull request. The `dbt-ci` job will appear under **Checks**. On the first run, dbt will automatically create the `ci_staging`, `ci_intermediate`, and `ci_marts` datasets in BigQuery.

---

## Key Insights

_To be filled in Phase 8 after marts are built._

- **GMV trend:** …
- **Late delivery effect on reviews:** …
- **Repeat-purchase rate:** ~3%

---

## Dashboard

_Looker Studio link — coming after Phase 8._

<!-- ![Dashboard screenshot](docs/dashboard_screenshot.png) -->

---

## dbt Docs

Run `dbt docs generate && dbt docs serve` inside `dbt/` to browse the full lineage graph and data dictionary locally.
