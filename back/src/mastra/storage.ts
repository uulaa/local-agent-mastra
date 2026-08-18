import { PostgresStore } from "@mastra/pg";

// Shared Mastra storage: lives in the demo Postgres instance, but in its own
// "mastra" schema so the agent's schema-introspection tool (which lists the
// "public" schema) never sees Mastra's tables as company data.
export const storage = new PostgresStore({
  id: "agent-storage",
  connectionString:
    process.env.POSTGRES_URL ??
    "postgresql://postgres:postgres@localhost:5432/company",
  schemaName: "mastra",
});
