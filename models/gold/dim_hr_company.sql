with source as (
    select distinct id, ein_name
    from {{ ref('ukg_ready_lookup_eins') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['id']) }} as company_key,
    id as dim_company_id,
    null as company_code,
    ein_name as company_name,
    current_timestamp() as gold_load_date
from source
