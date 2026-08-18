import { Mastra } from "@mastra/core/mastra";
import { chatRoute } from "@mastra/ai-sdk";
import { companyAgent } from "./agents/company-agent.js";
import { storage } from "./storage.js";

const envNumber = (value: string | undefined, fallback: number): number => {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
};

// Sampling parameters, tunable via .env (deployment/.env in Docker).
const LLM_TEMPERATURE = envNumber(process.env.LLM_TEMPERATURE, 0.3);
const LLM_TOP_P = envNumber(process.env.LLM_TOP_P, 0.9);
const LLM_TOP_K = envNumber(process.env.LLM_TOP_K, 30);
// Ollama defaults to a 4096-token context; the system prompt (persona + DB
// schema) plus memory exceeds that, and Ollama silently truncates from the
// top when it overflows — which cuts off the instructions.
const LLM_NUM_CTX = envNumber(process.env.LLM_NUM_CTX, 8192);

export const mastra = new Mastra({
  agents: { companyAgent },
  storage,
  server: {
    // Bind 0.0.0.0 in Docker so other containers can reach the server.
    host: process.env.HOST ?? "localhost",
    port: Number(process.env.PORT ?? 4111),
    // AI SDK v5-compatible streaming endpoint for the frontend:
    // POST /chat/company-agent (proxied by ai-agent-web's /api/chat route).
    apiRoutes: [
      chatRoute({
        path: "/chat/:agentId",
        defaultOptions: {
          modelSettings: {
            temperature: LLM_TEMPERATURE,
            topP: LLM_TOP_P,
          },
          // top_k is not part of the standard AI SDK call settings the
          // Ollama provider maps, so pass it as a native Ollama option.
          // think:true makes Ollama separate qwen3's chain-of-thought into a
          // dedicated "thinking" field (surfaced as AI SDK reasoning parts,
          // which chatRoute does not forward to the client). With think
          // false/unset the model reasons anyway and the raw <think> text
          // leaks into the visible answer.
          providerOptions: {
            ollama: {
              think: true,
              options: { top_k: LLM_TOP_K, num_ctx: LLM_NUM_CTX },
            },
          },
        },
      }),
    ],
  },
});
