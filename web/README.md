# ai-agent-web

Next.js chat frontend for the local AI agent. Talks to the Mastra backend
(`ai-agent-back`) — everything runs locally.

## How it works

- [app/page.tsx](app/page.tsx) — chat UI built with the Vercel AI SDK v5
  (`useChat` from `@ai-sdk/react`). Shows tool activity ("Querying database…",
  "Searching company documents…") while the agent works.
- [app/api/chat/route.ts](app/api/chat/route.ts) — proxies chat requests to the
  Mastra server's AI SDK-compatible endpoint (`POST /chat/company-agent`,
  registered in the backend via `@mastra/ai-sdk`'s `chatRoute`). Keeps the
  backend URL server-side and avoids CORS. It also injects
  `memory: { thread, resource }` (thread = the useChat conversation id,
  resource = `MASTRA_RESOURCE_ID`, default `demo-user`) and forwards only the
  newest message — the agent's Postgres-backed memory supplies the history.

## Run

Start the backend first (see `../ai-agent-back/README.md` — Ollama, Postgres
and Qdrant must be running), then:

```sh
npm install
npm run dev
```

Open http://localhost:3000.

Configuration (optional, defaults work for local dev): copy `.env.example` to
`.env.local` and adjust `MASTRA_URL` / `MASTRA_AGENT_ID`.

> Note: the frontend pins `ai@^5` / `@ai-sdk/react@^2` because the backend's
> `@mastra/ai-sdk` chat route streams the AI SDK **v5** UI-message protocol.
> Don't bump to `ai@6+` without also switching the backend route to
> `version: 'v6'`.
