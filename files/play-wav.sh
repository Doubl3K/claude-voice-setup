#!/usr/bin/env bash
# Play a wav through Windows audio and stop early when Escape is pressed (global key state, any window).
# shortcut: Escape is polled system-wide, so Esc in any app stops playback; upgrade only if that gets in the way.
wav="$1"
dur=$("$HOME/.local/share/piper/soxfx" --i -D "$wav") || exit 1
w=$(wslpath -w "$wav")
powershell.exe -NoProfile -Command "
Add-Type -Namespace K -Name U -MemberDefinition '[DllImport(\"user32.dll\")] public static extern short GetAsyncKeyState(int k);'
\$null = [K.U]::GetAsyncKeyState(27)
\$p = New-Object Media.SoundPlayer '$w'
\$p.Play()
\$t = [Diagnostics.Stopwatch]::StartNew()
while (\$t.Elapsed.TotalSeconds -lt ($dur + 0.3)) {
  if ([K.U]::GetAsyncKeyState(27) -band 0x8000) { \$p.Stop(); break }
  Start-Sleep -Milliseconds 40
}
"
