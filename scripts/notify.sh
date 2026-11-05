#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# notify.sh – إرسال إشعارات (Telegram / Discord / ملف)
# الاستخدام: ./notify.sh "العنوان" "الرسالة" [error|info|success]
# ============================================================

TITLE="${1:-xkali-shell}"
MESSAGE="${2:-}"
LEVEL="${3:-info}"

LOG_DIR="${LOG_DIR:-/sec/logs}"
mkdir -p "$LOG_DIR"

# 1) سجل محلي دائماً
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$LEVEL] $TITLE – $MESSAGE" >> "${LOG_DIR}/notifications.log"

# 2) Telegram (اختياري – ضع التوكن في secrets.env)
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="*[${LEVEL}] ${TITLE}*%0A${MESSAGE}" \
    -d parse_mode="Markdown" >/dev/null 2>&1 || true
fi

# 3) Discord webhook (اختياري)
if [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
  curl -s -X POST "$DISCORD_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"**[${LEVEL}] ${TITLE}**\\n${MESSAGE}\"}" >/dev/null 2>&1 || true
fi

echo "[notify] $LEVEL – $TITLE"
