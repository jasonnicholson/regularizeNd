#!/bin/bash
# Run MATLAB script with CPU/RAM monitoring
# Usage: ./run_with_monitoring.sh <path_to_matlab_file>

set -e

MATLAB_FILE="${1:?Please provide a MATLAB file path}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/matlab_resource_log.csv"

echo "=========================================="
echo "MATLAB Resource Monitor"
echo "=========================================="
echo "MATLAB Script: $MATLAB_FILE"
echo "Log File: $LOG_FILE"
echo ""

# Start monitoring in background
python3 "$SCRIPT_DIR/monitor_matlab_resources.py" "$LOG_FILE" 1 &
MONITOR_PID=$!
echo "Started resource monitor (PID: $MONITOR_PID)"
echo ""

# Give monitor time to detect MATLAB startup
sleep 2

# Start MATLAB and run the script
echo "Starting MATLAB..."
matlab -batch "run('$MATLAB_FILE'); exit;" 

# Monitor may still be running, give it time to clean up
sleep 2

# Kill monitor if still running
if ps -p $MONITOR_PID > /dev/null 2>&1; then
    kill $MONITOR_PID 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "Execution complete!"
echo "Resource log saved to: $LOG_FILE"
echo "=========================================="
