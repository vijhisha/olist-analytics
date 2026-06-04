# Olist Analytics Platform — common commands
# Requires: GNU make, Python venv activated, env vars set (see .env.example)
# On Windows: run via Git Bash, WSL, or `make` from a POSIX shell.

.PHONY: load build test snapshot freshness docs lint lint-fix clean help

## Load raw CSVs into BigQuery raw dataset (idempotent)
load:
	python ingestion/load_raw.py --source-dir data/

## Build all dbt models + run all tests (excludes snapshots)
build:
	cd dbt && dbt deps && dbt build --exclude resource_type:snapshot

## Run dbt tests only (no model rebuild)
test:
	cd dbt && dbt test --exclude resource_type:snapshot

## Run snapshots (separate step — avoids BigQuery concurrency issue with 4 threads)
snapshot:
	cd dbt && dbt snapshot

## Check source freshness (will warn on historical 2016-2018 data — expected)
freshness:
	cd dbt && dbt source freshness

## Generate dbt docs and serve locally at http://localhost:8080
docs:
	cd dbt && dbt docs generate && dbt docs serve

## Lint all dbt SQL with sqlfluff (must run from project root; matches CI)
lint:
	cd dbt && sqlfluff lint models --processes 2

## Auto-fix sqlfluff violations (run from dbt/ to avoid temp-file path bug on Windows)
lint-fix:
	cd dbt && sqlfluff fix models --processes 2

## Run the full pipeline end to end
all: load build snapshot

## Remove dbt build artefacts
clean:
	cd dbt && dbt clean

help:
	@grep -E '^##' Makefile | sed 's/## /  /'
