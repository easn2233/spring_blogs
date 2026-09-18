# ---- Build stage ----
FROM node:22-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Next.js resolves rewrites at build time (they are baked into
# routes-manifest.json), so the backend address must be injected here.
# Process env wins over the value in .env.production.
ARG SERVER_API_BASE_URL=http://server:8080/api
ENV SERVER_API_BASE_URL=${SERVER_API_BASE_URL} \
    NEXT_TELEMETRY_DISABLED=1

# next/font/google downloads font files at build time; retry once
# because those requests can fail transiently on restricted networks.
RUN npm run build || (echo '--- build failed, retrying once ---' && sleep 5 && npm run build)

# ---- Runtime stage: Next.js standalone output ----
FROM node:22-alpine
WORKDIR /app

# request.ts reads this at RUNTIME for server-side data fetching and
# falls back to 127.0.0.1 (unreachable inside a container) without it.
ARG SERVER_API_BASE_URL=http://server:8080/api
ENV SERVER_API_BASE_URL=${SERVER_API_BASE_URL} \
    NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public

EXPOSE 3000
CMD ["node", "server.js"]
