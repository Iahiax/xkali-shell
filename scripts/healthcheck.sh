#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# healthcheck.sh
# يتحقق من حالة البوتات ويكتب heartbeat
# ============================================================

LOG_DIR="${LOG_DIR:-/sec/logs}"
mkdir -p "$LOG_DIR"
STATUS_FILE="${LOG_DIR}/status.json"
HEARTBEAT_FILE="${LOG_DIR}/heartbeat"

echo "[*] healthcheck – $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# اكتب heartbeat
date -u +%s > "$HEARTBEAT_FILE"

# تحقق من العمليات
node_ok=false
python_ok=false

if pgrep -f "node.*index.js" >/dev/null 2>&1; then
  node_ok=true
fi
if pgrep -f "python.*main.py" >/dev/null 2>&1; then
  python_ok=true
fi

# اكتب status.json بسيط
cat > "$STATUS_FILE" << JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "node_bot": $node_ok,
  "python_bot": $python_ok,
  "hostname": "$(hostname 2>/dev/null || echo unknown)"
}
JSON

echo "[+] status written to $STATUS_FILE"
cat "$STATUS_FILE"
