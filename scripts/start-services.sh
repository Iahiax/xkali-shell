#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# start-services.sh
# Runs inside the segfault session.
# Starts: Node bot, Python bot, sf-keeper, supervisord, infinity loop
# Safe if one of the bots is missing.
# ============================================================

BASE="/sec"
BOTS_DIR="${BASE}/bots"
CONFIG_DIR="${BASE}/xkali-shell/config"
LOG_DIR="${BASE}/logs"
mkdir -p "$LOG_DIR" "$BOTS_DIR"

echo "[*] start-services.sh – $(date)"

# ---------- 1. Node.js bot ----------
start_node() {
  local dir="${BOTS_DIR}/node-bot"
  if [[ -f "${dir}/package.json" ]]; then
    echo "[*] Found Node.js bot"
    cd "$dir"
    if [[ ! -d node_modules ]]; then
      npm install --production --silent 2>>"${LOG_DIR}/node-install.log" || true
    fi
    # kill old instance
    pkill -f "node.*index.js" 2>/dev/null || true
    nohup node index.js >>"${LOG_DIR}/node-bot.log" 2>&1 &
    echo "[+] Node bot started (PID $!)"
  else
    echo "[*] No Node.js bot (package.json missing) – skipped"
  fi
}

# ---------- 2. Python bot ----------
start_python() {
  local dir="${BOTS_DIR}/python-bot"
  if [[ -f "${dir}/requirements.txt" ]] || [[ -f "${dir}/main.py" ]]; then
    echo "[*] Found Python bot"
    cd "$dir"
    if [[ -f requirements.txt ]]; then
      pip3 install -r requirements.txt --target /sec/usr --quiet 2>>"${LOG_DIR}/python-install.log" || true
      export PYTHONPATH="/sec/usr:${PYTHONPATH:-}"
    fi
    pkill -f "python.*main.py" 2>/dev/null || true
    nohup python3 main.py >>"${LOG_DIR}/python-bot.log" 2>&1 &
    echo "[+] Python bot started (PID $!)"
  else
    echo "[*] No Python bot – skipped"
  fi
}

# ---------- 3. sf-keeper (custom) ----------
start_sf_keeper() {
  local keeper="${CONFIG_DIR}/sf-keeper.sh"
  if [[ -x "$keeper" ]] || [[ -f "$keeper" ]]; then
    echo "[*] Starting sf-keeper"
    pkill -f "sf-keeper" 2>/dev/null || true
    nohup bash "$keeper" >>"${LOG_DIR}/sf-keeper.log" 2>&1 &
    echo "[+] sf-keeper started"
  else
    echo "[*] sf-keeper.sh not found – skipped"
  fi
}

# ---------- 4. supervisord ----------
start_supervisord() {
  local conf="${CONFIG_DIR}/supervisord.conf"
  if command -v supervisord >/dev/null 2>&1 && [[ -f "$conf" ]]; then
    echo "[*] Starting supervisord"
    pkill -f supervisord 2>/dev/null || true
    supervisord -c "$conf" >>"${LOG_DIR}/supervisord.log" 2>&1 &
    echo "[+] supervisord started"
  else
    echo "[*] supervisord not available or config missing – skipped"
  fi
}

# ---------- 5. PID 1 Infinity Loop (fallback keeper) ----------
start_infinity_loop() {
  local loop_script="${LOG_DIR}/infinity-loop.sh"
  cat > "$loop_script" << 'LOOP'
#!/bin/bash
while true; do
  # Node
  if [[ -f /sec/bots/node-bot/package.json ]]; then
    pgrep -f "node.*index.js" >/dev/null || {
      cd /sec/bots/node-bot && nohup node index.js >>/sec/logs/node-bot.log 2>&1 &
    }
  fi
  # Python
  if [[ -f /sec/bots/python-bot/main.py ]]; then
    pgrep -f "python.*main.py" >/dev/null || {
      cd /sec/bots/python-bot && \
      PYTHONPATH=/sec/usr nohup python3 main.py >>/sec/logs/python-bot.log 2>&1 &
    }
  fi
  sleep 45
done
LOOP
  chmod +x "$loop_script"
  pkill -f "infinity-loop.sh" 2>/dev/null || true
  nohup bash "$loop_script" >>"${LOG_DIR}/infinity.log" 2>&1 &
  echo "[+] Infinity loop started (PID $!)"
}

# Run all
start_node
start_python
start_sf_keeper
start_supervisord
start_infinity_loop

echo "[+] All requested services launched"
echo "[*] Logs under $LOG_DIR"
