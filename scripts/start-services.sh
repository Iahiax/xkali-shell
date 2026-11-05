# تثبيت المتطلبات مرة واحدة في /sec
[ -f /sec/bots/node-bot/package.json ] && (cd /sec/bots/node-bot && npm install --production)
[ -f /sec/bots/python-bot/requirements.txt ] && pip3 install -r /sec/bots/python-bot/requirements.txt --target /sec/usr

# tmux sessions
tmux new-session -d -s bots
tmux send-keys -t bots "cd /sec && ./scripts/start-services.sh" Enter
tmux new-session -d -s keeper "sf-keeper &"   # أو المسار الصحيح
