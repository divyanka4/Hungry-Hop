# R10 — Ticket Classification + SOP Chunks + Vector Search Index

Built 2026-11-26 from [notebooks/r10_sop_rag](../notebooks/r10_sop_rag). Three deliverables, all under `hop.genai`:

## 1. hop.genai.ticket_classified
- 1,200 rows — exactly one per ticket in `hop.raw.support_tickets` (as loaded, unchanged).
- Columns: `ticket_id STRING`, `predicted_issue_code STRING`.
- Coded with `ai_classify` v2.1 (single call per ticket, stored once): labels are the six SOP 01 issue codes, each carrying its SOP 01 definition as the label description, plus a global instruction to pick the single code whose SOP definition best matches the customer's free-text description.
- Agreement with the agent-coded `issue_code`: **1,200 / 1,200 = 100%** (pass mark is 85%). Distribution: RIDER_DELAY 304, KITCHEN_DELAY 263, CUSTOMER_UNAVAILABLE 181, WRONG_ITEM 172, OTHER 170, DAMAGED_IN_TRANSIT 110 — 0 null predictions.

## 2. hop.genai.sop_chunks
- 36 rows — one chunk per `##` section across all eight SOP documents (5+5+5+5+4+4+4+4).
- Columns: `chunk_id STRING`, `doc_name INT` (1..8 from the file prefix), `heading STRING`, `chunk STRING` (section body alone), `text STRING`.
- `chunk_id = <filename>#<anchor>`; the anchor is the `##` heading lowercased with every run of non-alphanumeric characters collapsed to one hyphen, no leading/trailing hyphen. All 36 ids match that grammar. Sample: `01_Order_Lifecycle_and_Fault_Codes.md#order-events`.
- `text` (the embedding source) starts with the document's `#` title line and its `Applies to:` line, then the `##` heading and the body — verified for all 36 rows.
- `delta.enableChangeDataFeed = true` (verified via table properties) and `PRIMARY KEY (chunk_id)` constraint `sop_chunks_pk` declared — both Delta Sync index prerequisites.

## 3. hop.genai.sop_chunks_idx (Vector Search)
- Endpoint `hungryhop-vs` (STANDARD, ONLINE) — the single Vector Search endpoint Free Edition allows; none existed before this round.
- Index: DELTA_SYNC over `hop.genai.sop_chunks`, primary key `chunk_id`, embedding source column `text`, embedding model `databricks-gte-large-en`, pipeline type TRIGGERED, hybrid subtype.
- Status: ready = true, `indexed_row_count` = 36/36 chunks after the initial snapshot sync.
- Smoke retrieval for "A question about Instant orders and the late delivery compensation" returns, in order: `03_Late_Delivery_Compensation_Instant.md#when-no-coupon-is-given` (0.756), `03_...#when-an-order-counts-as-late` (0.752), `03_...#coupon-amount` (0.748) — the right SOP document and section rank first, which is what R11's citation rules require (Instant questions answered from the Instant SOP).

## Notes
- Two files with the same `# Late Delivery Compensation` title (03 Instant, 04 Standard) stay distinguishable through the chunk_id filename prefix and the doc_name number.
- ai_classify output is sampled; the classification is stored once in the table rather than recomputed, so downstream consumers read stable values.
