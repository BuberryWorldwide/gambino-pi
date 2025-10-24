#!/bin/bash

SESSION="gambino-monitor"

# Check if session exists, if so attach to it
tmux has-session -t $SESSION 2>/dev/null
if [ $? == 0 ]; then
    echo "Session $SESSION already exists. Attaching..."
    tmux attach -t $SESSION
    exit 0
fi

# Create new session
tmux new-session -d -s $SESSION -n "Logs"

# Split window into 4 panes
tmux split-window -h -t $SESSION:0
tmux split-window -v -t $SESSION:0.0
tmux split-window -v -t $SESSION:0.2

# Pane 0 (top-left): Service logs
tmux send-keys -t $SESSION:0.0 "cd ~/gambino-pi-app && sudo journalctl -u gambino-pi.service -f -o cat" C-m

# Pane 1 (bottom-left): Parsed lines
tmux send-keys -t $SESSION:0.1 "cd ~/gambino-pi-app && tail -f data/serial-logs/lines-2025-10-14.jsonl | grep -o '\"line\":\"[^\"]*\"' | sed 's/\"line\":\"//g' | sed 's/\"\$//g'" C-m

# Pane 2 (top-right): Events created
tmux send-keys -t $SESSION:0.2 "cd ~/gambino-pi-app && tail -f data/serial-logs/events-2025-10-14.jsonl" C-m

# Pane 3 (bottom-right): File sizes
tmux send-keys -t $SESSION:0.3 "cd ~/gambino-pi-app && watch -n 1 'ls -lh data/serial-logs/'" C-m

# Select first pane
tmux select-pane -t $SESSION:0.0

# Attach to session
tmux attach -t $SESSION
