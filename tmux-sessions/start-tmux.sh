#!/usr/bin/env bash
set -euo pipefail

BASE="/sec"
XKALI="${BASE}/xkali-shell"
LOG="${BASE}/logs"
mkdir -p "$LOG"

echo "[*] start-tmux.sh – $(date -u +%Y-%m-%dT%H:%M:%SZ)"

chmod +x "${XKALI}/scripts/"*.sh 2>/dev/null || true
chmod +x "${XKALI}/config/"*.sh 2>/dev/null || true

# تثبيت المتطلبات مرة واحدة
if [[ -f "${XKALI}/scripts/install-deps.sh" ]]; then
  bash "${XKALI}/scripts/install-deps.sh" >>"${LOG}/install-deps.log" 2>&1 || true
fi

# تنظيف جلسات قديمة
tmux kill-session -t xkali-bots 2>/dev/null || true
tmux kill-session -t xkali-keeper 2>/dev/null || true
tmux kill-session -t xkali-main 2>/dev/null || true

# جلسة البوتات
tmux new-session -d -s xkali-bots -c "$BASE"
tmux send-keys -t xkali-bots "bash ${XKALI}/scripts/start-services.sh" Enter

# جلسة الـ keeper
tmux new-session -d -s xkali-keeper -c "$BASE"
tmux send-keys -t xkali-keeper "bash ${XKALI}/config/sf-keeper.sh" Enter

# جلسة تفاعلية
tmux new-session -d -s xkali-main -c "$BASE"
tmux send-keys -t xkali-main "echo 'xkali-shell ready – tmux attach -t xkali-main'" Enter

echo "[+] tmux sessions:"
tmux list-sessions 2>/dev/null || true
