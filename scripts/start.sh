#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================================"
echo "  🚀 DBSense AI: Starting Unified Multi-Tier Service   "
echo "======================================================"

# Default ports and internal routing
export PORT="${PORT:-5001}"
export AI_LAYER_URL="${AI_LAYER_URL:-http://127.0.0.1:8000}"
export PYTHONUNBUFFERED=1
export NODE_ENV="${NODE_ENV:-production}"
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=256}"

# Step 1: Start Python AI Layer (FastAPI on internal port 8000)
echo "🧠 [1/2] Starting AI Layer on 127.0.0.1:8000..."
cd "$ROOT_DIR/ai-layer"
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000 --workers 1 &
AI_PID=$!

# Step 2: Wait for AI Layer to be healthy
echo "⏳ Waiting for AI Layer initialization..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if curl -s http://127.0.0.1:8000/health >/dev/null 2>&1 || curl -s http://127.0.0.1:8000/ping >/dev/null 2>&1; then
    echo "✅ AI Layer is online and responsive!"
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
  sleep 0.5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "⚠️ AI Layer health check timed out, proceeding to start Backend anyway..."
fi

# Step 3: Start Node.js Backend & SPA Server on Render $PORT
echo "🌐 [2/2] Starting Node.js Server on port ${PORT}..."
cd "$ROOT_DIR/backend"
node server.js &
NODE_PID=$!

# Step 4: Signal trapping & Graceful Shutdown
cleanup() {
  echo "🛑 Received termination signal. Gracefully shutting down services..."
  kill -TERM "$NODE_PID" 2>/dev/null || true
  kill -TERM "$AI_PID" 2>/dev/null || true
  wait "$NODE_PID" 2>/dev/null || true
  wait "$AI_PID" 2>/dev/null || true
  echo "👋 Services terminated cleanly."
  exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

# Step 5: Wait for any process to exit
wait -n "$AI_PID" "$NODE_PID"
EXIT_CODE=$?

echo "⚠️ Service process exited with code $EXIT_CODE. Exiting container..."
cleanup
exit $EXIT_CODE
