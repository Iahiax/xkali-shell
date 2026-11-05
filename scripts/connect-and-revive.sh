#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# connect-and-revive.sh
# Connects to lsd.segfault.net, bypasses initial timer,
# starts services inside the session.
# ============================================================

# Load local secrets file if it exists (preferred when not using GitHub Secrets)
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
  echo "[!] SEGFault_SECRET is empty. Set it as a repository secret."
  exit 1
fi

echo "[*] Target host: $HOST"
echo "[*] Using SECRET (length: ${#SECRET})"

# Create a temporary expect script to handle the interactive login + timer bypass
EXPECT_SCRIPT=$(mktemp)
cat > "$EXPECT_SCRIPT" << 'EOF'
#!/usr/bin/expect -f
set timeout 120
set secret [lindex $argv 0]
set host  [lindex $argv 1]
set pass  [lindex $argv 2]

spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
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
        # Already at shell prompt
    }
    timeout {
        puts "Timeout waiting for password/prompt"
        exit 1
    }
}

# Bypass the initial ~60s boot timer
# 1) wait 2 seconds then press Enter
sleep 2
send "\r"

# 2) wait 61 seconds then press Enter again
sleep 61
send "\r"

# Give the shell a moment
sleep 2

# Now run the remote bootstrap commands
send "mkdir -p /sec/xkali-shell /sec/usr/bin /sec/usr/etc\r"
expect -re {[#\$] }

# Upload is handled separately; here we just ensure tmux + services start
send "command -v tmux >/dev/null || apt-get update && apt-get install -y tmux 2>/dev/null || true\r"
expect -re {[#\$] }

send "cd /sec && bash -c 'if [ -f /sec/xkali-shell/tmux-sessions/start-tmux.sh ]; then bash /sec/xkali-shell/tmux-sessions/start-tmux.sh; else echo no-start-tmux; fi'\r"
expect -re {[#\$] }

send "echo REVIVER_OK\r"
expect {
    "REVIVER_OK" { puts "Remote revive finished" }
    timeout { puts "No REVIVER_OK received" }
}

# Keep the connection alive a bit so background processes can start
sleep 10
send "exit\r"
expect eof
EOF

chmod +x "$EXPECT_SCRIPT"

echo "[*] Connecting and reviving..."
expect -f "$EXPECT_SCRIPT" "$SECRET" "$HOST" "$PASSWORD" || {
  echo "[!] expect failed – connection or timer bypass issue"
  rm -f "$EXPECT_SCRIPT"
  exit 1
}

rm -f "$EXPECT_SCRIPT"
echo "[+] connect-and-revive completed"
