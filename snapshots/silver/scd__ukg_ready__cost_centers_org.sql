{% snapshot scd__ukg_ready__cost_centers_org %}

{{
    config(
        unique_key='cost_center_org_key',
        strategy='timestamp',
        updated_at='_fivetran_synced',
        hard_deletes='invalidate',
        dbt_valid_to_current="to_date('9999-12-31')"
    )
}}

select
    cost_center_org_key,
    parent_cost_center_org_key,
    id,
    parent_id,
    name,
    _fivetran_synced
from {{ ref('stg__ukg_ready__cost_centers_org') }}

{% endsnapshot %}
