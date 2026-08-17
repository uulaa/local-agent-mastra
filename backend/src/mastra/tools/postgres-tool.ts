import { createTool } from "@mastra/core/tools";
import { z } from "zod";
import pg from "pg";

const pool = new pg.Pool({
  connectionString:
    process.env.POSTGRES_URL ??
    "postgresql://postgres:postgres@localhost:5432/company",
  max: 5,
});

const MAX_ROWS = 200;
const STATEMENT_TIMEOUT_MS = 10_000;

/** Reject anything that is not a single read-only statement. */
function assertReadOnly(sql: string): void {
  const trimmed = sql.trim().replace(/;\s*$/, "");
  if (trimmed.includes(";")) {
    throw new Error("Only a single SQL statement is allowed.");
  }
  if (!/^(select|with)\b/i.test(trimmed)) {
    throw new Error("Only SELECT (or WITH ... SELECT) queries are allowed.");
  }
}

export const postgresSchemaTool = createTool({
  id: "postgres-get-schema",
  description:
    "Introspect the live PostgreSQL schema: all tables and their columns with types. " +
    "The documented schema is already in your instructions — only call this as a " +
    "fallback when a query failed because the real schema differs from the documentation.",
  inputSchema: z.object({}),
  outputSchema: z.object({
    tables: z.array(
      z.object({
        table: z.string(),
        columns: z.array(z.object({ name: z.string(), type: z.string() })),
      }),
    ),
  }),
  execute: async () => {
    const { rows } = await pool.query<{
      table_name: string;
      column_name: string;
      data_type: string;
    }>(
      `SELECT table_name, column_name, data_type
       FROM information_schema.columns
       WHERE table_schema = 'public'
       ORDER BY table_name, ordinal_position`,
    );

    const byTable = new Map<string, { name: string; type: string }[]>();
    for (const row of rows) {
      const cols = byTable.get(row.table_name) ?? [];
      cols.push({ name: row.column_name, type: row.data_type });
      byTable.set(row.table_name, cols);
    }

    return {
      tables: [...byTable.entries()].map(([table, columns]) => ({
        table,
        columns,
      })),
    };
  },
});

export const postgresQueryTool = createTool({
  id: "postgres-query",
  description:
    "Run a read-only SQL query against the company PostgreSQL database with real business data " +
    "(sales, orders, customers, etc.). Use for statistical or numeric questions. " +
    "Only SELECT queries are allowed. Use postgres-get-schema first if unsure of the schema.",
  inputSchema: z.object({
    query: z
      .string()
      .describe("A single read-only SQL SELECT query. Include a LIMIT clause."),
  }),
  outputSchema: z.object({
    rows: z.array(z.record(z.string(), z.unknown())),
    rowCount: z.number(),
    truncated: z.boolean(),
  }),
  execute: async (input) => {
    assertReadOnly(input.query);

    const client = await pool.connect();
    try {
      await client.query("BEGIN TRANSACTION READ ONLY");
      await client.query(`SET LOCAL statement_timeout = ${STATEMENT_TIMEOUT_MS}`);
      const result = await client.query(input.query);
      await client.query("COMMIT");

      const rows = result.rows.slice(0, MAX_ROWS);
      return {
        rows,
        rowCount: result.rowCount ?? rows.length,
        truncated: result.rows.length > MAX_ROWS,
      };
    } catch (error) {
      await client.query("ROLLBACK").catch(() => {});
      throw error;
    } finally {
      client.release();
    }
  },
});
