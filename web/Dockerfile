# Next.js frontend — multi-stage build using the standalone output.
FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
# --strict-ssl=false: the corporate FortiGate does TLS inspection, so the
# registry cert is re-signed by a CA the image doesn't trust. Build stage only;
# the runtime stage below never talks to the registry.
RUN npm ci --no-audit --no-fund --strict-ssl=false

COPY . .
RUN npm run build

FROM node:22-alpine

WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

ENV HOSTNAME=0.0.0.0
ENV PORT=3000
EXPOSE 3000

CMD ["node", "server.js"]
