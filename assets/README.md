# Layout Fix icon

`terminal-lf.png` is the original generated artwork: a dark terminal with a teal
LF badge. `terminal-lf.ico` contains transparent 32-bit PNG frames at 16, 20, 24,
32, 40, 48, 64, 128 and 256 pixels. ICO SHA-256:
`421af3d08b1377bb391a08bd7dc285a69cae3b4217d4febf6a8a35af37bf0979`.

To regenerate, copy the PNG and `build/New-LayoutFixIcon.ps1` to a local Windows
directory, then run PowerShell 7. The output must not exist:

```powershell
.\New-LayoutFixIcon.ps1 -SourcePng .\terminal-lf.png -OutputIco .\terminal-lf-new.ico
```

Compare the result before replacing the reviewed asset. The generator never
overwrites an output; if a write fails, retain the partial file and choose a
fresh destination. The icon directory and PNG dimensions were independently
checked, and native `LoadImageW` loaded all nine sizes. Use that Windows API
when verifying the 256px frame: the .NET Icon size constructor selected a
smaller frame in our check despite successful native loading.

For the pinned Stable source, overlay only `res/terminal.ico` after preserving
the upstream asset. The build recipe checks its exact hash along with the ten
existing patch files. Keep the four source patches unchanged. Release
`WindowsTerminal.rc` embeds this resource; `icon.cpp` loads it for window icons,
including after theme changes. High-contrast resources remain upstream.

Package into a fresh `-lf` candidate directory. A shortcut should target that
exact `WindowsTerminal.exe` and use the same EXE as `IconLocation`, index 0.
Do not set an unrelated shortcut-only AppUserModelID, replace a running EXE,
restart Explorer, clear the icon cache, or copy live session state for branding.
Existing processes retain their loaded icon until the owner closes them.

Use `build/New-PortableShortcut.ps1` with explicit `-TerminalExe` and
`-ShortcutPath` paths. It requires the adjacent `.portable` marker, creates a
new `.lnk` without overwriting an existing path, and verifies the saved target,
icon and empty arguments. It neither launches nor pins the application.
After copying the helper to a local Windows folder, for this candidate:

```powershell
.\New-PortableShortcut.ps1 -TerminalExe "$env:LOCALAPPDATA\Programs\WT-Layout-Fix-1.25.2733.0-lf\terminal-1.25.2733.0\WindowsTerminal.exe" -ShortcutPath (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Terminal LF 1.25.lnk')
```

For taskbar use, open this shortcut and pin that running window manually;
an older pinned shortcut continues to select its old executable.

The 2026-10-27 LF candidate passed an embedded-resource comparison for all nine
frames and a live `WM_GETICON` pixel comparison at 16px and 32px. The new blank
window rendered successfully. These checks establish executable/window branding;
taskbar grouping and owner visual acceptance remain separate checks. Exact
artifacts and the live receipt are in the [dated record](../docs/upgrade-20261026.md).
