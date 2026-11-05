# xkali-shell

External Auto-Reviver for segfault.net sessions.

This project keeps a segfault.net shell session alive using external CI (GitHub Actions / AppVeyor), automatically reconnects, bypasses the initial 60s timer, runs Node.js + Python bots, supervisord, infinity loop, and backs up `/sec` content.

## Important Notes

- segfault.net free tier has limits (≈36h with active shell, shorter without).
- Continuous external automation may be considered abuse. Use responsibly.
- Always store your `SECRET` as an encrypted secret in GitHub / AppVeyor.
- Data under `/sec` is persistent across reconnects when using the same SECRET.

## Structure

```
xkali-shell/
├── .github/workflows/reviver.yml   # Preferred (GitHub Actions)
├── appveyor.yml                    # Alternative
├── scripts/
│   ├── connect-and-revive.sh
│   ├── backup-and-push.sh
│   ├── start-services.sh
│   └── install-deps.sh
├── bots/
│   ├── node-bot/                   # Place your Node.js bot here
│   └── python-bot/                 # Place your Python bot here
├── config/
│   ├── supervisord.conf
│   └── sf-keeper.sh                # Placeholder for custom sf-keeper
├── tmux-sessions/
│   └── start-tmux.sh
└── README.md
```

## Setup

1. Fork / clone this repository.
2. Add repository secrets:
   - `SEGFault_SECRET` → your segfault SECRET
   - `SEGFault_HOST` → e.g. `us.segfault.net` or the hostname shown on login
   - `GH_TOKEN` (optional) → for pushing backups (or use GITHUB_TOKEN)
3. Place your bots inside `bots/node-bot/` and/or `bots/python-bot/`.
4. Enable the GitHub Actions workflow (or AppVeyor).
5. Run the workflow manually the first time to capture the SECRET if needed.

## How it works

- The reviver connects via SSH using the SECRET.
- Bypasses the initial boot timer (wait 2s → Enter → wait 61s → Enter).
- Starts tmux sessions, supervisord, infinity loop, and bots.
- Periodically backs up `/sec` and pushes to the repository.

## License

Use at your own risk.
