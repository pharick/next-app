# Install Nodejs
FROM ubuntu:jammy as base

ENV NODE_MAJOR 20
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    npm install -g npm

# Install dependencies
FROM base as deps
WORKDIR /usr/src/app

COPY ./next-app/package.json ./next-app/package-lock.json ./
RUN npm ci

# Build
FROM base as builder

WORKDIR /usr/src/app
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY ./next-app/ ./

RUN npm run build

# Production
FROM base AS runner
WORKDIR /usr/src/app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /usr/src/app/public ./public

RUN mkdir .next && chown nextjs:nodejs .next

COPY --from=builder --chown=nextjs:nodejs /usr/src/app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /usr/src/app/.next/static ./.next/static

USER nextjs

EXPOSE 80

ENV PORT 80
ENV HOSTNAME 0.0.0.0

CMD ["sh", "-c", "HOSTNAME=$HOST node server.js"]
