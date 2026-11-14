#!/usr/bin/env python3
"""Merge the voice setup into ~/.claude/settings.json and keybindings.json without touching anything else.
Safe to run repeatedly."""
import json, os

C = os.path.expanduser("~/.claude")

def load(name, default):
    try:
        with open(os.path.join(C, name)) as f:
            return json.load(f)
    except FileNotFoundError:
        return default

def save(name, data):
    os.makedirs(C, exist_ok=True)
    with open(os.path.join(C, name), "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

def add_hook(hooks, event, hook):
    groups = hooks.setdefault(event, [])
    if not any(h.get("command") == hook["command"] for g in groups for h in g.get("hooks", [])):
        if groups:
            groups[0].setdefault("hooks", []).append(hook)
        else:
            groups.append({"hooks": [hook]})

s = load("settings.json", {})
s["voice"] = {**s.get("voice", {}), "enabled": True, "mode": "tap"}
s["voiceEnabled"] = True
s["statusLine"] = {"type": "command", "command": "python3 ~/.claude/statusline.py", "refreshInterval": 1}
h = s.setdefault("hooks", {})
add_hook(h, "UserPromptSubmit", {"type": "command", "command": "touch ~/.claude/busy"})
add_hook(h, "Stop", {"type": "command", "command": "rm -f ~/.claude/busy"})
add_hook(h, "Stop", {"type": "command", "command": "~/.claude/speak.sh", "async": True, "timeout": 120})
save("settings.json", s)

k = load("keybindings.json", {
    "$schema": "https://www.schemastore.org/claude-code-keybindings.json",
    "$docs": "https://code.claude.com/docs/en/keybindings",
    "bindings": [],
})
chat = next((b for b in k["bindings"] if b.get("context") == "Chat"), None)
if chat is None:
    chat = {"context": "Chat", "bindings": {}}
    k["bindings"].append(chat)
chat["bindings"].update({"space": None, "f9": "voice:pushToTalk"})
save("keybindings.json", k)
print("settings.json and keybindings.json updated")
