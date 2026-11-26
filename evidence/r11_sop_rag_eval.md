# R11 — Hybrid RAG + Gold Answers + Evaluation

Built 2026-11-26 from [notebooks/r11_sop_rag_eval](../notebooks/r11_sop_rag_eval). The copilot answers support questions from the SOP binder with citations, and says exactly `not in the SOPs` when the binder has no answer.

## answer_sop_question(q)
- **Retrieval**: hybrid `query_index` (ANN + BM25) over `hop.genai.sop_chunks_idx`, top 10. BM25 keeps the class terms Instant/Standard decisive, which is what the 03-vs-04 citation rule needs.
- **LLM rerank** (permitted reranker): the chat model (temperature 0) reorders the 10 retrieved chunks best-first; top 5 survive. On rerank failure the hybrid order is kept unchanged.
- **Generation**: the chat model answers only from those 5 chunks, returns a JSON object with `answer`, `cited_chunk_ids` (bare chunk ids, best first, up to 5, filtered to the top 5) and `not_in_sops`; `not in the SOPs` answers carry no citations.
- Returns `question, answer, cited_chunk_ids, top5, rank (1-based position of the first citation), not_in_sops`.

## hop.genai.gold_answers
14 rows — questions, answers, cited_chunk_ids (ARRAY<STRING>, bare chunk ids, best first, up to 5):
- G01-G12 of `gold_set.json`, each answered from its expected SOP section.
- UQ1 "Does Hungryhop deliver alcohol?" and UQ2 "What is the monthly salary of a Hungryhop rider?" both answer exactly `not in the SOPs` with empty citations.

## Citation rules (verified in the run output)
- G04 and G05 cite a chunk of `03_Late_Delivery_Compensation_Instant.md` first.
- G06 and G07 cite a chunk of `04_Late_Delivery_Compensation_Standard.md` first.
- UQ1 and UQ2 answer `not in the SOPs`.

## evidence/r11_eval.json
- `hit_rate_at_5` = **1.000** and `mrr` = **1.000** over the 18 anchor questions G01-G18 (G19 multi-hop sentinel excluded per its own note) — every expected chunk ranks #1 after rerank. Gates (hit-rate@5 >= 0.80, MRR >= 0.70): **pass**.
- `judges`: 14/14 answers scored **1.0** by the chat-model judge against the gold set's expected facts, including the two `not in the SOPs` questions.
- `status` = pass, `ran` = 2026-11-26T07:35:23Z; no `error` key (the judges ran).

## Notes
- `ai_query` on `databricks-meta-llama-3-3-70b-instruct` rejects structured `responseFormat` on this endpoint, so the model replies with plain JSON text that the notebook parses; temperature stays 0 and every call is made once and read once.
- All model calls are single-shot per distinct input and stored (gold_answers) — sampled AI output is never recomputed for scoring.
