#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-api-errors.XXXXXX")"
PORT_FILE="$TMP_DIR/slow-server-port.txt"
SERVER_SCRIPT="$TMP_DIR/slow-server.py"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat > "$SERVER_SCRIPT" <<'PYTHON'
import http.server
import pathlib
import sys
import time

port_file = pathlib.Path(sys.argv[1])

class SlowHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        time.sleep(5)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"choices":[{"message":{"content":"OK"}}]}')

    def log_message(self, format, *args):
        return

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), SlowHandler)
port_file.write_text(str(server.server_port), encoding="utf-8")
server.serve_forever()
PYTHON

python3 "$SERVER_SCRIPT" "$PORT_FILE" &
SERVER_PID=$!

for _ in {1..50}; do
  if [[ -s "$PORT_FILE" ]]; then
    break
  fi
  sleep 0.1
done

if [[ ! -s "$PORT_FILE" ]]; then
  echo "Failed to start local slow HTTP server for timeout acceptance." >&2
  exit 1
fi

PORT="$(cat "$PORT_FILE")"
cd "$ROOT_DIR"

echo "Running ReadyType 1.2 API error-path acceptance."
echo "The invalid-model case uses DEEPSEEK_API_KEY or the saved ReadyType Keychain API key when available."

READYTYPE_RUN_REAL_API_FAILURE_ACCEPTANCE=1 \
READYTYPE_API_TIMEOUT_BASE_URL="http://127.0.0.1:$PORT" \
swift test --filter RealAPIConnectionFailureAcceptanceTests
