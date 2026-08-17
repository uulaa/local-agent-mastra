"use client";

import { useState } from "react";
import { useChat } from "@ai-sdk/react";
import { DefaultChatTransport } from "ai";
import styles from "./chat.module.css";

const SUGGESTIONS = [
  "What were last month's sales?",
  "What is our vacation policy?",
  "How many customers do we have?",
  "How do refunds work?",
];

function toolLabel(type: string): string {
  const name = type.replace(/^tool-/, "");
  if (name.startsWith("postgres")) return `Querying database (${name})`;
  if (name === "search-company-docs") return "Searching company documents";
  return `Using tool: ${name}`;
}

export default function Chat() {
  const [input, setInput] = useState("");
  const { messages, sendMessage, status, error } = useChat({
    transport: new DefaultChatTransport({ api: "/api/chat" }),
  });

  const busy = status === "submitted" || status === "streaming";

  const submit = (text: string) => {
    const trimmed = text.trim();
    if (!trimmed || busy) return;
    sendMessage({ text: trimmed });
    setInput("");
  };

  return (
    <main className={styles.main}>
      <header className={styles.header}>
        <h1>Jarvis — Novatech Solutions</h1>
        <p>Local AI assistant · PostgreSQL statistics + company knowledge base</p>
      </header>

      <div className={styles.messages}>
        {messages.length === 0 && (
          <div className={styles.suggestions}>
            {SUGGESTIONS.map((s) => (
              <button key={s} onClick={() => submit(s)}>
                {s}
              </button>
            ))}
          </div>
        )}

        {messages.map((message) => (
          <div
            key={message.id}
            className={
              message.role === "user" ? styles.userMsg : styles.agentMsg
            }
          >
            {message.parts.map((part, i) => {
              if (part.type === "text") {
                return <p key={i}>{part.text}</p>;
              }
              if (part.type.startsWith("tool-") || part.type === "dynamic-tool") {
                const name =
                  part.type === "dynamic-tool"
                    ? (part as { toolName?: string }).toolName ?? "tool"
                    : part.type;
                return (
                  <p key={i} className={styles.tool}>
                    🔧 {toolLabel(name)}
                  </p>
                );
              }
              return null;
            })}
          </div>
        ))}

        {busy && <p className={styles.thinking}>Thinking…</p>}
        {error && (
          <p className={styles.error}>
            Error: {error.message}. Is the Mastra server running on port 4111?
          </p>
        )}
      </div>

      <form
        className={styles.inputRow}
        onSubmit={(e) => {
          e.preventDefault();
          submit(input);
        }}
      >
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask about sales numbers or company policies…"
          autoFocus
        />
        <button type="submit" disabled={busy || input.trim() === ""}>
          Send
        </button>
      </form>
    </main>
  );
}
