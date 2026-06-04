# Looker Studio Dashboard Spec

> This document tells you exactly which charts to build in Looker Studio and which dbt mart fields to use. Connect each data source to the BigQuery tables in the `dev_marts` dataset of project `olist-analytics-498115`.

---

## Data sources to add

| Looker Studio data source | BigQuery table |
|---|---|
| `mart_gmv_daily` | `olist-analytics-498115.dev_marts.mart_gmv_daily` |
| `mart_delivery_performance` | `olist-analytics-498115.dev_marts.mart_delivery_performance` |
| `mart_customer_cohorts` | `olist-analytics-498115.dev_marts.mart_customer_cohorts` |
| `fct_orders` | `olist-analytics-498115.dev_marts.fct_orders` |

---

## Page 1 — Executive Summary

**Purpose:** top-level health-check; stakeholder landing page.

### Scorecards (4 cards across the top)
| Card label | Metric | Source | Formula |
|---|---|---|---|
| Total GMV | Sum of `daily_gmv` | `mart_gmv_daily` | `SUM(daily_gmv)` ÷ distinct days |
| Total Orders | `SUM(daily_order_count)` | `mart_gmv_daily` | distinct days |
| Average Order Value | `daily_aov` | `mart_gmv_daily` | `SUM(daily_gmv) / SUM(daily_order_count)` |
| Late Delivery Rate | `late_delivery_rate` | `mart_delivery_performance` | `SUM(late_orders) / SUM(delivered_orders)` |

### Chart 1 — Weekly GMV trend (time series)
- **Type:** Smoothed line chart
- **Source:** `mart_gmv_daily`
- **Dimension:** `order_date` (aggregated to week — use date-truncation in Looker Studio)
- **Metrics:** `SUM(daily_gmv)` (primary axis), `AVG(daily_aov)` (secondary axis)
- **Filter:** exclude rows where `product_category = 'uncategorized'` is optional
- **Date range control:** connect to a page-level date filter on `order_date`

### Chart 2 — GMV by category (horizontal bar)
- **Type:** Horizontal bar chart, sorted descending
- **Source:** `mart_gmv_daily`
- **Dimension:** `product_category`
- **Metric:** `SUM(category_gmv)`
- **Rows shown:** top 15
- **Note:** excludes order-level measures (use `category_gmv`, not `daily_gmv`, for this chart)

---

## Page 2 — Delivery Performance

**Purpose:** understand where and when late deliveries happen.

### Chart 3 — Late delivery rate by Brazilian state (filled map)
- **Type:** Geo chart — Brazil, region level
- **Source:** `mart_delivery_performance`
- **Location dimension:** `customer_state` (2-letter Brazilian state code)
- **Metric:** `SUM(late_orders) / SUM(delivered_orders)` (calculated field: `Late Rate`)
- **Colour scale:** green (0 %) → red (30 %+)
- **Tooltip:** also show `SUM(delivered_orders)` as order count

### Chart 4 — Monthly late delivery rate over time (line)
- **Type:** Line chart
- **Source:** `mart_delivery_performance`
- **Dimension:** `order_month`
- **Metric:** `SUM(late_orders) / SUM(delivered_orders)` (calculated field)
- **Breakdown dimension:** leave blank for overall; optionally add `customer_state` with a dropdown filter

### Chart 5 — Delivery days distribution (histogram / bar)
- **Type:** Bar chart
- **Source:** `fct_orders` (add as a separate data source)
- **Dimension:** calculated bucket: `CASE WHEN delivery_days < 5 THEN '<5d' WHEN delivery_days < 10 THEN '5-9d' ... END`
- **Metric:** `COUNT(order_id)`
- **Filter:** `order_status = 'delivered'`

### Chart 6 — State × month table (sortable)
- **Type:** Table with heatmap
- **Source:** `mart_delivery_performance`
- **Row dimension:** `customer_state`
- **Column dimension / metric:** `AVG(late_delivery_rate)`, `AVG(avg_delivery_days)`, `SUM(delivered_orders)`
- **Heatmap:** on `late_delivery_rate` column

---

## Page 3 — Customer Cohorts

**Purpose:** show acquisition volume over time and the ~3 % repeat-purchase finding.

### Chart 7 — Monthly cohort acquisition (bar)
- **Type:** Bar chart
- **Source:** `mart_customer_cohorts`
- **Filter:** `periods_since_acquisition = 0`
- **Dimension:** `cohort_month`
- **Metric:** `SUM(cohort_size)`

### Chart 8 — Cohort retention heatmap (pivot table)
- **Type:** Pivot table with conditional formatting
- **Source:** `mart_customer_cohorts`
- **Row dimension:** `cohort_month`
- **Column dimension:** `periods_since_acquisition` (0 → 12)
- **Metric:** `AVG(retention_rate)` → format as percentage
- **Conditional formatting:** 100 % = dark blue, 0 % = white
- **Key insight to highlight:** retention at period 1+ is typically 1–4 %, confirming the ~3 % repeat-purchase rate documented in the dbt model descriptions

### Chart 9 — Overall repeat-purchase KPI (scorecard)
- **Type:** Scorecard
- **Source:** `mart_customer_cohorts`
- **Metric:** calculated field:
  ```
  SUM(IF(periods_since_acquisition > 0, active_customers, 0))
  / SUM(IF(periods_since_acquisition = 0, cohort_size, 0))
  ```
- **Label:** "Repeat-purchase rate"
- **Format:** percentage, 1 decimal place

---

## Filters to add (page level)

| Page | Filter | Type |
|---|---|---|
| All pages | Date range | `order_date` / `order_month` / `cohort_month` |
| Page 2 | State selector | `customer_state` dropdown, multi-select |
| Page 3 | Cohort month range | `cohort_month` slider |

---

## Styling notes

- Use a consistent colour for "late" / negative metrics: **coral / #E8735A**
- Use **steelblue / #4A90D9** for GMV and positive metrics
- Dashboard title font: bold, 18 pt
- Add the Olist logo or a placeholder in the top-left corner
- Add a "last refreshed" dynamic date text box pulling from `MAX(order_date)` on `mart_gmv_daily`
