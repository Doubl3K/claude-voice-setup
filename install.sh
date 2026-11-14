#!/usr/bin/env bash
# Installs the Claude Code voice setup on WSL2: local Piper TTS reply voice, tap-to-talk on F9,
# Escape / talk-key interruption and a status-line indicator. Safe to re-run.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
P="$HOME/.local/share/piper"
C="$HOME/.claude"
MODEL=en_GB-jenny_dioco-medium
URL=https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/jenny_dioco/medium

grep -qi microsoft /proc/version || { echo "This setup needs WSL2 (it plays audio through Windows)."; exit 1; }
command -v powershell.exe >/dev/null || { echo "powershell.exe not found: enable WSL interop."; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required."; exit 1; }

# sox: used by Claude Code's dictation recorder and for the pitch shift; libsox-fmt-pulse lets it record under WSLg.
if ! command -v sox >/dev/null; then
  echo "Installing sox (needs sudo)..."
  sudo apt-get install -y sox libsox-fmt-pulse
fi
command -v curl >/dev/null || sudo apt-get install -y curl

mkdir -p "$P" "$C"
if [ ! -x "$P/venv/bin/python" ]; then
  if ! python3 -m venv "$P/venv" 2>/dev/null; then
    # shortcut: python3-venv missing, bootstrap pip by hand; upgrade by installing python3-venv.
    rm -rf "$P/venv"; python3 -m venv --without-pip "$P/venv"
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$P/get-pip.py"
    "$P/venv/bin/python" "$P/get-pip.py" -q
  fi
fi
"$P/venv/bin/python" -c "import piper" 2>/dev/null || "$P/venv/bin/pip" install -q piper-tts

for f in "$MODEL.onnx" "$MODEL.onnx.json"; do
  [ -f "$P/$f" ] || curl -fsSL -o "$P/$f" "$URL/$f"
done
# Same sox under another name, so the "is the talk recorder running?" check ignores our own pitch shifting.
ln -sf "$(command -v sox)" "$P/soxfx"

install -m 755 "$here/files/speak.sh" "$here/files/play-wav.sh" "$C/"
[ -f "$C/statusline.py" ] && ! cmp -s "$here/files/statusline.py" "$C/statusline.py" && cp "$C/statusline.py" "$C/statusline.py.bak"
install -m 644 "$here/files/statusline.py" "$C/statusline.py"

python3 "$here/merge_settings.py"
echo "Done. Restart Claude Code. F9 starts/stops dictation, Esc cancels, replies are read aloud."
