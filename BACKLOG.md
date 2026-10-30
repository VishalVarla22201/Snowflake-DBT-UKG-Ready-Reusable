# UKG Ready Reusable - dbt Standardisation Backlog

Project: `UKG Ready Reusable Scripts/Snowflake-DBT-UKG-Ready-Reusable`
Branch: `feature/modifying-scipts-vv`

## Done

| # | Item | Notes |
|---|------|-------|
| 1 | One YAML file per model | `<model_name>.yml` next to each `.sql`; shared `schema.yml` files removed; all columns described, existing tests kept |
| 2 | Replace `select *` with explicit columns | All 12 affected models (silver import CTEs and final selects, gold finals, `te_latest` in `fact_payroll_workhours`) |
| 3 | Fix `row_number` alias in `dim_hr_employee` | Renamed to `compensation_rank`, join condition qualified as `ch.compensation_rank` |
| 4 | Make division by `3600000` explicit | `3600000.0` in `fact_payroll_workhours` and `ukg_ready_time_entries` |

## Backlog

| # | Item | Model(s) | Detail | Priority |
|---|------|----------|--------|----------|
| B1 | Remove hard-coded end date `'2050-01-01'` | `fact_payroll_workhours` | Move to a project var (e.g. `far_future_date`) or use an open-ended condition (`effective_till is null or ...`) | Medium |
| B2 | Clean up `select distinct` and untyped `null` | `dim_hr_company` | Dedupe on `id` explicitly (or rely on the `unique` test) and cast `company_code` (`cast(null as varchar)`) | Medium |
| B3 | Remove hard-coded hierarchy levels | `dim_hr_department` (level 4), `dim_hr_location` (level 3) | Move the level to project vars or document and test it, so a hierarchy change does not silently break the dimension | Medium |
| B4 | Cast untyped `null` placeholder columns | `dim_hr_employee`, `fact_employee_salary_details` | Columns such as `hire_source`, `termination_reason`, `dim_company_id`, `location_id` have no type, so the Snowflake type is not controlled | Low |
| B5 | Add missing tests | gold and silver | Add `relationships` tests on `employee_key`, `location_key`, `job_key`, `department_key` and the silver foreign keys; `not_null` on `pay_date`; consider `accepted_values` for `employee_type` | Medium |
| B6 | Document sources per table | `models/sources.yml` | Add table and column descriptions; add `freshness` and `loaded_at_field` where available | Low |
| B7 | Move to the staging / intermediate / marts layering | project structure | Optional: bring the folder layout and naming (`stg_`, `int_`) in line with the dbt style guide if the project grows | Low |
| B8 | Switch to `import CTE -> logical CTEs -> final` layout | all models | Put all `ref` / `source` calls in import CTEs at the top and end every model with a `final` CTE | Low |

## Notes

- Nothing from this work has been run against Snowflake yet. Run `dbt parse`, then `dbt build` in a dev target, before merging.
- `ukg_ready_time_entries` now names the raw columns explicitly, so a mismatch with the raw table will fail loudly as an invalid identifier.
- B5 to B8 are suggestions added while reviewing the code. They were not discussed yet; confirm or drop them.
