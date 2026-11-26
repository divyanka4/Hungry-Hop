# R9 — Late-Delivery Compensation Engine (evidence)

*Scope note: interpreted R9 as the deterministic compensation policy layer (the copilot's core decision
logic). If the assignment's R9 is a different round, this work still serves the agent rounds unchanged.*

## Deliverable
- Notebook: `notebooks/r9_compensation_engine` (config cell + SOP policy doc + engine + 3 verification cells; all cells executed successfully).
- Table: **hop.genai.compensation_decisions** — one row per gold order (13,152 rows, verified 13,152 distinct = 13,152 gold orders). Gold stays policy-free; the policy layer lives in `hop.genai`.

## Policy implemented (source: sop_docs/01–06, frozen as of 2026-08-31)
1. Fault from the order's ticket issue code: KITCHEN_DELAY/WRONG_ITEM → restaurant; RIDER_DELAY/DAMAGED_IN_TRANSIT → rider; CUSTOMER_UNAVAILABLE → customer; OTHER or no ticket → unknown. (Data verified: ≤1 ticket per order, 1,200 tickets.)
2. Late = delivered AND minutes past promise > 5 (instant) / > 20 (standard); measured from the accepted event (gold's minutes_past_promise).
3. Decision precedence: customer fault → NONE; cancelled (not customer fault) → REFUND 100% of order value; late → COUPON base 40 (instant) / 60 (standard) × tier multiplier (free ×1, hop_plus ×1.5, hop_pro ×2) ONLY for restaurant/rider fault (unknown fault → base alone); else NONE.

## Schema
`order_id, issue_code, fault, customer_tier, status, delivery_class, minutes_past_promise, is_late, eligible, compensation_type, amount, reason_code`

## Decision distribution (13,152 orders)
| type | reason_code | count |
|---|---|---|
| COUPON | LATE_RESTAURANT_FAULT | 105 |
| COUPON | LATE_RIDER_FAULT | 169 |
| COUPON | LATE_UNKNOWN_FAULT | 470 |
| NONE | CUSTOMER_FAULT | 154 |
| NONE | ON_TIME | 11,442 |
| REFUND | NOT_DELIVERED | 812 |

## Verification (all executed, all green)
- One decision row per gold order: 13,152 / 13,152 / 13,152 (rows / distinct / gold orders).
- Invariants: eligible ⟺ type ≠ NONE — 0 violations; negative amounts — 0; is_late but not delivered — 0; REFUND amount ≠ order_value — 0.
- Independent recomputation of amount via a different code path (map-based): **0 mismatches of 13,152**.
- Probe tickets (hop.genai.compensation_probes, 24): 20 resolved; the 4 unresolved reference orders absent from gold (ORD-31559, ORD-35893, ORD-44514, ORD-31669). Context: 182 of all 1,200 ticket orders are absent from gold (quarantined/outside window) — expected data reality, not engine failures.

## Probe spot-checks (hand-verified against the SOPs)
- TKT-10071 (delivered, late 22.35, CUSTOMER_UNAVAILABLE) → NONE — customer fault beats lateness. ✓
- TKT-10384 (late 26.58, OTHER, hop_plus) → COUPON 60 — base only, no multiplier for unknown fault. ✓
- TKT-10426 (instant, late 8.07, rider, hop_pro) → COUPON 80 = 40×2. ✓
- TKT-10696 (standard, late 20.8, rider, hop_plus) → COUPON 90 = 60×1.5. ✓
- TKT-10096 (cancelled, KITCHEN_DELAY) → REFUND 2,267.03 = full order value. ✓
- TKT-10263 (cancelled, CUSTOMER_UNAVAILABLE) → NONE. ✓
- TKT-10035 (rider ticket but on time, 12.77) → NONE. ✓
- Planted edge orders in gold: ORD-50001 (instant, 8.00, rider, hop_plus) → 60 = 40×1.5; ORD-50002 (standard, 8.00, on time) → NONE; ORD-50003 (standard, 22.00, rider, hop_pro) → 120 = 60×2. ✓

## Notes for the agent rounds (R10+)
- The four facts per SOP 01: fault, delivered?, late?, tier — all present per row.
- For ticket orders absent from gold, the copilot must answer "order not found" rather than guess (see the 4 unresolved probes).
- SOP 08: never promise a coupon/refund before the four facts are checked — the decisions table is that check.