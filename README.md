# Local AI Agent

> 🇲🇳 **Монгол хэл дээрх суулгах бүрэн заавар:** [README.mn.md](README.mn.md)

A fully local AI agent for a small company — no cloud LLM dependency.
The agent answers statistical questions from PostgreSQL (real business
records) and knowledge questions from Qdrant (semantic search over company
documents), routing between the two automatically.

```
ai-agent/
├── ai-agent-web/    Next.js chat UI (Vercel AI SDK)
├── ai-agent-back/   Mastra backend: agent + Postgres/Qdrant tools
└── deployment/      docker-compose stack: web, back, postgres, qdrant, llm
```

## Quick start (Docker, recommended)

```sh
cd deployment
docker compose up --build
```

Open http://localhost:3000. Everything is included: the LLM (Ollama in a
container running Qwen), a seeded PostgreSQL demo database, and Qdrant with
pre-ingested company documents. See [deployment/README.md](deployment/README.md).

## Development without Docker

Run Ollama, Postgres, and Qdrant yourself, then `npm run dev` in
`ai-agent-back` (Mastra playground on :4111) and `ai-agent-web` (UI on :3000).
See the README in each folder.
