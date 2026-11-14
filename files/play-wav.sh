#!/usr/bin/env bash
# Play chunk files "$1.0.wav" .. "$1.<n-1>.wav" ($2 = n) back to back through Windows audio, in ONE PowerShell
# (starting one per chunk cost seconds of silence), waiting for each file to be synthesized. Escape stops it all.
# shortcut: Escape is polled system-wide, so Esc in any app stops playback; upgrade only if that gets in the way.
# shortcut: duration is read from a 44-byte wav header (what sox writes); upgrade if sox starts adding header chunks.
echo $$ > "$HOME/.claude/speak.pid"  # tells the status line a reply is being read aloud
base=$(wslpath -w "$1")
powershell.exe -NoProfile -Command "
Add-Type -Namespace K -Name U -MemberDefinition '[DllImport(\"user32.dll\")] public static extern short GetAsyncKeyState(int k);'
\$null = [K.U]::GetAsyncKeyState(27)
for (\$i = 0; \$i -lt $2; \$i++) {
  \$f = '$base.' + \$i + '.wav'
  \$w = [Diagnostics.Stopwatch]::StartNew()
  while (-not (Test-Path \$f)) {
    if (\$w.Elapsed.TotalSeconds -gt 60 -or ([K.U]::GetAsyncKeyState(27) -band 0x8000)) { exit 1 }
    Start-Sleep -Milliseconds 20
  }
  \$b = [IO.File]::ReadAllBytes(\$f)
  \$dur = (\$b.Length - 44) / [BitConverter]::ToInt32(\$b, 28)
  \$p = New-Object Media.SoundPlayer \$f
  \$p.Load()  # load fully first so Play() starts at once
  \$p.Play()
  \$t = [Diagnostics.Stopwatch]::StartNew()
  while (\$t.Elapsed.TotalSeconds -lt \$dur + 0.05) {
    if ([K.U]::GetAsyncKeyState(27) -band 0x8000) { \$p.Stop(); exit 1 }
    Start-Sleep -Milliseconds 20
  }
}
"
