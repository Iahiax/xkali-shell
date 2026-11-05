#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# backup-and-push.sh  (اقتراح 4)
# - نسخ احتياطي خفيف مع استثناءات
# - رفع إلى مجلد backups/ بتاريخ
# - يمكن لاحقاً تحويله إلى فرع منفصل
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="${SCRIPT_DIR}/../config/secrets.env"

if [[ -f "$SECRETS_FILE" ]]; then
  source "$SECRETS_FILE"
  echo "[*] Loaded secrets from config/secrets.env"
fi

SECRET="${SEGFault_SECRET:-}"
HOST="${SEGFault_HOST:-lsd.segfault.net}"
PASSWORD="segfault"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="backup-${TIMESTAMP}"
LOCAL_TMP="./.backup-tmp"

if [[ -z "$SECRET" ]]; then
  echo "[!] SEGFault_SECRET missing"
  exit 1
fi

mkdir -p "$LOCAL_TMP" backups

echo "[*] Creating remote lightweight archive..."

EXPECT_PULL=$(mktemp)
cat > "$EXPECT_PULL" << 'EXPECT_EOF'
#!/usr/bin/expect -f
set timeout 180
set secret [lindex $argv 0]
set host  [lindex $argv 1]
set pass  [lindex $argv 2]

spawn ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null \
          -o "SetEnv SECRET=$secret" root@$host

expect {
    -re "(?i)password:" { send "$pass\r"; exp_continue }
    -re {[#\$] } {}
    timeout { exit 1 }
}

# أرشيف خفيف مع استثناءات (اقتراح 4)
send "mkdir -p /tmp/xkali-bak && tar czf /tmp/xkali-bak/sec-backup.tar.gz \
  --exclude='*/node_modules' \
  --exclude='*/.git' \
  --exclude='*/__pycache__' \
  --exclude='*/.cache' \
  --exclude='*/venv' \
  --exclude='*/.venv' \
  --exclude='*.log' \
  -C /sec \
  bots config xkali-shell logs 2>/dev/null || \
  tar czf /tmp/xkali-bak/sec-backup.tar.gz \
  --exclude='*/node_modules' --exclude='*/.git' --exclude='*/__pycache__' \
  -C /sec . 2>/dev/null || true\r"
expect -re {[#\$] }

send "ls -lh /tmp/xkali-bak/sec-backup.tar.gz 2>/dev/null || echo NO_BACKUP\r"
expect -re {[#\$] }

send "exit\r"
expect eof
EXPECT_EOF

chmod +x "$EXPECT_PULL"
expect -f "$EXPECT_PULL" "$SECRET" "$HOST" "$PASSWORD" || true
rm -f "$EXPECT_PULL"

echo "[*] Downloading archive..."
scp -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null \
    -o "SetEnv SECRET=$SECRET" \
    "root@${HOST}:/tmp/xkali-bak/sec-backup.tar.gz" \
    "$LOCAL_TMP/sec-backup.tar.gz" 2>/dev/null || {
  echo "[!] Could not download backup"
  exit 0
}

if [[ ! -f "$LOCAL_TMP/sec-backup.tar.gz" ]]; then
  echo "[!] No backup file"
  exit 0
fi

echo "[*] Extracting..."
mkdir -p "backups/${BACKUP_NAME}"
tar xzf "$LOCAL_TMP/sec-backup.tar.gz" -C "backups/${BACKUP_NAME}" 2>/dev/null || true

if [[ -z "$(ls -A "backups/${BACKUP_NAME}" 2>/dev/null)" ]]; then
  echo "[*] Empty backup – skipping"
  rm -rf "$LOCAL_TMP" "backups/${BACKUP_NAME}"
  exit 0
fi

# احتفظ بآخر 7 نسخ فقط
ls -1d backups/backup-* 2>/dev/null | sort -r | tail -n +8 | xargs -r rm -rf

git config user.name "xkali-reviver[bot]" 2>/dev/null || true
git config user.email "reviver@users.noreply.github.com" 2>/dev/null || true

git add backups/
if git diff --staged --quiet 2>/dev/null; then
  echo "[*] No changes to commit"
else
  git commit -m "chore: auto-backup ${BACKUP_NAME}" || true
  # يمكن لاحقاً: git push origin HEAD:refs/heads/backup/${TIMESTAMP}
  git push origin HEAD || echo "[!] push failed"
fi

rm -rf "$LOCAL_TMP"
echo "[+] backup-and-push finished → backups/${BACKUP_NAME}"
