# UKG Ready Reusable - dbt Standardisation Backlog

Project: `UKG Ready Reusable Scripts/Snowflake-DBT-UKG-Ready-Reusable`
Branch: `feature/modifying-scipts-vv`

## Done

| # | Item | Notes |
|---|------|-------|
| 1 | One YAML file per model | `<model_name>.yml` next to each `.sql`; shared `schema.yml` files removed; all columns described, existing tests kept |
| 2 | Replace `select *` with explicit columns | All 12 affected models (silver import CTEs and final selects, gold finals, `te_latest` in `fact_payroll_workhours`) |
| 3 | Fix `row_number` alias in `dim_hr_employee` | Renamed to `compensation_rank`, join condition qualified as `ch.compensation_rank` |
| 4 | Make division by `3600000` explicit | `3600000.0` in `fact_payroll_workhours` and `stg__ukg_ready__time_entries` |
| 5 | Raw source is Fivetran; env-based databases | `raw_database` / `raw_schema` from `FIVETRAN_DATABASE` / `FIVETRAN_UKG_SCHEMA`; silver, gold and mapping tables in `DEV_DB`, or `PROD_DB` for `--target prod` |
| 6 | `_fivetran_synced` (timestamp_ntz) and `_fivetran_deleted` filter in silver | All 7 silver models; deleted rows are removed, `_fivetran_synced` is carried through |
| 7 | Incremental gold models | `dim_hr_company` and `dim_hr_employee` (merge); `fact_payroll_workhours` and `fact_employee_salary_details` (delete+insert on new `employee_date_key`); watermark macro with a 1 hour lookback (`incremental_lookback_hours`) |
| 8 | `staging/` subfolder | Silver staging models and their YAML moved to `models/silver/staging/`; renamed to `stg__ukg_ready__<source table>` |
| 9 | SCD type 2 snapshots | `snapshots/silver/scd__ukg_ready__*` for 6 staging models; strategy `timestamp` on `_fivetran_synced`, `hard_deletes: invalidate`, one YAML per snapshot (needs dbt 1.9+) |

## Backlog

| # | Item | Model(s) | Detail | Priority |
|---|------|----------|--------|----------|
| B1 | Remove hard-coded end date `'2050-01-01'` | `fact_payroll_workhours` | Move to a project var (e.g. `far_future_date`) or use an open-ended condition (`effective_till is null or ...`) | Medium |
| B2 | Clean up `select distinct` and untyped `null` | `dim_hr_company` | Dedupe on `id` explicitly (or rely on the `unique` test) and cast `company_code` (`cast(null as varchar)`) | Medium |
| B3 | Remove hard-coded hierarchy levels | `dim_hr_department` (level 4), `dim_hr_location` (level 3) | Move the level to project vars or document and test it, so a hierarchy change does not silently break the dimension | Medium |
| B4 | Cast untyped `null` placeholder columns | `dim_hr_employee`, `fact_employee_salary_details` | Columns such as `hire_source`, `termination_reason`, `dim_company_id`, `location_id` have no type, so the Snowflake type is not controlled | Low |
| B5 | Add missing tests | gold and silver | Add `relationships` tests on `employee_key`, `location_key`, `job_key`, `department_key` and the silver foreign keys; `not_null` on `pay_date`; consider `accepted_values` for `employee_type` | Medium |
| B6 | Document sources per table | `models/sources.yml` | Add table and column descriptions; add `freshness` with `loaded_at_field: _fivetran_synced` | Low |
| B7 | Move to the staging / intermediate / marts layering | project structure | Optional: bring the folder layout and naming (`stg_`, `int_`) in line with the dbt style guide if the project grows | Low |
| B8 | Switch to `import CTE -> logical CTEs -> final` layout | all models | Put all `ref` / `source` calls in import CTEs at the top and end every model with a `final` CTE | Low |
| B9 | Propagate deletes into incremental gold models | `dim_hr_company`, `dim_hr_employee`, `fact_payroll_workhours`, `fact_employee_salary_details` | Silver drops `_fivetran_deleted` rows, but incremental models never remove rows already loaded. Add a scheduled `--full-refresh`, or a delete step that removes target rows missing from silver | High |
| B10 | One-time full refresh when switching to incremental | the four incremental models | The existing tables lack `_fivetran_synced` and `employee_date_key`; run `dbt build --full-refresh` once per environment | High |
| B11 | Decide on incremental for the remaining gold models | `dim_hr_department`, `dim_hr_location`, `dim_job`, `dim_salary_code`, three mapping dims | Kept as tables: hierarchy changes move descendants without touching their rows, `dim_salary_code` is static and the mapping tables are manual with no Fivetran columns. Revisit if volumes grow | Low |
| B12 | Silver models stay full-refresh tables | all silver models | They re-read the whole raw table each run; make them incremental on `_fivetran_synced` if raw volumes grow | Low |
| B13 | Verify Fivetran column names | silver import CTEs | Confirm the Fivetran tables expose the exact columns listed, including `_fivetran_synced` and `_fivetran_deleted`; first `dbt build` will fail with an invalid identifier if not | High |
| B14 | Materialise staging models as views | `models/silver/staging/` | Staging models are `table` today (project default); the dbt style guide uses views. Snapshots read from them, so check cost before switching | Low |
| B15 | Snapshot `time_entries` and downstream use of history | `stg__ukg_ready__time_entries`, gold | Not snapshotted: transactional rows, large, and their key already includes the extraction window. Also decide whether gold dims should read the snapshots (point-in-time joins) | Low |

## Notes

- Nothing from this work has been run against Snowflake yet. Run `dbt parse`, then `dbt build` in a dev target, before merging.
- `stg__ukg_ready__time_entries` now names the raw columns explicitly, so a mismatch with the raw table will fail loudly as an invalid identifier.
- B5 to B8 are suggestions added while reviewing the code. They were not discussed yet; confirm or drop them.
