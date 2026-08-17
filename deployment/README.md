# Deployment — full local demo stack

Runs the entire AI agent demo with Docker: frontend, Mastra backend,
PostgreSQL (seeded), Qdrant (auto-ingested docs), and the LLM (Ollama in a
container, no native install needed).

## Run

```sh
cd deployment
docker compose up --build
```

First start takes a while: it builds both app images and downloads the models
(`qwen3:4b` ≈ 2.6 GB + `nomic-embed-text` ≈ 0.3 GB) into a Docker volume.
Subsequent starts are fast — models, database, and vectors persist in volumes.

Then open **http://localhost:3000** and ask:

- *"What were last month's sales?"* → Postgres tool (seeded data)
- *"What is our vacation policy?"* → Qdrant tool (ingested docs)

The Mastra playground (inspect tool calls) is at http://localhost:4111.

## Services

| Service    | Image / build      | Port  | Purpose                                    |
| ---------- | ------------------ | ----- | ------------------------------------------ |
| `web`      | ../ai-agent-web    | 3000  | Next.js chat UI                            |
| `back`     | ../ai-agent-back   | 4111  | Mastra agent + tools                       |
| `postgres` | postgres:17-alpine | 5432  | Seeded demo data (12 tables, 100+ rows ea.)|
| `qdrant`   | qdrant/qdrant      | 6333  | Vector DB for document search              |
| `llm`      | ollama/ollama      | 11434 | Local LLM runtime (OpenAI-compatible API)  |
| `llm-init` | one-shot           | —     | Pulls chat + embedding models              |
| `ingest`   | one-shot           | —     | Embeds ai-agent-back/docs into Qdrant      |

Configuration lives in [.env](.env) — DB credentials, ports, model names.
The model must support tool calling (qwen3/qwen2.5 do; **Gemma does not**).
On a weak machine set `OLLAMA_MODEL=qwen3:1.7b` for faster CPU inference.

## Seed data

[postgres/01-init.sql](postgres/01-init.sql) runs automatically on first start
(empty `pg_data` volume) and generates realistic billing data for the fictional
company "Novatech Solutions": billing_plans, customers, users, products,
subscriptions, invoices, invoice_items, payments, transactions, sales,
usage_logs, support_tickets. Dates are generated relative to today, and
invoice totals, line items, and payments are internally consistent.

To re-seed from scratch: `docker compose down -v` (deletes all volumes,
including downloaded models), or just the DB:
`docker volume rm ai-agent_pg_data` while the stack is down.

## GPU

CPU inference works but is slow for chat. With an NVIDIA GPU + Docker GPU
support, uncomment the `deploy.resources` block under `llm` in
[docker-compose.yaml](docker-compose.yaml).
