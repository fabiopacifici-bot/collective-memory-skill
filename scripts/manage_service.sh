#!/usr/bin/env bash
# manage_collective_memory.sh — Start/stop the Multi-Agent Collective Memory service
#
# Usage:
#   bash manage_collective_memory.sh start   # Start the service
#   bash manage_collective_memory.sh stop    # Stop the service
#   bash manage_collective_memory.sh status  # Check if running
#   bash manage_collective_memory.sh restart # Restart the service

set -e

# Prefer canonical repo location under repositories/
REPO_DIR="/home/pacificDev/.openclaw/workspace/repositories/multi-agent-collective-memory"
if [ ! -d "$REPO_DIR" ]; then
    # Backward-compat fallback
    REPO_DIR="/home/pacificDev/.openclaw/workspace/multi-agent-collective-memory"
fi
VENV_DIR="$REPO_DIR/.venv-service"
PORT="${COLLECTIVE_MEMORY_PORT:-8010}"
PID_FILE="/tmp/collective-memory.pid"
LOG_FILE="/tmp/collective-memory.log"

start_service() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "✅ Collective Memory service already running (PID $(cat "$PID_FILE"))"
        return 0
    fi

    echo "Starting Collective Memory service on port $PORT..."

    # Source venv
    source "$VENV_DIR/bin/activate"

    # Ensure data directory
    mkdir -p "$REPO_DIR/data"

    # Ensure we're in the repo directory so 'app' module resolves
    cd "$REPO_DIR"

    # Start uvicorn in background
    export HF_HOME=/mnt/e/models/huggingface/hub
    nohup python -m uvicorn app.main:app \
        --host 0.0.0.0 \
        --port "$PORT" \
        --log-level info \
        > "$LOG_FILE" 2>&1 &

    PID=$!
    echo $PID > "$PID_FILE"
    echo "Service starting (PID $PID)..."

    # Wait for health check
    for i in $(seq 1 15); do
        sleep 1
        if curl -sS "http://localhost:$PORT/health" 2>/dev/null | grep -q "ok"; then
            echo "✅ Collective Memory service ready on http://localhost:$PORT"
            return 0
        fi
    done

    echo "⚠️  Service started but health check timed out. Check logs: $LOG_FILE"
    tail -5 "$LOG_FILE"
}

stop_service() {
    if [ ! -f "$PID_FILE" ]; then
        echo "No PID file found. Trying pkill..."
        pkill -f "uvicorn app.main:app" 2>/dev/null && echo "Stopped" || echo "No process found"
        return 0
    fi

    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        sleep 1
        if kill -0 "$PID" 2>/dev/null; then
            kill -9 "$PID" 2>/dev/null
        fi
        echo "Stopped Collective Memory service (PID $PID)"
    else
        echo "Process $PID not running"
    fi
    rm -f "$PID_FILE"
}

status_service() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "✅ Running — PID $(cat "$PID_FILE")"
        curl -sS "http://localhost:$PORT/health" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "(health check failed)"
    else
        echo "❌ Not running"
        if [ -f "$PID_FILE" ]; then
            echo "   (stale PID file found)"
        fi
    fi
}

case "${1:-status}" in
    start)   start_service ;;
    stop)    stop_service ;;
    restart) stop_service; sleep 1; start_service ;;
    status)  status_service ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac