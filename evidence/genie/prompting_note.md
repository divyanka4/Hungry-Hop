# R8 — Genie prompting & setup note (HungryHop Ops Assistant)

## Space
- **HungryHop Ops Assistant** — space id `01f1e8ca04201cd2adc50cc366bbe8a0`, warehouse `dcce4de94be7e086`.
- Tables: `hop.analytics.fact_orders` + `dim_date`, `dim_customer`, `dim_zone`, `dim_restaurant` (sorted by identifier — the update API rejects an unsorted list).
- Configured via `PATCH /api/2.0/genie/spaces/{id}` with `serialized_space` (version 2):
  - `instructions.text_instructions` — one instruction block (id must be lowercase 32-hex).
  - `instructions.example_question_sqls` — two worked examples.
  - `config.sample_questions` + per-table `description` arrays.

## What the instructions had to encode
1. **Frozen clock**: data ends 2026-08-31; forbid `current_date()`/`now()`; resolve "August 2026" → `placed_date` in 2026-08-01..2026-08-31.
2. **Late rule**: delivered only, `minutes_past_promise > 5` for instant, `> 20` for standard; cancelled orders are never late.
3. **Rate math**: conditional aggregation (`count_if`) over one filtered base — never averaging row flags.
4. **Geography**: delivery "city" from `dim_zone.city` (zone_id join); customer attributes from `dim_customer` (customer_id join).
5. **Rounding**: rates 4dp, money 2dp, minutes 2dp; answer format: number first, then SQL.

## Schema changes made for the benchmark (see sql/r6_star_schema.sql §5)
Ground-truth SQL expected columns that the R6 star schema lacked; all added via `ADD COLUMN` + backfill (no rebuild):
- `dim_zone.city` (backfilled from `hop.raw.zones`) and `zone_sk`
- `dim_date.date_key` (INT yyyyMMdd) and `month_start`
- `dim_customer.customer_sk` and a duplicate `tier` column (ground truth uses `c.tier`)
- `dim_restaurant.restaurant_sk`
- `fact_orders.placed_date_key`, `customer_sk`, `zone_sk`, `restaurant_sk`

Delta note: `RENAME COLUMN` is blocked without column mapping, hence the duplicate `tier` column instead of renaming `customer_tier`.

## Benchmark result
10/10 questions (B01–B10) answered with values exactly matching the ground-truth SQL results
(value-level grading, alias-insensitive — see benchmark_run.json). All 10 conversations
COMPLETED; each answer carried executable SQL over the aligned schema.

## API gotchas hit
- Serialized-space JSON fields probed: `general_instructions`/`text`/`general` rejected; correct shape is `text_instructions: [{id, content: [...]}]`.
- ids (sample questions, instructions, examples) must be lowercase 32-hex strings without hyphens.
- `data_sources.tables` must be sorted by identifier.
- Runtime: `POST /start-conversation` → poll `GET .../messages/{id}` until COMPLETED → read `attachments[].query.query` (SQL + statement_id) and `attachments[].text.content` (answer).