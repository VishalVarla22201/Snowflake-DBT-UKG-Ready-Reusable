{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='company_key',
        on_schema_change='sync_all_columns'
    )
}}

with source as (
    select distinct
        id,
        ein_name,
        _fivetran_synced
    from {{ ref('stg__ukg_ready__lookup_eins') }}
    {% if is_incremental() %}
    where _fivetran_synced > {{ incremental_watermark() }}
    {% endif %}
)

select
    {{ dbt_utils.generate_surrogate_key(['id']) }} as company_key,
    id as dim_company_id,
    null as company_code,
    ein_name as company_name,
    current_timestamp() as gold_load_date,
    _fivetran_synced
from source
