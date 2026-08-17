# ai-agent-back

Mastra backend for the local AI agent. Runs fully on local infrastructure:

- **Model runtime:** [Ollama](https://ollama.com) (OpenAI-compatible API, no cloud dependency)
- **Agent framework:** [Mastra](https://mastra.ai)
- **Tool 1 — PostgreSQL:** read-only SQL over real company data (statistics, numbers)
- **Tool 2 — Qdrant:** semantic search over internal documents (policies, rules, company info)

## Prerequisites

1. **Ollama** running locally with a tool-calling chat model and an embedding model:

   ```sh
   ollama pull qwen3:4b
   ollama pull nomic-embed-text
   ```

   > ⚠️ The chat model must support tool calling in Ollama. Qwen (`qwen3`, `qwen2.5`)
   > and `llama3.1` do; **Gemma does not** — with Gemma the agent cannot call tools.

2. **PostgreSQL** with the company database (any schema works — the agent
   introspects it with the `postgres-get-schema` tool).

3. **Qdrant** running locally, e.g.:

   ```sh
   docker run -d -p 6333:6333 -v qdrant_storage:/qdrant/storage qdrant/qdrant
   ```

## Setup

```sh
npm install
copy .env.example .env   # then edit connection strings
```

Ingest documents into Qdrant (put your `.md` / `.txt` files in `./docs` first —
a sample policy document is included):

```sh
npm run ingest
```

Re-run `npm run ingest` whenever documents change (it rebuilds the collection).

## Run

```sh
npm run dev
```

This starts the Mastra dev server with a playground at http://localhost:4111
where you can chat with the agent and inspect tool calls.

The frontend (`ai-agent-web`) talks to `POST /chat/company-agent`, an
AI SDK v5-compatible streaming endpoint registered in
`src/mastra/index.ts` via `@mastra/ai-sdk`'s `chatRoute`.

## Persona & memory

The agent has a persona — **Jarvis**, the AI assistant of Novatech Solutions
("Who are you?" always gets the canonical answer) — and Postgres-backed
conversation memory (`@mastra/memory` + `@mastra/pg`):

- Storage lives in the same Postgres instance as the demo data, but in a
  separate **`mastra` schema**, so the `postgres-get-schema` tool (which
  lists the `public` schema) never exposes memory tables as company data.
- The memory window is `lastMessages: 10` to keep prompts short for the
  small local model; semantic recall and title generation are off.
- Clients pass `memory: { thread, resource }` in the chat request body —
  the web app uses its conversation id as `thread` and a demo-wide
  `resource`, and sends only the newest message per request (the server
  rebuilds context from memory).

Try:

- *"What were last month's sales?"* → agent introspects the DB schema, writes a
  `SELECT`, and answers with real numbers.
- *"What is our vacation policy?"* → agent searches Qdrant and answers from the
  retrieved document chunks, citing the source file.

## Structure

```
src/mastra/index.ts               Mastra instance, registers the agent
src/mastra/agents/company-agent.ts  Agent config: Ollama model + routing instructions
src/mastra/tools/postgres-tool.ts   postgres-get-schema + postgres-query (SELECT-only)
src/mastra/tools/qdrant-tool.ts     search-company-docs (semantic search)
src/lib/embeddings.ts             Ollama embedding helper
scripts/ingest.ts                 docs → chunks → embeddings → Qdrant
```

## Safety notes

- The Postgres tool enforces **read-only** access: single statement, must start
  with `SELECT`/`WITH`, runs inside a `READ ONLY` transaction with a 10s
  statement timeout, and results are capped at 200 rows. For production, also
  connect with a DB role that only has `SELECT` grants.
- Everything runs locally; no data leaves the machine.
