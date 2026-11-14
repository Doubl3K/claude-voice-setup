#!/usr/bin/env bash
# Stop hook: read Claude's last reply aloud with Piper (local neural TTS) played via Windows audio.
# Voice: Jenny, pitched down 200 cents (soxfx = sox under another name so the recorder check below ignores it).
# Speech is cut off when voice dictation starts recording (sox/rec appears) or a newer reply begins.
# shortcut: markdown stripping is crude (code blocks dropped, symbols removed), upgrade if reads sound odd.
# shortcut: "talk key pressed" is detected as a running rec/sox process; upgrade if Claude Code changes its recorder.
P="$HOME/.local/share/piper"
pidfile="$HOME/.claude/speak.pid"
[ -f "$pidfile" ] && kill -- "-$(cat "$pidfile")" 2>/dev/null

text=$(python3 -I -c '
import sys, json, re
d = json.load(sys.stdin)
m = d.get("last_assistant_message") or ""
if not m:
    try:
        for l in open(d.get("transcript_path", "")):
            e = json.loads(l)
            if e.get("type") == "assistant":
                t = "".join(c.get("text", "") for c in e["message"]["content"] if c.get("type") == "text")
                if t: m = t
    except Exception: pass
m = re.sub(r"```.*?```", " code omitted. ", m, flags=re.S)
m = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", m)
m = re.sub(r"[`#*_>|]", "", m)
sys.stdout.write(re.sub(r"\s+", " ", m))
')
[ -z "$text" ] && exit 0

# Play through Windows' own audio stack: WSLg's PulseAudio (sox play) dropped audio in places.
wintemp=$(cd /mnt/c && wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")
wav=$(mktemp --tmpdir="$wintemp" speak.XXXXXX.wav)
printf '%s' "$text" | setsid bash -c '"$1/venv/bin/python" -m piper -m "$1/en_GB-jenny_dioco-medium.onnx" --length-scale 1.0 --sentence-silence 0.45 -f "$2.in" >/dev/null 2>&1 && "$1/soxfx" "$2.in" "$2" gain -3 pitch -200 >/dev/null 2>&1 && "$HOME/.claude/play-wav.sh" "$2" >/dev/null 2>&1; rm -f "$2" "$2.in"' _ "$P" "$wav" &
ps=$!
echo "$ps" > "$pidfile"

# Only a recorder that starts after speech began counts: one still shutting down from the tap that sent
# the prompt would otherwise cancel a fast reply before it is heard.
armed=
while kill -0 "$ps" 2>/dev/null; do
  if pgrep -x 'rec|sox' >/dev/null; then
    [ -n "$armed" ] && { kill -- "-$ps" 2>/dev/null; break; }
  else
    armed=1
  fi
  sleep 0.1
done
rm -f "$wav" "$wav.in"  # also covers jobs killed by a newer reply, which never reach their own rm
exit 0
