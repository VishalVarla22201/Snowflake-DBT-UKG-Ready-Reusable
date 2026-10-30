{% snapshot scd__ukg_ready__lookup_eins %}

{{
    config(
        unique_key='company_key',
        strategy='timestamp',
        updated_at='_fivetran_synced',
        hard_deletes='invalidate',
        dbt_valid_to_current="to_date('9999-12-31')"
    )
}}

select
    company_key,
    id,
    ein_name,
    ein_tax_id,
    ein_country_id,
    _fivetran_synced
from {{ ref('stg__ukg_ready__lookup_eins') }}

{% endsnapshot %}
