with source_data as (
    select
        _fivetran_synced,
        _fivetran_deleted,
        id,
        ein_name,
        ein_tax_id,
        ein_country_id
    from {{ source('ukg_ready', 'LOOKUP_EINS') }}
    where not coalesce(_fivetran_deleted, false)
),

cleaned as (
    select
        cast(id as int) as id,
        trim(ein_name) as ein_name,
        trim(ein_tax_id) as ein_tax_id,
        trim(ein_country_id) as ein_country_id,
        current_timestamp() as silver_load_date,
        cast(_fivetran_synced as timestamp_ntz) as _fivetran_synced
    from source_data
)

select
    {{ dbt_utils.generate_surrogate_key(['id']) }} as company_key,
    id,
    ein_name,
    ein_tax_id,
    ein_country_id,
    silver_load_date,
    _fivetran_synced
from cleaned
