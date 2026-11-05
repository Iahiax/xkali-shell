# xkali-shell

External Auto-Reviver for **segfault.net** (Kali-based disposable root servers).

This project keeps a session on `lsd.segfault.net` alive using external CI (GitHub Actions preferred, AppVeyor as alternative). It reconnects, bypasses the initial ~60s timer, starts Node.js + Python bots, supervisord, an infinity loop, and backs up `/sec`.

## Security – IMPORTANT

**Never commit the real SECRET to the repository.**

Your SECRET is:
```
aGgvPaHlcdvPBuoHDkAqWYgH
```
Host:
```
lsd.segfault.net
```

Add them only as **encrypted secrets**:

### GitHub Actions
Repository → Settings → Secrets and variables → Actions → New repository secret

| Name              | Value                          |
|-------------------|--------------------------------|
| `SEGFault_SECRET` | `aGgvPaHlcdvPBuoHDkAqWYgH`     |
| `SEGFault_HOST`   | `lsd.segfault.net`             |

### AppVeyor
Project → Settings → Environment → Add variable → check **Encrypt data**

## Structure

```
xkali-shell/
├── .github/workflows/reviver.yml   # Preferred
├── appveyor.yml
├── scripts/
│   ├── connect-and-revive.sh
│   ├── backup-and-push.sh
│   ├── start-services.sh
│   └── install-deps.sh
├── bots/
│   ├── node-bot/          ← ضع بوت Node.js هنا
│   └── python-bot/        ← ضع بوت Python هنا
├── config/
│   ├── supervisord.conf
│   └── sf-keeper.sh
├── tmux-sessions/
│   └── start-tmux.sh
└── README.md
```

## What is still missing (you must complete)

1. **Your real bots**
   - Replace `bots/node-bot/index.js` + `package.json` with your Node bot
   - Replace `bots/python-bot/main.py` + `requirements.txt` with your Python bot

2. **sf-keeper**
   - `config/sf-keeper.sh` is only a placeholder heartbeat.
   - Put your real sf-keeper tool/script there.

3. **GitHub / AppVeyor secrets** (see table above)

4. **First manual run**
   - Push the repo
   - Go to Actions → External Auto-Reviver → Run workflow
   - Watch the logs. If the timer bypass fails, increase the sleep values in `connect-and-revive.sh`.

5. **Optional improvements**
   - Add a real `rc.local` under `/sec/usr/etc/rc.local` so services start even without the external reviver
   - Add more robust health checks inside the infinity loop
   - Restrict the backup paths if `/sec` becomes large

## How the timer bypass works

```
connect → password → sleep 2 → Enter → sleep 61 → Enter → start services
```

This matches the behaviour you described for new sessions on segfault.

## License / Warning

Use at your own risk. Continuous external keep-alive may be considered abuse of the free tier. Prefer requesting a TOKEN from THC if you need long-running legitimate work.
