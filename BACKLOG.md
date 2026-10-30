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
| 5 | Raw source is Fivetran; env-based databases | Raw source `fivetrandb.ukg_ready` set in `models/sources.yml`; silver, gold and mapping tables in `DEV_DB`, or `PROD_DB` for `--target prod` |
| 6 | `_fivetran_synced` (timestamp_ntz) and `_fivetran_deleted` filter in silver | All 7 silver models; deleted rows are removed, `_fivetran_synced` is carried through |
| 7 | Incremental gold models | `dim_hr_company` and `dim_hr_employee` (merge); `fact_payroll_workhours` and `fact_employee_salary_details` (delete+insert on new `employee_date_key`); watermark macro with a 1 hour lookback (`incremental_lookback_hours`) |
| 8 | Staging naming | Silver models renamed to `stg__ukg_ready__<source table>` in `models/silver/` |
| 9 | SCD type 2 snapshots | `snapshots/silver/scd__ukg_ready__*`: SQL snapshot blocks plus a YAML file each for 6 staging models; strategy `timestamp` on `_fivetran_synced`, `hard_deletes=invalidate`, `dbt_valid_to_current` = `9999-12-31` (current dbt config names) |
| 10 | Propagate deletes into incremental gold (was B9) | Post-hook macro `delete_rows_missing_upstream` removes rows whose key is gone upstream: `dim_hr_company`, `fact_payroll_workhours` (vs staging), `fact_employee_salary_details` (vs the fact). `dim_hr_employee` is soft-deleted instead: `is_deleted` Y/N plus `deleted_date`, cleared again if the employee returns; `full_refresh=false` protects that history |
| 11 | Typed placeholder nulls (was B4) | `dim_hr_employee` and `fact_employee_salary_details`: ids cast to int, text columns to varchar, `period_pay_rate` to float |
| 12 | Sources documented, freshness added (was B6) | Table and column descriptions in `models/sources.yml`; freshness on `_fivetran_synced` (warn 24h, error 48h for the Fivetran source; manual tables excluded). Run `dbt source freshness` |
| 13 | Remaining gold models kept as tables (was B11) | Decision recorded in each model: hierarchy dims and `dim_job` (parent changes alter other rows), `dim_salary_code` (static), mapping dims (manual, no watermark) |
| 14 | Staging models as views | `models/silver/*` use `+materialized: view` in `dbt_project.yml`; they filter `_fivetran_deleted` rows directly, so deletes still reach gold and the snapshots. Incremental staging was built and reverted, see B17 |
| 15 | Hard-coded values moved to project variables (was B1, B3) | `far_future_date` (2050-01-01) in `fact_payroll_workhours`; `department_hierarchy_level` (4) and `location_hierarchy_level` (3) in `dim_hr_department` / `dim_hr_location`, all in `dbt_project.yml` |

## Backlog

| # | Item | Model(s) | Detail | Priority |
|---|------|----------|--------|----------|
| B2 | Clean up `select distinct` and untyped `null` | `dim_hr_company` | Dedupe on `id` explicitly (or rely on the `unique` test) and cast `company_code` (`cast(null as varchar)`) | Medium |
| B5 | Add missing tests | gold and silver | Add `relationships` tests on `employee_key`, `location_key`, `job_key`, `department_key` and the silver foreign keys; `not_null` on `pay_date`; consider `accepted_values` for `employee_type` | Medium |
| B7 | Move to the staging / intermediate / marts layering | project structure | Optional: bring the folder layout and naming (`stg_`, `int_`) in line with the dbt style guide if the project grows | Low |
| B8 | Switch to `import CTE -> logical CTEs -> final` layout | all models | Put all `ref` / `source` calls in import CTEs at the top and end every model with a `final` CTE | Low |
| B10 | One-time full refresh when switching to incremental | the four incremental gold models | Existing tables lack `_fivetran_synced` and `employee_date_key`; run `dbt build --full-refresh` once per environment (`dim_hr_employee` is excluded, drop it by hand to rebuild) | High |
| B13 | Verify Fivetran column names | silver import CTEs | Confirm the Fivetran tables expose the exact columns listed, including `_fivetran_synced` and `_fivetran_deleted`; first `dbt build` will fail with an invalid identifier if not | High |
| B15 | Snapshot `time_entries` and downstream use of history | `stg__ukg_ready__time_entries`, gold | Not snapshotted: transactional rows, large, and their key already includes the extraction window. Also decide whether gold dims should read the snapshots (point-in-time joins) | Low |
| B16 | Older extraction window not restored after a delete | `fact_payroll_workhours` | If the latest window of an employee/day is deleted in Fivetran, its rows are removed but an older window for that day only becomes current again after a full refresh. Fix by also adding such days to `changed_days` | Low |
| B17 | Check with Ram / Srinivas whether to convert staging to tables and incremental | `models/silver/*` | Staging is a view today. If they want tables: materialise as `table`, or incremental `merge` on the key with `cast(_fivetran_synced as timestamp_ntz) > incremental_watermark()`. Incremental must still remove Fivetran-deleted rows: load them in the batch (no `_fivetran_deleted` filter), keep a `_fivetran_deleted` column, and purge them with `post_hook="delete from {{ this }} where _fivetran_deleted"`; gold hooks and snapshots rely on deleted rows being absent from staging. Also add `_fivetran_deleted` to the staging YAML | Pending |
| B18 | Check with Srinivas / Ram: confirm the project variable values | `dbt_project.yml` | Confirm with them that `far_future_date` = 2050-01-01 is the right open-ended end date, and that department = level 4 and location = level 3 are correct for the UKG cost-center hierarchies (and the same in every environment) | Pending |

## Notes

- Nothing from this work has been run against Snowflake yet. Run `dbt parse`, then `dbt build` in a dev target, before merging.
- `stg__ukg_ready__time_entries` now names the raw columns explicitly, so a mismatch with the raw table will fail loudly as an invalid identifier.
- B5 to B8 are suggestions added while reviewing the code. They were not discussed yet; confirm or drop them.
