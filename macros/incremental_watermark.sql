{#-
    Watermark for incremental models: the latest _fivetran_synced already loaded into this model,
    minus a lookback window (var 'incremental_lookback_hours', default 1). Fivetran syncs tables
    independently, so a source table can land slightly after the watermark has moved past it; the
    lookback re-reads a few rows rather than missing them. Models using it are idempotent
    (merge / delete+insert), so reprocessing is safe.
-#}
{% macro incremental_watermark(column='_fivetran_synced') -%}
    (
        select dateadd(
            'hour',
            -{{ var('incremental_lookback_hours', 1) }},
            coalesce(max({{ column }}), '1900-01-01'::timestamp_ntz)
        )
        from {{ this }}
    )
{%- endmacro %}
