{#- Kept as a table (not incremental): the source is a manually maintained table with no _fivetran_synced column to use as a watermark, and it is small. -#}
{{ config(materialized='table') }}

with source as (
    select
        dim_subsidiary_id,
        subsidiary_name,
        company_name,
        dim_company_id,
        current_timestamp()::timestamp_ntz as gold_load_date
    from {{ source('manual', 'subsidiary_mapping') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['dim_subsidiary_id', 'dim_company_id']) }} as subsidiary_mapping_key,
    {{ dbt_utils.generate_surrogate_key(['dim_subsidiary_id']) }} as subsidiary_key,
    {{ dbt_utils.generate_surrogate_key(['dim_company_id']) }} as company_key,
    dim_subsidiary_id,
    subsidiary_name,
    company_name,
    dim_company_id,
    gold_load_date
from source
