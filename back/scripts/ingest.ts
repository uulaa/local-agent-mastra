/**
 * Ingest local documents into Qdrant.
 *
 * Reads every .md / .txt file in ./docs, splits it into overlapping chunks,
 * embeds the chunks with the local Ollama embedding model, and upserts them
 * into the Qdrant collection used by the search-company-docs tool.
 *
 * Usage: npm run ingest
 */
import "dotenv/config";
import { readdir, readFile } from "node:fs/promises";
import { join, extname } from "node:path";
import { QdrantClient } from "@qdrant/js-client-rest";
import { embed, EMBED_MODEL } from "../src/lib/embeddings.js";

const envNumber = (value: string | undefined, fallback: number): number => {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : fallback;
};

const DOCS_DIR = process.env.DOCS_DIR ?? "docs";
const COLLECTION = process.env.QDRANT_COLLECTION ?? "company_docs";
const CHUNK_SIZE = envNumber(process.env.CHUNK_SIZE, 400);
// Overlap must stay below chunk size or the chunking loop can't advance.
const CHUNK_OVERLAP = Math.min(
  envNumber(process.env.CHUNK_OVERLAP, 60),
  CHUNK_SIZE - 1,
);

const qdrant = new QdrantClient({
  url: process.env.QDRANT_URL ?? "http://localhost:6333",
});

function chunkText(text: string): string[] {
  const clean = text.replace(/\r\n/g, "\n").trim();
  const chunks: string[] = [];
  for (let start = 0; start < clean.length; start += CHUNK_SIZE - CHUNK_OVERLAP) {
    const chunk = clean.slice(start, start + CHUNK_SIZE).trim();
    if (chunk.length > 0) chunks.push(chunk);
    if (start + CHUNK_SIZE >= clean.length) break;
  }
  return chunks;
}

async function main() {
  const files = (await readdir(DOCS_DIR)).filter((f) =>
    [".md", ".txt"].includes(extname(f).toLowerCase()),
  );
  if (files.length === 0) {
    console.error(`No .md or .txt files found in ./${DOCS_DIR}`);
    process.exit(1);
  }

  console.log(
    `Embedding with Ollama model "${EMBED_MODEL}" (chunk size ${CHUNK_SIZE}, overlap ${CHUNK_OVERLAP})...`,
  );

  let nextId = 1;
  const points: {
    id: number;
    vector: number[];
    payload: { text: string; source: string };
  }[] = [];

  for (const file of files) {
    const text = await readFile(join(DOCS_DIR, file), "utf8");
    const chunks = chunkText(text);
    console.log(`  ${file}: ${chunks.length} chunk(s)`);

    const vectors = await embed(chunks);
    for (let i = 0; i < chunks.length; i++) {
      points.push({
        id: nextId++,
        vector: vectors[i],
        payload: { text: chunks[i], source: file },
      });
    }
  }

  const dimension = points[0].vector.length;

  // Recreate the collection so re-running ingest gives a clean index.
  const { exists } = await qdrant.collectionExists(COLLECTION);
  if (exists) await qdrant.deleteCollection(COLLECTION);
  await qdrant.createCollection(COLLECTION, {
    vectors: { size: dimension, distance: "Cosine" },
  });

  await qdrant.upsert(COLLECTION, { wait: true, points });
  console.log(
    `Done: ${points.length} chunks from ${files.length} file(s) → collection "${COLLECTION}" (dim ${dimension})`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
