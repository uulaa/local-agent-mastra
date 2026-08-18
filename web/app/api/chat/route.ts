// Proxies chat requests to the Mastra backend's AI SDK-compatible chat route
// (registered via @mastra/ai-sdk's chatRoute in ai-agent-back). Keeps the
// backend URL server-side and avoids CORS.
//
// Memory: the agent has Postgres-backed conversation memory. We pass the
// useChat conversation id as the Mastra threadId and a demo-wide resourceId,
// and forward only the newest message — the server rebuilds context from
// memory (last N messages), which keeps prompts short for the local model.

const MASTRA_URL = process.env.MASTRA_URL ?? "http://localhost:4111";
const AGENT_ID = process.env.MASTRA_AGENT_ID ?? "company-agent";
const RESOURCE_ID = process.env.MASTRA_RESOURCE_ID ?? "demo-user";

export async function POST(request: Request) {
  const body = await request.json();

  const payload = {
    ...body,
    messages: Array.isArray(body.messages)
      ? body.messages.slice(-1)
      : body.messages,
    memory: {
      thread:
        typeof body.id === "string" && body.id !== "" ? body.id : "default",
      resource: RESOURCE_ID,
    },
  };

  const upstream = await fetch(`${MASTRA_URL}/chat/${AGENT_ID}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  return new Response(upstream.body, {
    status: upstream.status,
    headers: {
      "Content-Type":
        upstream.headers.get("content-type") ?? "text/event-stream",
      "Cache-Control": "no-cache",
    },
  });
}
