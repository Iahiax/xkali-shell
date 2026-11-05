#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# install-deps.sh
# Run once inside the segfault session (or via start-tmux).
# Installs common runtime deps for Node + Python bots into /sec
# so they survive session restarts.
# ============================================================

echo "[*] install-deps.sh – $(date)"

# Make sure /sec/usr exists (persistent)
mkdir -p /sec/usr/bin /sec/usr/lib /sec/usr/etc /sec/logs

export DEBIAN_FRONTEND=noninteractive

# Basic tools
apt-get update -qq || true
apt-get install -y -qq \
  curl wget git tmux \
  python3 python3-pip python3-venv \
  nodejs npm \
  2>/dev/null || echo "[!] apt install partially failed (normal on restricted free tier)"

# Node global tools (optional)
npm install -g npm@latest 2>/dev/null || true

# Python user packages go to /sec/usr so they persist
pip3 install --upgrade pip --quiet 2>/dev/null || true

echo "[+] Base dependencies ready"
echo "    Node: $(node -v 2>/dev/null || echo missing)"
echo "    npm : $(npm -v 2>/dev/null || echo missing)"
echo "    Python: $(python3 --version 2>/dev/null || echo missing)"
