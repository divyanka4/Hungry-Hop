# R7 — HungryHop Ops dashboard evidence

Dashboard: `dashboards/HungryHop Ops.lvdash.json` — workspace file, open it in the Databricks AI/BI dashboard editor to see it live (or via searchAssets / the HungryHop Ops tile in the workspace).

## Structure

* Dataset: UC metric view `hop.analytics.mv_orders` imported by `asset_name` (read-only from the dashboard).
* Page **Overview** (canvas, GRID_V1): 4 KPI counters (Total Orders, Deliver Rate, Late Rate delivered, Avg Actual Minutes), Daily Orders line over `placed_date`, Orders by Delivery Class pie, Deliver-vs-Late Rate by class bar (grouped), Top Cities by Orders bar, Late Rate by City bar, Orders by Platform bar.
* Page **Global Filters**: date-range on `placed_date`, multi-select `delivery_class`, multi-select `customer_city` — apply to every page.

## Verification (rendered draft, all 13 widget queries SUCCESS, 0 errors)

| Widget | Result |
| --- | --- |
| Total Orders | 13,152 (matches hop.gold.orders_enriched row count) |
| Deliver Rate | 93.2% (12,255 delivered / 13,152) |
| Late Rate (delivered) | 54.1% (6,626 late / 12,255) |
| Avg Actual Minutes | 30.0 |
| Orders by Delivery Class | standard 9,461 / instant 3,691 |
| Rate by class | instant deliver 93.1% / late 70.6%; standard deliver 93.2% / late 47.6% |
| Top Cities | Bengaluru 2,890 / Hyderabad 2,816 / Delhi 2,521 / Pune 2,502 / Mumbai 2,423 |
| Late Rate by City | Mumbai 54.7% .. Bengaluru 53.5% (tight range) |
| Orders by Platform | null 8,836 (pre-platform orders) / android 1,467 / ios 1,445 / web 1,404 |

Fix applied during verification: the Deliver-vs-Late bar defaulted to a **stacked** layout (0.93 + 0.71 drawn on top of each other); switched to `mark.layout: "group"` so the two rates render side by side.

Note on the PNG: the dashboard screenshot capture renders inside the assistant chat but does not expose the image as a downloadable file, so this note documents the verified render instead of a saved `r7_dashboard.png`.