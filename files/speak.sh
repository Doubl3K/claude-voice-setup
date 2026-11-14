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
# Spell out abbreviations: their dot reads as a sentence end ("Mr. <pause> Bennett") and splits chunks.
for a, b in (("Mr", "Mister"), ("Mrs", "Missus"), ("Ms", "Miss"), ("Dr", "Doctor"), ("Prof", "Professor"),
             ("vs", "versus"), ("e.g", "for example"), ("i.e", "that is"), ("etc", "etcetera")):
    m = re.sub(r"\b" + re.escape(a) + r"\.", b, m)
# Chunks of whole sentences with doubling target length (100, 200, 400 chars...): each chunk is synthesized
# while the previous one plays, and is short enough (synthesis ~3x faster than speech) to be ready in time.
t = re.sub(r"\s+", " ", re.sub(r"\s*\n\s*\n\s*", "| ", m)).strip()  # "|" = paragraph break
out, size = [], 100
while t:
    n = next((x.end() for x in re.finditer(r"[.!?][\")]*\|?(?= |$)", t) if x.end() >= size), len(t))
    out.append(t[:n].strip())
    t, size = t[n:].strip(), size * 2
sys.stdout.write("\n".join(out))
')
[ -z "$text" ] && exit 0

# Play through Windows' own audio stack: WSLg's PulseAudio (sox play) dropped audio in places.
wintemp=$(cd /mnt/c && wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")
wav=$(mktemp --tmpdir="$wintemp" speak.XXXXXX.wav)
base="${wav%.wav}"
mapfile -t chunks <<<"$text"
setsid bash -c '
synth() {
  local P=$1 b=$2 k pad files=() parts; IFS="|" read -ra parts <<<"$3"
  local n=${#parts[@]}; [[ $3 == *"|" ]] || n=$((n-1))  # parts [0,n) end a paragraph: they get a longer pause
  for k in "${!parts[@]}"; do
    [[ -z "${parts[k]// /}" ]] && continue
    pad=(); ((k < n)) && pad=(pad 0 0.5)
    printf "%s" "${parts[k]}" | "$P/venv/bin/python" -m piper -m "$P/en_GB-jenny_dioco-medium.onnx" --length-scale 1.0 --sentence-silence 0.45 -f "$b.$k.in" >/dev/null 2>&1 &&
      "$P/soxfx" "$b.$k.in" "$b.$k.p.wav" gain -3 pitch -200 "${pad[@]}" >/dev/null 2>&1 || return
    files+=("$b.$k.p.wav")
  done
  # Written under a temp name and renamed, so the player never sees a half-written file.
  "$P/soxfx" "${files[@]}" "$b.t.wav" "${@:4}" >/dev/null 2>&1 && mv "$b.t.wav" "$b.wav"
}
P=$1; b=$2; shift 2
( i=0; for c; do if ((i == 0)); then synth "$P" "$b.$i" "$c" pad 0.4 0; else synth "$P" "$b.$i" "$c"; fi || exit; i=$((i+1)); done ) \
  & sp=$!
"$HOME/.claude/play-wav.sh" "$b" $# >/dev/null 2>&1
kill $sp 2>/dev/null
rm -f "$b"*' _ "$P" "$base" "${chunks[@]}" &
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
rm -f "$base"* "$wav"  # also covers jobs killed by a newer reply, which never reach their own rm
exit 0
