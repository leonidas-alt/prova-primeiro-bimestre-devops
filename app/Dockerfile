# ==============================================================
# Dockerfile — TechNova API (multi-stage, usuário não-root)
# Etapa 1: instala dependências (inclui devDependencies para
#           eventual build); Etapa 2: imagem de produção enxuta.
# ==============================================================

# ── Etapa 1: builder ────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /build

# Copia manifests e instala TODAS as deps (com lock file exato)
COPY package*.json ./
RUN npm ci --omit=dev

# ── Etapa 2: runtime ─────────────────────────────────────────
FROM node:20-alpine AS runtime

# Cria usuário não-root para executar a aplicação
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copia deps já instaladas da etapa builder
COPY --from=builder /build/node_modules ./node_modules

# Copia código-fonte
COPY src/ ./src/
COPY package.json ./

# Ajusta dono dos arquivos
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000

CMD ["node", "src/index.js"]
