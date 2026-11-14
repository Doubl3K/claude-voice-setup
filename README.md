# Claude Code voice setup (WSL2)

Talk to Claude Code and have its final replies read aloud, all locally except Claude Code's own dictation.

- **Reply voice:** Piper (local neural TTS), British female voice "Jenny", pitched down 2 semitones, played through Windows audio. German replies are read by the German voice "Thorsten" in high quality (not pitched).
- **Talking:** tap F9 to start dictation, tap again to send, Esc cancels.
- **Interrupting:** the voice stops when you start dictating (F9) or press Escape.
- **Several sessions:** replies from different Claude sessions are read one after another, never over each other. A reply from a session you named (`/rename` or `--name`) starts with that name, so you know which session is speaking; unnamed sessions don't announce anything. A newer reply from the same session replaces its older one. Pressing Escape skips the reply being read; a queued one then starts.
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

1. **Speaking back:** a Claude Code `Stop` hook runs `speak.sh` after every final reply. `speak-text.py` strips markdown,
   picks the language, spells out abbreviations, and splits the text into chunks of whole sentences (about 100 characters, then
   doubling). Piper (running in Linux) turns each chunk into a wav file and sox lowers the pitch, while
   `play-wav.sh` plays the chunks back to back in one `powershell.exe` through Windows' own audio, so the first
   chunk starts quickly and later ones are ready before they are needed. Playing through Windows avoids
   dropouts that WSLg's Linux audio had. Paragraph breaks get an extra half-second pause, and the first chunk
   starts with 0.4 s of silence so the audio device waking up doesn't clip the first words.
2. **Interrupting:** while playing, `speak.sh` watches for the dictation recorder (`rec`/`sox`) starting, and
   `play-wav.sh` watches the Escape key. Either one stops the voice. The pitch tool is a copy of sox named
   `soxfx` so it isn't mistaken for the recorder.
3. **Talking:** Claude Code's own voice dictation, set to tap mode on F9 in `keybindings.json`.
4. **Status line:** `statusline.py` shows a mic while the recorder runs, a thinking icon while Claude works
   (a `UserPromptSubmit` hook sets a `busy` flag that the `Stop` hook clears), and a speaker while `speak.sh` is
   playing. It refreshes once a second, so animation is one frame per second.

## Language

`speak-text.py` picks the voice once per reply (never per chunk, so it can't switch halfway) by counting common
German and English words. German needs clear evidence: at least 3 German hits and twice as many as English ones.
Anything else, including very short or mixed text, gets the English voice. Code blocks don't count. Run the
self-check after touching this: `python3 -m unittest discover tests`.

## Several sessions

- **Queue:** `speak.sh` takes a lock (`flock`) before playing, so replies from different Claude sessions are read one
  after another. Each is already synthesized while it waits, so it starts almost at once when its turn comes.
- **Replacing:** a newer reply from the same session replaces its own older one, whether that one is playing or
  still waiting (a pid file per session id).
- **Who is speaking:** a reply from a session you named (`/rename` or `--name`) starts with that name, e.g.
  "Claude improvements. Done." `speak-text.py` reads it from the session's transcript (the last `custom-title`
  entry). Unnamed sessions, and auto-generated titles, announce nothing. Hyphens and underscores are read as spaces.

## Abbreviations

A dot after an abbreviation reads as a sentence end ("Mr. <pause> Bennett"), so `speak.sh` spells these out first:

English replies:

| Written | Spoken |
|---|---|
| Mr. / Mrs. / Ms. | Mister / Missus / Miss |
| Dr. / Prof. | Doctor / Professor |
| vs. | versus |
| e.g. / i.e. / etc. | for example / that is / etcetera |

German replies: Dr., Prof., Nr., bzw., ca., usw., z. B. and d. h. (as Doktor, Professor, Nummer, beziehungsweise,
circa, und so weiter, zum Beispiel, das heißt).

Others such as "St." (Saint or Street) and "Jr." (Junior) are left alone: telling them apart needs understanding the
context, which would cost tokens and isn't worth it. To add a clear-cut one, extend the list in `files/speak.sh`.

## Tweaks

- Voice speed and pauses: `--length-scale` and `--sentence-silence` in `files/speak.sh`; paragraph pause: `pad 0 0.5`; start silence: `pad 0.4 0`.
- Pitch: `pitch -200` (cents) in `files/speak.sh`.
- Other voices: any model from https://huggingface.co/rhasspy/piper-voices, change the `VOICES` list in `install.sh` and the model names in `files/speak.sh`.
- Talk key: `f9` in `merge_settings.py` (F13 and above did not reach Claude Code in Windows Terminal).

## Known limits

- The status line speaker and the thinking icon are shared by all sessions: either shows in every session while any of them speaks or works. The Stop hook has a 120 s timeout, so after waiting that long in the queue the dictation cut-off no longer works for that reply.
- Only English and German are detected; a reply in another language gets the English voice.
- Escape is read system-wide while a reply plays, so Esc in any window stops it.
- "Talk key pressed" is detected as a running `rec`/`sox` process; if Claude Code changes its recorder, the cut-off stops working.
- Tap mode always sends on the second tap (three words or more); Esc instead cancels it.
