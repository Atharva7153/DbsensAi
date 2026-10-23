# =========================================================================
# Stage 1: Build the React Frontend SPA
# =========================================================================
FROM node:20-bookworm-slim AS frontend-builder

WORKDIR /app

# Copy root workspace and package manifests for caching
COPY package*.json ./
COPY frontend/package*.json ./frontend/
COPY backend/package*.json ./backend/

# Install dependencies across all npm workspaces
RUN npm install

# Copy frontend source files
COPY frontend/ ./frontend/

# Build production static assets (relative API path for single-domain routing)
WORKDIR /app/frontend
ENV VITE_API_URL=""
RUN npm run build

# =========================================================================
# Stage 2: Unified Production Container (AI Layer + Backend + Frontend)
# =========================================================================
FROM python:3.11-slim-bookworm

WORKDIR /app

# Prevent Python buffering and bytecode creation
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    NODE_ENV=production \
    PORT=5001 \
    AI_LAYER_URL=http://127.0.0.1:8000 \
    NODE_OPTIONS="--max-old-space-size=256"

# Install OS dependencies, build tools, curl, and Node.js 20
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    build-essential \
    python3-dev \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python AI Layer dependencies
COPY ai-layer/requirements.txt /app/ai-layer/requirements.txt
RUN pip install --no-cache-dir -r /app/ai-layer/requirements.txt

# Install Node Backend dependencies
COPY backend/package*.json /app/backend/
RUN cd /app/backend && npm install --omit=dev

# Copy application source code
COPY ai-layer /app/ai-layer
COPY backend /app/backend

# Copy compiled frontend assets from Stage 1
COPY --from=frontend-builder /app/frontend/dist /app/frontend/dist

# Copy container startup and process management script
COPY scripts/start.sh /app/scripts/start.sh
RUN chmod +x /app/scripts/start.sh

# Render dynamically sets PORT environment variable (default: 10000 on Render, 5001 local)
EXPOSE 5001

# Container healthcheck for local docker runtime
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f http://127.0.0.1:${PORT:-5001}/ping || exit 1

# Start all three tiers via unified entrypoint
CMD ["/app/scripts/start.sh"]
