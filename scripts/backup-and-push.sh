#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# backup-and-push.sh
# Pulls important files from /sec on the remote session
# and commits them back to this repository.
# ============================================================

# Load local secrets file if it exists
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
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
LOCAL_BACKUP="./.backup-tmp"

if [[ -z "$SECRET" ]]; then
  echo "[!] SEGFault_SECRET missing"
  exit 1
fi

mkdir -p "$LOCAL_BACKUP"

echo "[*] Creating remote archive of /sec (bots + config + important dirs)..."

# Use expect + scp / ssh to pull a tarball
EXPECT_PULL=$(mktemp)
cat > "$EXPECT_PULL" << 'EOF'
#!/usr/bin/expect -f
set timeout 180
set secret [lindex $argv 0]
set host  [lindex $argv 1]
set pass  [lindex $argv 2]

spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o "SetEnv SECRET=$secret" \
          root@$host

expect {
    -re "(?i)password:" { send "$pass\r"; exp_continue }
    -re {[#\$] } {}
    timeout { exit 1 }
}

# Create a lightweight backup of important paths only
send "mkdir -p /tmp/xkali-bak && tar czf /tmp/xkali-bak/sec-backup.tar.gz \
  --exclude='*/node_modules' \
  --exclude='*/.git' \
  --exclude='*/__pycache__' \
  -C /sec \
  bots config xkali-shell 2>/dev/null || \
  tar czf /tmp/xkali-bak/sec-backup.tar.gz -C /sec . 2>/dev/null || true\r"
expect -re {[#\$] }

send "ls -lh /tmp/xkali-bak/sec-backup.tar.gz 2>/dev/null || echo NO_BACKUP\r"
expect -re {[#\$] }

send "exit\r"
expect eof
EOF

chmod +x "$EXPECT_PULL"
expect -f "$EXPECT_PULL" "$SECRET" "$HOST" "$PASSWORD" || true
rm -f "$EXPECT_PULL"

# Now scp the archive
echo "[*] Downloading backup archive..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o "SetEnv SECRET=$SECRET" \
    "root@${HOST}:/tmp/xkali-bak/sec-backup.tar.gz" \
    "$LOCAL_BACKUP/sec-backup.tar.gz" 2>/dev/null || {
  echo "[!] Could not download backup (session may be down or path missing)"
  exit 0
}

if [[ ! -f "$LOCAL_BACKUP/sec-backup.tar.gz" ]]; then
  echo "[!] No backup file received"
  exit 0
fi

echo "[*] Extracting and committing..."
mkdir -p "$BACKUP_DIR"
tar xzf "$LOCAL_BACKUP/sec-backup.tar.gz" -C "$BACKUP_DIR" 2>/dev/null || true

# Only commit if there is real content
if [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
  echo "[*] Empty backup – skipping commit"
  rm -rf "$LOCAL_BACKUP" "$BACKUP_DIR"
  exit 0
fi

git config user.name "xkali-reviver[bot]"
git config user.email "reviver@users.noreply.github.com"

# Move extracted content into a dated folder under backups/
mkdir -p backups
rm -rf "backups/$BACKUP_DIR"
mv "$BACKUP_DIR" "backups/"

git add backups/
if git diff --staged --quiet; then
  echo "[*] No changes to commit"
else
  git commit -m "chore: auto-backup from segfault /sec ($BACKUP_DIR)"
  git push origin HEAD || echo "[!] push failed (check token permissions)"
fi

rm -rf "$LOCAL_BACKUP"
echo "[+] backup-and-push finished"
