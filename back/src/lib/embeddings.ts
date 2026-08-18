const OLLAMA_BASE_URL =
  process.env.OLLAMA_BASE_URL ?? "http://localhost:11434";

export const EMBED_MODEL =
  process.env.OLLAMA_EMBED_MODEL ?? "nomic-embed-text";

/** Embed one or more texts with the local Ollama embedding model. */
export async function embed(texts: string[]): Promise<number[][]> {
  const res = await fetch(`${OLLAMA_BASE_URL}/api/embed`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ model: EMBED_MODEL, input: texts }),
  });

  if (!res.ok) {
    throw new Error(
      `Ollama embedding failed (${res.status}): ${await res.text()}`,
    );
  }

  const data = (await res.json()) as { embeddings: number[][] };
  return data.embeddings;
}
