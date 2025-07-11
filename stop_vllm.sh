#!/bin/bash
PID_FILE="vllm_server.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    echo "Stopping vLLM server with PID $PID..."
    kill "$PID" && rm -f "$PID_FILE"
    echo "✅ Stopped."
else
    echo "No PID file found. Is the server running?"
fi
