# Mastra backend. Single-stage on purpose: the image keeps dev deps and
# source so the same image can run the server (default CMD) and the Qdrant
# ingest job (docker compose runs `npm run ingest` in a one-shot container).
FROM node:22-alpine

WORKDIR /app

COPY package.json package-lock.json ./
# --strict-ssl=false: the corporate FortiGate does TLS inspection, so the
# registry cert is re-signed by a CA the image doesn't trust.
RUN npm ci --no-audit --no-fund --strict-ssl=false

COPY . .
RUN npm run build

ENV HOST=0.0.0.0
ENV PORT=4111
EXPOSE 4111

CMD ["npm", "run", "start"]
