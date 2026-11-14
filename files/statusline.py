#!/usr/bin/env python3
import json, sys, os, time, subprocess

try:
    d = json.load(sys.stdin)
except Exception:
    d = {}

def get(obj, *keys):
    for k in keys:
        if not isinstance(obj, dict):
            return None
        obj = obj.get(k)
    return obj

RESET = "\033[0m"
BOLD = "\033[1m"

def rgb(r, g, b):
    return f"\033[38;2;{r};{g};{b}m"

CYAN = rgb(0, 229, 255)
SKY = rgb(130, 200, 255)
ICE = rgb(200, 235, 255)
MUTED = rgb(100, 125, 150)
WARN = rgb(255, 200, 80)
CRIT = rgb(255, 110, 110)

def pct(v):
    if not isinstance(v, (int, float)):
        return f"{MUTED}n/a{RESET}"
    color = CRIT if v >= 85 else WARN if v >= 60 else CYAN
    return f"{color}{BOLD}{round(v)}%{RESET}"

EFFORT_COLORS = {
    "low": rgb(80, 220, 100),
    "medium": rgb(170, 220, 70),
    "high": rgb(255, 210, 60),
    "xhigh": rgb(255, 150, 50),
    "max": rgb(255, 95, 70),
    "ultracode": rgb(255, 40, 70),
}

def label(t):
    return f"{SKY}{t}:{RESET}"

model = get(d, "model", "display_name") or get(d, "model", "id") or "unknown"

effort = get(d, "effort", "level") or get(d, "effort_level")
if isinstance(get(d, "effort"), str):
    effort = d["effort"]
if not effort:
    try:
        with open(os.path.expanduser("~/.claude/settings.json")) as f:
            effort = json.load(f).get("effortLevel")
    except Exception:
        pass
effort = effort or "default"

ctx = get(d, "context_window", "used_percentage")
h5 = get(d, "rate_limits", "five_hour", "used_percentage")
d7 = get(d, "rate_limits", "seven_day", "used_percentage")

def left(secs):
    secs = max(0, int(secs))
    return f"{secs // 3600}h{secs % 3600 // 60:02d}m" if secs >= 3600 else f"{secs // 60}m"

# shortcut: cache age = transcript mtime (last write), TTL assumed 1h; adjust CACHE_TTL if on the 5m tier
CACHE_TTL = 3600
cache = None
try:
    cache = CACHE_TTL - (time.time() - os.path.getmtime(d["transcript_path"]))
except Exception:
    pass
cache_s = f"{MUTED}n/a{RESET}" if cache is None else (f"{CRIT}{BOLD}expired{RESET}" if cache <= 0 else f"{CYAN}{BOLD}{left(cache)}{RESET}")

reset = get(d, "rate_limits", "five_hour", "resets_at")
reset_s = f"{ICE}{BOLD}{left(reset - time.time())}{RESET}" if isinstance(reset, (int, float)) else f"{MUTED}n/a{RESET}"

# speak.sh stores the PID of the running speech job; alive means a reply is being read aloud.
speaking = False
try:
    os.kill(int(open(os.path.expanduser("~/.claude/speak.pid")).read()), 0)
    speaking = True
except Exception:
    pass

# Voice dictation runs sox/rec while recording (soxfx, used for TTS pitch, is a different name on purpose).
recording = subprocess.run(["pgrep", "-x", "rec|sox"], capture_output=True).returncode == 0

# busy flag: set on prompt submit, cleared by the Stop hook.
# shortcut: an interrupted turn never fires Stop, so a flag older than 15 min is ignored; upgrade if this misfires.
busy = False
try:
    busy = time.time() - os.path.getmtime(os.path.expanduser("~/.claude/busy")) < 900
except Exception:
    pass

voice = f"{SKY}TTS{RESET} {MUTED}F9{RESET}"
# shortcut: the status line refreshes at most once a second (refreshInterval min 1), so animation is one frame per second.
frames = None
if recording:
    frames = ["\U0001F3A4  ", " \U0001F3A4 ", "  \U0001F3A4", " \U0001F3A4 "]  # mic sways left to right via padding
elif speaking:
    frames = ["\U0001F508", "\U0001F509", "\U0001F50A"]  # speaker growing louder
elif busy:
    frames = ["\U0001F4AD", "\U0001F914"]  # thought bubble, thinking face
if frames:
    voice += " " + frames[int(time.time()) % len(frames)].rstrip()

sep = f" {MUTED}|{RESET} "
print(sep.join([
    f"{CYAN}{BOLD}{model}{RESET}",
    f"{label('Eff')} {EFFORT_COLORS.get(str(effort).lower(), ICE)}{BOLD}{effort}{RESET}",
    f"{label('ctx')} {pct(ctx)}",
    f"{label('5h')} {pct(h5)} {MUTED}->{RESET} {reset_s}",
    f"{label('7d')} {pct(d7)}",
    f"{label('Cc')} {cache_s}",
    voice,
]))
