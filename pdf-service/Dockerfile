# ─────────────────────────────────────────────────────────────────────────────
# Dataferme PDF Service — Image Docker
#
# Génère des PDFs IDENTIQUES au bouton "Rapport" de l'application,
# en utilisant le même code (rapport-pdf.html + jsPDF) via Puppeteer.
#
# Déploiement via Coolify :
#   1. Créer un nouveau service "Docker Build" dans Coolify
#   2. Pointer vers ce dossier (Dockerfile + pdf-service.js + rapport-pdf.html)
#   3. Port exposé : 3001
#   4. Pas de variable d'environnement requise
#
# Test local :
#   docker build -t dataferme-pdf .
#   docker run -p 3001:3001 dataferme-pdf
#   curl http://localhost:3001/health
# ─────────────────────────────────────────────────────────────────────────────

FROM node:20-slim

# ── 1. Dépendances système pour Chrome headless (Puppeteer) ──────────────────
RUN apt-get update && apt-get install -y \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libcairo2 \
    libxshmfence1 \
    fonts-liberation \
    fonts-noto-color-emoji \
    ca-certificates \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Répertoire de travail ──────────────────────────────────────────────────
WORKDIR /app

# ── 3. Dépendances Node.js (layer cachée séparée pour rebuild rapide) ─────────
COPY package.json ./
RUN npm install

# ── 3b. Installer Chrome dans l'image (permanent — survit aux redéploiements) ─
ENV PUPPETEER_CACHE_DIR=/opt/puppeteer-cache
RUN npx puppeteer browsers install chrome

# ── 4. Fichiers de l'application ──────────────────────────────────────────────
COPY pdf-service.js   ./
COPY rapport-pdf.html ./

# ── 5. Utilisateur non-root ───────────────────────────────────────────────────
RUN groupadd -r pptruser \
    && useradd -r -g pptruser -G audio,video pptruser \
    && mkdir -p /home/pptruser/.cache \
    && chown -R pptruser:pptruser /home/pptruser \
    && chown -R pptruser:pptruser /app \
    && chown -R pptruser:pptruser /opt/puppeteer-cache

USER pptruser

# ── 6. Variables ──────────────────────────────────────────────────────────────
ENV PDF_SERVICE_PORT=3001

# ── 7. Port et healthcheck ────────────────────────────────────────────────────
EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3001/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "pdf-service.js"]
