# Instructions for Claude: installing this voice setup

If the user asks you to install, set up or enable this, follow these steps. See README.md for what it does.

1. Check the platform: this only works on WSL2 with Windows interop. Run `grep -i microsoft /proc/version` and
   `command -v powershell.exe`. If either fails, stop and tell the user it is WSL2-only.
2. Run `./install.sh` from the repo root. It installs Piper and the voice model into `~/.local/share/piper`,
   copies the scripts into `~/.claude/`, and merges the hooks, voice settings and F9 key binding into the user's
   existing `settings.json` and `keybindings.json`. It is safe to re-run.
3. If it needs `sudo` (to install `sox`), you cannot type a password: tell the user to run
   `! sudo apt-get install -y sox libsox-fmt-pulse` in the prompt, then re-run `./install.sh`.
4. Verify without relying on hearing: `echo '{"last_assistant_message":"Voice test."}' | ~/.claude/speak.sh`
   should exit 0 and leave no `speak.*` files in the Windows temp folder.
5. Tell the user to restart Claude Code, then try it: F9 starts dictation, F9 again sends, Esc cancels,
   replies are read aloud. You cannot hear the audio yourself, so ask them to confirm it.

Do not copy the user's own `settings.json` anywhere or overwrite it: only `merge_settings.py` should change it.
An existing `~/.claude/statusline.py` is backed up to `statusline.py.bak` before being replaced; mention this to the user.
