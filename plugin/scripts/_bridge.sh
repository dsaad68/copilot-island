#!/usr/bin/env bash
# _bridge.sh — shared logic for hook scripts
# Usage: echo '{"toolName":"bash",...}' | EVENT_TYPE=preToolUse ./_bridge.sh
#
# For preToolUse events, this script sends the payload and waits for a response
# from the app (approve/deny). For all other events, it's fire-and-forget.

SOCKET="/tmp/copilot-island.sock"
LOG="/tmp/copilot-island-hook.log"
INPUT=$(cat)
EVENT_TYPE="${EVENT_TYPE:-unknown}"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
log "hook fired: EVENT=$EVENT_TYPE"

# Use python3 for JSON manipulation (no jq dependency) and socket communication
RESPONSE=$(python3 -c "
import socket, sys, json

LOGF = '/tmp/copilot-island-hook.log'
SOCK = '$SOCKET'
EVT = '$EVENT_TYPE'

def log(msg):
    with open(LOGF, 'a') as f: f.write(f'[py] {msg}\n')

raw = sys.stdin.buffer.read()
try:
    payload = json.loads(raw)
except Exception:
    payload = {}
payload['event'] = EVT
data = json.dumps(payload).encode()

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(300)
try:
    s.connect(SOCK)
    log(f'connected, sending {len(data)}B')
    s.sendall(data)
    s.shutdown(socket.SHUT_WR)
    if EVT == 'preToolUse':
        resp = b''
        while True:
            chunk = s.recv(4096)
            if not chunk: break
            resp += chunk
        decoded = resp.decode('utf-8', errors='replace')
        log(f'response: {decoded}')
        sys.stdout.write(decoded)
        sys.stdout.flush()
    else:
        log('fire-and-forget sent')
except Exception as e:
    log(f'error: {e}')
finally:
    s.close()
" <<< "$INPUT" 2>/dev/null)

if [ "$EVENT_TYPE" = "preToolUse" ]; then
    if [ -n "$RESPONSE" ]; then
        DECISION=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('permissionDecision', ''))
except: pass
" <<< "$RESPONSE")
        log "decision=$DECISION"
        if [ "$DECISION" = "deny" ]; then
            REASON=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('permissionDecisionReason', 'Denied by user'))
except: print('Denied by user')
" <<< "$RESPONSE")
            echo "{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$REASON\"}"
            exit 0
        fi
    else
        log "no response from app"
    fi
    log "allowing (explicit)"
    echo '{"permissionDecision":"allow"}'
fi

exit 0
