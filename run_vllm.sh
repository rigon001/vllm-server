#!/bin/bash

# --- Script to start vLLM OpenAI-compatible API Server and manage logs/PID ---

# Adjust these paths as needed
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR" || { echo "Error: Could not enter $SCRIPT_DIR"; exit 1; }

LOGS_DIR="logs"
PID_FILE="vllm_server.pid"
LOG_FILE="$LOGS_DIR/vllm_server.log"

# Model & server config
MODEL_PATH="/home/user/.cache/huggingface/hub/models--meta-llama--Llama-3.1-8B-Instruct/snapshots/0e9e39f249a16976918f6564b8830bc894c89659"
MODEL_NAME="llama-3.1-8b-instruct"
PORT="8000"
HOST="0.0.0.0"

# Check for stale or active process
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null; then
        echo "vLLM server already running with PID $OLD_PID. Stop it first using ./stop_vllm.sh"
        exit 1
    else
        echo "Stale PID file found. Removing $PID_FILE."
        rm -f "$PID_FILE"
    fi
fi

# Prepare logs
echo "--- Preparing log directory ---"
rm -rf "$LOGS_DIR"/*
mkdir -p "$LOGS_DIR"

# Start the server
echo "Starting vLLM server with nohup..."
nohup python3 -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_PATH" \
    --served-model-name "$MODEL_NAME" \
    --tensor-parallel-size 1 \
    --max-model-len 16384 \
    --gpu-memory-utilization 0.9 \
    --max-num-seqs 2 \
    --host "$HOST" \
    --port "$PORT" \
    --uvicorn-log-level debug \
    > "$LOG_FILE" 2>&1 &

# Save PID
VLLM_PID=$!
echo $VLLM_PID > "$PID_FILE"
echo "vLLM server started with PID $VLLM_PID"

# Wait for health
echo -n "Waiting for vLLM server readiness on http://$HOST:$PORT/health ..."

while true; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$HOST:$PORT/health)
    if [[ "$STATUS" =~ ^2|3 ]]; then
        echo -e "\n✅ vLLM server is up (HTTP $STATUS)"
        echo "Logs in $LOG_FILE, PID in $PID_FILE"
        break
    fi
    echo -n "."
    sleep 2
done
