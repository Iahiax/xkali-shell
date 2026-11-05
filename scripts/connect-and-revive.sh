#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# connect-and-revive.sh
# يتصل بـ segfault بدون أي مؤقت (تم إلغاء الـ timer bypass)
# ثم يشغّل الخدمات
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="${SCRIPT_DIR}/../config/secrets.env"

if [[ -f "$SECRETS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$SECRETS_FILE"
  echo "[*] Loaded secrets from config/secrets.env"
fi

SECRET="${SEGFault_SECRET:-}"
HOST="${SEGFault_HOST:-lsd.segfault.net}"
PASSWORD="segfault"

if [[ -z "$SECRET" ]]; then
  echo "[!] SEGFault_SECRET is empty"
  exit 1
fi

echo "[*] Target host: $HOST"
echo "[*] Connecting (no timer bypass)..."

EXPECT_SCRIPT=$(mktemp)
cat > "$EXPECT_SCRIPT" << 'EXPECT_EOF'
#!/usr/bin/expect -f
set timeout 90
set secret [lindex $argv 0]
set host  [lindex $argv 1]
set pass  [lindex $argv 2]

spawn ssh -o StrictHostKeyChecking=accept-new \
          -o UserKnownHostsFile=/dev/null \
          -o "SetEnv SECRET=$secret" \
          -o ServerAliveInterval=30 \
          -o ServerAliveCountMax=4 \
          root@$host

expect {
    -re "(?i)password:" {
        send "$pass\r"
        exp_continue
    }
    -re "(?i)yes/no" {
        send "yes\r"
        exp_continue
    }
    -re {[#\$] } {
        # وصلنا للـ prompt مباشرة
    }
    timeout {
        puts "Timeout waiting for shell prompt"
        exit 1
    }
}

# لا يوجد أي sleep أو Enter إضافي – تم إلغاء الموقت
send "echo CONNECTED_OK\r"
expect {
    "CONNECTED_OK" { puts "Remote shell ready" }
    timeout { puts "No confirmation received"; exit 1 }
}

# تأكد من وجود المجلدات
send "mkdir -p /sec/xkali-shell /sec/usr/bin /sec/usr/etc /sec/logs\r"
expect -re {[#\$] }

# شغّل tmux + الخدمات إن وُجدت
send "if [ -f /sec/xkali-shell/tmux-sessions/start-tmux.sh ]; then bash /sec/xkali-shell/tmux-sessions/start-tmux.sh; else echo NO_TMUX_SCRIPT; fi\r"
expect -re {[#\$] }

send "echo REVIVER_OK\r"
expect {
    "REVIVER_OK" { puts "Revive finished successfully" }
    timeout { puts "Revive confirmation missing" }
}

sleep 5
send "exit\r"
expect eof
EXPECT_EOF

chmod +x "$EXPECT_SCRIPT"

if expect -f "$EXPECT_SCRIPT" "$SECRET" "$HOST" "$PASSWORD"; then
  echo "[+] connect-and-revive completed"
  # إشعار نجاح (اختياري)
  if [[ -x "${SCRIPT_DIR}/notify.sh" ]]; then
    bash "${SCRIPT_DIR}/notify.sh" "Revive Success" "Connected to $HOST and started services" success || true
  fi
else
  echo "[!] connect-and-revive failed"
  if [[ -x "${SCRIPT_DIR}/notify.sh" ]]; then
    bash "${SCRIPT_DIR}/notify.sh" "Revive Failed" "Could not connect to $HOST" error || true
  fi
  rm -f "$EXPECT_SCRIPT"
  exit 1
fi

rm -f "$EXPECT_SCRIPT"
