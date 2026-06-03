#!/usr/bin/env python3
"""
Load all 9 Olist CSVs into a BigQuery 'raw' dataset.

Orders are loaded month-by-month (simulating incremental ingestion batches),
adding a _loaded_date column so downstream incremental dbt models are
meaningful. All other tables are loaded with full-replace (WRITE_TRUNCATE)
semantics, making re-runs safe.

Usage:
    python ingestion/load_raw.py --source-dir data/
    python ingestion/load_raw.py --source-dir data/ --project my-gcp-project --dataset raw
"""

import argparse
import logging
import os
import sys
from pathlib import Path

import pandas as pd
from google.cloud import bigquery

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

# Timestamp columns to coerce per table (read as str initially, then cast)
TIMESTAMP_COLS: dict[str, list[str]] = {
    "raw_orders": [
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ],
    "raw_order_items": ["shipping_limit_date"],
    "raw_order_reviews": ["review_creation_date", "review_answer_timestamp"],
}

# CSV filename → destination BigQuery table name
TABLE_MAP: dict[str, str] = {
    "olist_customers_dataset.csv": "raw_customers",
    "olist_geolocation_dataset.csv": "raw_geolocation",
    "olist_order_items_dataset.csv": "raw_order_items",
    "olist_order_payments_dataset.csv": "raw_order_payments",
    "olist_order_reviews_dataset.csv": "raw_order_reviews",
    "olist_orders_dataset.csv": "raw_orders",
    "olist_products_dataset.csv": "raw_products",
    "olist_sellers_dataset.csv": "raw_sellers",
    "product_category_name_translation.csv": "raw_product_category_name_translation",
}


def read_csv(path: Path, table_name: str) -> pd.DataFrame:
    """Read a CSV, strip BOM from headers, and cast timestamp columns."""
    df = pd.read_csv(path, dtype=str, keep_default_na=True)
    # Strip BOM that appears on product_category_name_translation.csv
    df.columns = [c.lstrip("﻿").strip() for c in df.columns]
    for col in TIMESTAMP_COLS.get(table_name, []):
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df


def load_simple(client: bigquery.Client, df: pd.DataFrame, table_ref: str) -> int:
    """Full-replace load — idempotent."""
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )
    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()
    return len(df)


def load_orders_batched(
    client: bigquery.Client, df: pd.DataFrame, table_ref: str
) -> int:
    """
    Load orders one calendar month at a time, adding _loaded_date so
    downstream incremental models have a meaningful watermark column.

    First batch truncates the table; subsequent ones append, making the
    whole operation idempotent on re-run.
    """
    df = df.copy()

    # _loaded_date = first day of the order's purchase month
    df["_loaded_date"] = (
        df["order_purchase_timestamp"]
        .dt.to_period("M")
        .dt.to_timestamp()
    )
    # Rows with no purchase timestamp land in a catch-all month
    df["_loaded_date"] = df["_loaded_date"].fillna(pd.Timestamp("1970-01-01"))

    months = sorted(df["_loaded_date"].unique())
    total = 0

    for i, month in enumerate(months):
        batch = df[df["_loaded_date"] == month].copy()
        disposition = (
            bigquery.WriteDisposition.WRITE_TRUNCATE
            if i == 0
            else bigquery.WriteDisposition.WRITE_APPEND
        )
        job_config = bigquery.LoadJobConfig(write_disposition=disposition)
        job = client.load_table_from_dataframe(batch, table_ref, job_config=job_config)
        job.result()
        total += len(batch)
        log.info(
            "    batch %3d/%d  month=%-7s  rows=%d",
            i + 1,
            len(months),
            month.strftime("%Y-%m"),
            len(batch),
        )

    return total


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Load Olist CSVs into BigQuery raw dataset."
    )
    parser.add_argument(
        "--source-dir",
        required=True,
        help="Directory containing the 9 Olist CSVs",
    )
    parser.add_argument(
        "--project",
        default=os.environ.get("DBT_BQ_PROJECT"),
        help="GCP project ID (default: $DBT_BQ_PROJECT)",
    )
    parser.add_argument(
        "--dataset",
        default="raw",
        help="BigQuery dataset to load into (default: raw)",
    )
    args = parser.parse_args()

    if not args.project:
        log.error(
            "GCP project not set. Pass --project or set the DBT_BQ_PROJECT env var."
        )
        sys.exit(1)

    source_dir = Path(args.source_dir)
    if not source_dir.is_dir():
        log.error("Source directory not found: %s", source_dir)
        sys.exit(1)

    client = bigquery.Client(project=args.project)

    # Create the raw dataset if it doesn't exist yet
    dataset_ref = bigquery.Dataset(f"{args.project}.{args.dataset}")
    dataset_ref.location = "US"
    client.create_dataset(dataset_ref, exists_ok=True)
    log.info("Target dataset: %s.%s", args.project, args.dataset)
    log.info("─" * 64)

    results: dict[str, int] = {}

    for csv_name, table_name in TABLE_MAP.items():
        csv_path = source_dir / csv_name
        if not csv_path.exists():
            log.warning("File not found, skipping: %s", csv_path)
            continue

        table_ref = f"{args.project}.{args.dataset}.{table_name}"
        log.info("Loading  %s  →  %s", csv_name, table_name)

        df = read_csv(csv_path, table_name)

        if table_name == "raw_orders":
            count = load_orders_batched(client, df, table_ref)
        else:
            count = load_simple(client, df, table_ref)

        results[table_name] = count
        log.info("  ✓  %-48s  %7d rows", table_name, count)
        log.info("─" * 64)

    log.info("Load complete. Summary:")
    for tbl, cnt in results.items():
        log.info("  %-50s  %7d", tbl, cnt)

    missing = set(TABLE_MAP.values()) - set(results.keys())
    if missing:
        log.warning("Tables not loaded (CSV not found): %s", ", ".join(sorted(missing)))


if __name__ == "__main__":
    main()
