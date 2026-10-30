with source_data as (
    select
        id,
        ein_name,
        ein_tax_id,
        ein_country_id
    from {{ source('ukg_ready', 'LOOKUP_EINS') }}
),

cleaned as (
    select
        cast(id as int) as id,
        trim(ein_name) as ein_name,
        trim(ein_tax_id) as ein_tax_id,
        trim(ein_country_id) as ein_country_id,
        current_timestamp() as silver_load_date
    from source_data
)

select
    {{ dbt_utils.generate_surrogate_key(['id']) }} as company_key,
    id,
    ein_name,
    ein_tax_id,
    ein_country_id,
    silver_load_date
from cleaned
