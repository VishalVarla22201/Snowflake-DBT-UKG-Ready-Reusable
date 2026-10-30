# UKG Ready – reusable dbt project (Snowflake)

Converts the compiled UKG Ready silver/gold SQL into a parameterised dbt project.

```
raw (Fivetran: fivetrandb.ukg_ready) ──► silver (SILVER.stg__ukg_ready__*) ──► gold (GOLD.dim_* / fact_*)
```

## Setup
```bash
pip install dbt-snowflake
cp profiles.yml.example ~/.dbt/profiles.yml   # then set env vars
dbt deps
dbt build
```
Databases (see `dbt_project.yml`):
- **Raw (Fivetran):** `fivetrandb.ukg_ready`, set in `models/sources.yml`.
- **Silver / gold / mapping tables:** `DEV_DB` for any target except `prod`; `PROD_DB` when run with `--target prod`.

## Layout
- `models/sources.yml` – raw UKG tables + the 3 manual mapping tables (source `manual`, schema `manual`).
- `models/silver/staging/` – 7 staging models (`stg__ukg_ready__*`), schema `SILVER`.
- `snapshots/silver/` – SCD type 2 snapshots (`scd__ukg_ready__*`, SQL + YAML) of 6 staging models, strategy `timestamp` on `_fivetran_synced`, `hard_deletes: invalidate`, schema `SILVER`. Run with `dbt snapshot`.
- `models/gold/` – 11 dimension/fact models, schema `GOLD`; model names equal the original table names.
- `macros/generate_schema_name.sql` – uses `SILVER`/`GOLD` verbatim.

## Surrogate keys
All keys use `dbt_utils.generate_surrogate_key` on the table's id column(s); original ids are kept.
Key column = `<entity>_key`; foreign keys use the same name as the parent's key so they join directly:

| Key | Built from | Where |
|---|---|---|
| `employee_key` | employee id (`id` / `dim_employee_id` / `employee_account_id`) | employees, employee_details, compensation_history, time_entries, dim_hr_employee, facts |
| `company_key` | `id` / `dim_company_id` | lookup_eins, dim_hr_company, dim_hr_employee, dim_subsidiary_mapping |
| `location_key`, `department_key`, `job_key` | `dim_*_id` | dims, dim_hr_employee, mapping tables |
| `earning_key` | `dim_earning_id` | dim_salary_code, fact_employee_salary_details |
| `compensation_history_key`, `cost_center_org_key`, `cost_center_store_key`, `time_entry_key`, `payroll_workhours_key`, `employee_salary_detail_key`, `*_mapping_key` | table grain | primary keys |

No source table contains a `customer_id` column. If you reuse this on data that does, add
`{{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_key`.

## Notes
- Gold mapping models read `<mapping_database>.manual.*_mapping`; these must exist (or repoint the `mapping_*` vars).
- Logic is carried over unchanged from the compiled SQL (including the level-3/level-4 hierarchy filters and the `'1900-12-31'` compensation filter).
- Not executed against Snowflake in authoring; run `dbt build` to validate.
