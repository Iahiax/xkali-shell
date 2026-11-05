#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# start-services.sh  (اقتراح 5 + 8)
# يقرأ config/bots.yaml ويشغّل البوتات المفعّلة فقط
# يدعم Node + Python، ويتخطى أي بوت غير موجود
# ============================================================

BASE="/sec"
XKALI="${BASE}/xkali-shell"
BOTS_YAML="${XKALI}/config/bots.yaml"
LOG_DIR="${BASE}/logs"
mkdir -p "$LOG_DIR"

echo "[*] start-services.sh – $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---------- دالة مساعدة لتشغيل بوت ----------
start_bot() {
  local name="$1"
  local type="$2"
  local path="$3"
  local command="$4"

  local full_path="${BASE}/${path}"
  if [[ ! -d "$full_path" ]]; then
    echo "[*] [$name] path not found ($full_path) – skipped"
    return 0
  fi

  echo "[*] Starting [$name] ($type) ..."
  cd "$full_path"

  if [[ "$type" == "node" ]]; then
    if [[ -f package.json ]] && [[ ! -d node_modules ]]; then
      npm install --production --silent >>"${LOG_DIR}/${name}-install.log" 2>&1 || true
    fi
    pkill -f "$command" 2>/dev/null || true
    nohup bash -c "$command" >>"${LOG_DIR}/${name}.log" 2>&1 &
    echo "[+] [$name] started (PID $!)"
  elif [[ "$type" == "python" ]]; then
    if [[ -f requirements.txt ]]; then
      pip3 install -r requirements.txt --target /sec/usr --quiet >>"${LOG_DIR}/${name}-install.log" 2>&1 || true
      export PYTHONPATH="/sec/usr:${PYTHONPATH:-}"
    fi
    pkill -f "$command" 2>/dev/null || true
    nohup env PYTHONPATH="/sec/usr:${PYTHONPATH:-}" bash -c "$command" >>"${LOG_DIR}/${name}.log" 2>&1 &
    echo "[+] [$name] started (PID $!)"
  else
    echo "[!] [$name] unknown type: $type"
  fi
}

# ---------- قراءة bots.yaml بطريقة بسيطة (بدون yq) ----------
if [[ ! -f "$BOTS_YAML" ]]; then
  echo "[!] bots.yaml not found – falling back to classic detection"
  # fallback
  if [[ -f "${BASE}/bots/node-bot/package.json" ]]; then
    start_bot "node-main" "node" "bots/node-bot" "node index.js"
  fi
  if [[ -f "${BASE}/bots/python-bot/main.py" ]]; then
    start_bot "python-worker" "python" "bots/python-bot" "python3 main.py"
  fi
else
  echo "[*] Reading $BOTS_YAML"
  # تحليل بسيط لـ YAML (يعمل مع الهيكل الحالي)
  current_name=""
  current_type=""
  current_path=""
  current_command=""
  current_enabled="true"

  while IFS= read -r line || [[ -n "$line" ]]; do
    # تجاهل التعليقات والفراغات
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    if [[ "$line" =~ name:[[:space:]]*(.+) ]]; then
      # قبل البدء ببوت جديد، شغّل السابق إن وُجد
      if [[ -n "$current_name" && "$current_enabled" == "true" ]]; then
        start_bot "$current_name" "$current_type" "$current_path" "$current_command"
      fi
      current_name="${BASH_REMATCH[1]//\"/}"
      current_type=""
      current_path=""
      current_command=""
      current_enabled="true"
    elif [[ "$line" =~ type:[[:space:]]*(.+) ]]; then
      current_type="${BASH_REMATCH[1]//\"/}"
    elif [[ "$line" =~ path:[[:space:]]*(.+) ]]; then
      current_path="${BASH_REMATCH[1]//\"/}"
    elif [[ "$line" =~ command:[[:space:]]*(.+) ]]; then
      current_command="${BASH_REMATCH[1]//\"/}"
    elif [[ "$line" =~ enabled:[[:space:]]*(.+) ]]; then
      current_enabled="${BASH_REMATCH[1]//\"/}"
    fi
  done < "$BOTS_YAML"

  # آخر بوت
  if [[ -n "$current_name" && "$current_enabled" == "true" ]]; then
    start_bot "$current_name" "$current_type" "$current_path" "$current_command"
  fi
fi

# ---------- sf-keeper ----------
if [[ -f "${XKALI}/config/sf-keeper.sh" ]]; then
  pkill -f "sf-keeper" 2>/dev/null || true
  nohup bash "${XKALI}/config/sf-keeper.sh" >>"${LOG_DIR}/sf-keeper.log" 2>&1 &
  echo "[+] sf-keeper started"
fi

# ---------- supervisord ----------
if command -v supervisord >/dev/null 2>&1 && [[ -f "${XKALI}/config/supervisord.conf" ]]; then
  pkill -f supervisord 2>/dev/null || true
  supervisord -c "${XKALI}/config/supervisord.conf" >>"${LOG_DIR}/supervisord.log" 2>&1 &
  echo "[+] supervisord started"
fi

# ---------- Infinity Loop + healthcheck ----------
LOOP_SCRIPT="${LOG_DIR}/infinity-loop.sh"
cat > "$LOOP_SCRIPT" << 'LOOP'
#!/bin/bash
while true; do
  # أعد تشغيل البوتات إذا ماتت
  if [[ -f /sec/bots/node-bot/package.json ]]; then
    pgrep -f "node.*index.js" >/dev/null || {
      cd /sec/bots/node-bot && nohup node index.js >>/sec/logs/node-main.log 2>&1 &
    }
  fi
  if [[ -f /sec/bots/python-bot/main.py ]]; then
    pgrep -f "python.*main.py" >/dev/null || {
      cd /sec/bots/python-bot && \
      PYTHONPATH=/sec/usr nohup python3 main.py >>/sec/logs/python-worker.log 2>&1 &
    }
  fi
  # healthcheck
  if [[ -x /sec/xkali-shell/scripts/healthcheck.sh ]]; then
    bash /sec/xkali-shell/scripts/healthcheck.sh >/dev/null 2>&1 || true
  fi
  sleep 45
done
LOOP
chmod +x "$LOOP_SCRIPT"
pkill -f "infinity-loop.sh" 2>/dev/null || true
nohup bash "$LOOP_SCRIPT" >>"${LOG_DIR}/infinity.log" 2>&1 &
echo "[+] Infinity loop + healthcheck started"

echo "[+] All services launched"
