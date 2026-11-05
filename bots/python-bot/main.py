#!/usr/bin/env python3
# ============================================================
# Placeholder Python bot
# Replace this file with your real bot code.
# The reviver will start it automatically if main.py exists.
# ============================================================

import time
import datetime
import sys

def main():
    print(f"[python-bot] started at {datetime.datetime.utcnow().isoformat()}Z", flush=True)

    try:
        while True:
            print(f"[python-bot] heartbeat {datetime.datetime.utcnow().isoformat()}Z", flush=True)
            time.sleep(60)
    except KeyboardInterrupt:
        print("[python-bot] shutting down", flush=True)
        sys.exit(0)

if __name__ == "__main__":
    main()
