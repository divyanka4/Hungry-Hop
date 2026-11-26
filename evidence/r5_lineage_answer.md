# R5 — Lineage Answer: how `hop.gold.orders_enriched` is built, and does any PII reach it?

Source of truth: `system.access.table_lineage` (queried 2026-11-25, after the R2–R4 pipeline
updates). Reproduce with:

```sql
SELECT DISTINCT source_table_full_name, target_table_full_name
FROM system.access.table_lineage
WHERE target_table_full_name IN (
  'hop.bronze.order_events', 'hop.silver.order_events_dedup',
  'hop.silver.orders', 'hop.silver.orders_quarantine',
  'hop.silver.dim_restaurant_scd2', 'hop.gold.orders_enriched')
ORDER BY target_table_full_name, source_table_full_name;
```

## Full lineage chain

```
/volumes/hop/raw/landing/order_events/*.json        (Auto Loader, notebook r1_bronze_ingest)
  -> hop.bronze.order_events                        (R1, every line kept)
     -> hop.silver.order_events_dedup               (R2, one row per event_id)
        -> hop.silver.orders                        (R2, clean rebuilt orders)
        -> hop.silver.orders_quarantine             (R2, broken orders + failed rules)

hop.raw.restaurants_cdc
  -> hop.silver.dim_restaurant_scd2                 (R3, Auto CDC SCD2, sequenced on op_ts)

hop.silver.orders + hop.silver.dim_restaurant_scd2 + hop.raw.customers + hop.raw.zones
  -> hop.gold.orders_enriched                       (R4, policy-free gold)
```
Recorded lineage edges (17 total):

| Source | Target |
| --- | --- |
| (landing volume files) | hop.bronze.order_events |
| hop.bronze.order_events | hop.silver.order_events_dedup |
| hop.silver.order_events_dedup | hop.silver.orders |
| hop.raw.customers | hop.silver.orders |
| hop.raw.riders | hop.silver.orders |
| hop.raw.zones | hop.silver.orders |
| hop.raw.restaurants_cdc | hop.silver.orders |
| hop.silver.order_events_dedup | hop.silver.orders_quarantine |
| hop.raw.customers | hop.silver.orders_quarantine |
| hop.raw.riders | hop.silver.orders_quarantine |
| hop.raw.zones | hop.silver.orders_quarantine |
| hop.raw.restaurants_cdc | hop.silver.orders_quarantine |
| hop.raw.restaurants_cdc | hop.silver.dim_restaurant_scd2 |
| hop.silver.orders | hop.gold.orders_enriched |
| hop.silver.dim_restaurant_scd2 | hop.gold.orders_enriched |
| hop.raw.customers | hop.gold.orders_enriched |
| hop.raw.zones | hop.gold.orders_enriched |

## Does customer PII (email / phone) reach the gold layer?

**No.** `hop.raw.customers` feeds `hop.gold.orders_enriched`, but the gold view selects only
`city` (as `customer_city`) and `tier` (as `customer_tier`) from it. The gold schema
(25 columns) contains no `email`, `phone`, or customer-name column — verified by listing
`hop.gold.orders_enriched` columns: the only name-like column is `restaurant_name`.

In addition, as of R5 the `email` and `phone` columns of `hop.raw.customers` carry the column
mask `hop.gov.mask_contact` (verified via `SHOW CREATE TABLE hop.raw.customers`): outside the
support admin roster (`hop.gov.admin_users`) they render as four stars plus the last 4
characters, per SOP-08. The R5 proof table `hop.gov.r5_mask_proof` records the expected masked
rendering, and `sql/r5_governance.sql` holds the full governance DDL (mask, roster, grants).
