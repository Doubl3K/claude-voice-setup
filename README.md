# Claude Code voice setup (WSL2)

Talk to Claude Code and have its final replies read aloud, all locally except Claude Code's own dictation.

- **Reply voice:** Piper (local neural TTS), British female voice "Jenny", pitched down 2 semitones, played through Windows audio.
- **Talking:** tap F9 to start dictation, tap again to send, Esc cancels.
- **Interrupting:** the voice stops when you start dictating (F9) or press Escape.
- **Status line:** `TTS F9` plus an animated icon: mic while recording, thinking while Claude works, speaker while it speaks.

## Install

```bash
git clone <this repo> && cd claude-voice-setup
./install.sh
```

Needs WSL2 with Windows interop (`powershell.exe`), python3, and sudo once for `sox` if it's missing.
It installs Piper into `~/.local/share/piper`, copies the scripts into `~/.claude/`, and merges the hooks, voice
settings and key binding into your existing `settings.json` and `keybindings.json` without removing anything.
An existing `statusline.py` is backed up to `statusline.py.bak` and replaced. Re-running is safe.

## How it works

It is built for WSL2 because Claude Code runs in Linux while the speakers and microphone belong to Windows.

1. **Speaking back:** a Claude Code `Stop` hook runs `speak.sh` after every final reply. It strips markdown, has
   Piper (running in Linux) turn the text into a wav file, lowers the pitch with sox, and hands the file to
   `play-wav.sh`, which plays it through Windows' own audio via `powershell.exe`. Playing through Windows avoids
   dropouts that WSLg's Linux audio had.
2. **Interrupting:** while playing, `speak.sh` watches for the dictation recorder (`rec`/`sox`) starting, and
   `play-wav.sh` watches the Escape key. Either one stops the voice. The pitch tool is a copy of sox named
   `soxfx` so it isn't mistaken for the recorder.
3. **Talking:** Claude Code's own voice dictation, set to tap mode on F9 in `keybindings.json`.
4. **Status line:** `statusline.py` shows a mic while the recorder runs, a thinking icon while Claude works
   (a `UserPromptSubmit` hook sets a `busy` flag that the `Stop` hook clears), and a speaker while `speak.sh` is
   playing. It refreshes once a second, so animation is one frame per second.

## Tweaks

- Voice speed and pauses: `--length-scale` and `--sentence-silence` in `files/speak.sh`.
- Pitch: `pitch -200` (cents) in `files/speak.sh`.
- Other voices: any model from https://huggingface.co/rhasspy/piper-voices, change `MODEL`/`URL` in `install.sh` and the model name in `files/speak.sh`.
- Talk key: `f9` in `merge_settings.py` (F13 and above did not reach Claude Code in Windows Terminal).

## Known limits

- Escape is read system-wide while a reply plays, so Esc in any window stops it.
- "Talk key pressed" is detected as a running `rec`/`sox` process; if Claude Code changes its recorder, the cut-off stops working.
- Tap mode always sends on the second tap (three words or more); Esc instead cancels it.
