import { createTool } from "@mastra/core/tools";
import { z } from "zod";
import { QdrantClient } from "@qdrant/js-client-rest";
import { embed } from "../../lib/embeddings.js";

const qdrant = new QdrantClient({
  url: process.env.QDRANT_URL ?? "http://localhost:6333",
});

export const COLLECTION =
  process.env.QDRANT_COLLECTION ?? "company_docs";

export const qdrantSearchTool = createTool({
  id: "search-company-docs",
  description:
    "Semantic search over internal company documents: company info, internal rules, " +
    "policies, procedures and other unstructured knowledge. Use for general questions " +
    "about how the company works. Returns the most relevant text chunks.",
  inputSchema: z.object({
    query: z
      .string()
      .describe("The user's question or a search phrase, in natural language."),
    topK: z
      .number()
      .int()
      .min(1)
      .max(20)
      .default(5)
      .describe("How many chunks to retrieve."),
  }),
  outputSchema: z.object({
    results: z.array(
      z.object({
        text: z.string(),
        source: z.string(),
        score: z.number(),
      }),
    ),
  }),
  execute: async (input) => {
    const [vector] = await embed([input.query]);

    const { points } = await qdrant.query(COLLECTION, {
      query: vector,
      limit: input.topK ?? 5,
      with_payload: true,
    });

    return {
      results: points.map((hit) => ({
        text: String(hit.payload?.text ?? ""),
        source: String(hit.payload?.source ?? "unknown"),
        score: hit.score,
      })),
    };
  },
});
