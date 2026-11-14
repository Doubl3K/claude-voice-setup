#!/usr/bin/env bash
# Stop hook: read Claude's last reply aloud with Piper (local neural TTS) played via Windows audio.
# Voice: Jenny (English, pitched down 200 cents) or Thorsten (German), chosen per reply by speak-text.py (soxfx = sox under another name so the recorder check below ignores it).
# Speech is cut off when voice dictation starts recording (sox/rec appears) or a newer reply of the same session begins;
# replies of different sessions wait for each other instead of cutting each other off.
# shortcut: markdown stripping is crude (code blocks dropped, symbols removed), upgrade if reads sound odd.
# shortcut: "talk key pressed" is detected as a running rec/sox process; upgrade if Claude Code changes its recorder.
P="$HOME/.local/share/piper"
out=$(python3 -I "$HOME/.claude/speak-text.py")
[ -z "$out" ] && exit 0
head=${out%%$'\n'*}; text=${out#*$'\n'}; lang=${head% *}; sid=${head#* }
# A newer reply of the same session replaces its older one (speaking or still waiting); other sessions queue.
pidfile="$HOME/.claude/speak.$sid.pid"
[ -f "$pidfile" ] && kill -- "-$(cat "$pidfile")" 2>/dev/null

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
    printf "%s" "${parts[k]}" | "$P/venv/bin/python" -m piper -m "$P/$model.onnx" --length-scale 1.0 --sentence-silence 0.45 -f "$b.$k.in" >/dev/null 2>&1 &&
      "$P/soxfx" "$b.$k.in" "$b.$k.p.wav" "${fx[@]}" "${pad[@]}" >/dev/null 2>&1 || return
    files+=("$b.$k.p.wav")
  done
  # Written under a temp name and renamed, so the player never sees a half-written file.
  "$P/soxfx" "${files[@]}" "$b.t.wav" "${@:4}" >/dev/null 2>&1 && mv "$b.t.wav" "$b.wav"
}
P=$1; b=$2; lang=$3; shift 3
if [ "$lang" = de ]; then model=de_DE-thorsten-high; fx=(gain -3); else model=en_GB-jenny_dioco-medium; fx=(gain -3 pitch -200); fi
( i=0; for c; do if ((i == 0)); then synth "$P" "$b.$i" "$c" pad 0.4 0; else synth "$P" "$b.$i" "$c"; fi || exit; i=$((i+1)); done ) \
  & sp=$!
# One reply plays at a time across sessions (flock); play-wav.sh records its pid in speak.pid for the status line.
flock "$HOME/.claude/speak.lock" "$HOME/.claude/play-wav.sh" "$b" $# >/dev/null 2>&1
kill $sp 2>/dev/null
rm -f "$b"*' _ "$P" "$base" "$lang" "${chunks[@]}" &
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
[ "$(cat "$pidfile" 2>/dev/null)" = "$ps" ] && rm -f "$pidfile"  # never leave a pid that could be reused
rm -f "$base"* "$wav"  # also covers jobs killed by a newer reply, which never reach their own rm
exit 0
