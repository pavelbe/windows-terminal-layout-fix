# Layout Fix icon

## Current square taskbar variant

`terminal-lf-square.ico` reuses the original `terminal-lf.png` artwork. The
owner rejected the wide proportions and chose the square shape with Claude's
full-canvas taskbar sizing. No redraw or color change is included. ICO SHA-256:
`6a0a1ab4c869add88fd38761d945563d35d4836751e2fd38c040a7329b10cade`.

`New-LayoutFixIcon.ps1 -TrimTransparentPadding` measures pixels with alpha >=128
and crops a centered square around the visible artwork, preserving its aspect
ratio. For this source the crop is `(121, 128, 1011, 1011)`. All nine frames
occupy the full canvas; 24px and 32px match the installed Claude taskbar assets'
24x24 and 32x32 bounds. Interior alpha at 32px stays 253-254, as in the original.
The untrimmed default still reproduces the original ICO byte-for-byte.

Measure actual small-frame alpha bounds before deciding an icon is large enough:
a 1254px preview or a square ICO header alone is insufficient. The old Terminal
reference occupies 32x24; the rejected wide LF only about 31x17. Inspect the
interior alpha as well: generated edits introduced transparent holes and were
rejected. The owner explicitly selected deterministic cropping of the original.

The pinned LF shortcut now references `terminal-lf-square-trimmed.ico`, a
byte-identical copy of this square asset, following the owner's size correction.
The prior shortcut was backed up and its target, arguments, working directory,
description, hotkey and window style were verified unchanged. The native
receipt is `Downloads\WT-Square-20261028\pinned-square-receipt.json`. Explorer and running terminals were not restarted. Loaded
window icons can remain old until the owner opens the new executable. Resource
byte parity, live window appearance and taskbar visual acceptance are separate.

## Historical wide taskbar variant

`terminal-lf-wide.png` and `terminal-lf-wide.ico` are the 2026-10-28
owner-requested wide artwork. The icon uses nearly the full canvas width;
Windows still allocates a square icon slot. The existing generator produces
the same nine sizes. ICO SHA-256:
`cc32784f46b47b335fe34d0161ca04e36190de0426f7b91bad5b99ad86dc1996`.

The earlier shortcut-only update assigned this external ICO to the owner's pinned LF shortcut, with its executable,
arguments and working directory preserved and verified. The original shortcut
was backed up privately before modification. A targeted shell update notification
was sent; Explorer and active terminals were not restarted. The owner later rejected its wide proportions. That operation changed only the shortcut;
the old executable retained its original square LF artwork.

The subsequent 2026-10-28 rebuild embeds the wide ICO in a separate
`WT-Layout-Fix-1.25.2733.0-lf-wide` candidate. All nine resource payloads in
the extracted EXE match this ICO; native `LoadImageW` accepts all nine sizes.
It is packaged but not launched, switched into daily routing or publicly
released. See the [artifact record](../docs/upgrade-20261026.md#wide-lf-candidate-2026-10-28).

## Original embedded artwork

`terminal-lf.png` is the original generated artwork: a dark terminal with a teal
LF badge. `terminal-lf.ico` contains transparent 32-bit PNG frames at 16, 20, 24,
32, 40, 48, 64, 128 and 256 pixels. ICO SHA-256:
`421af3d08b1377bb391a08bd7dc285a69cae3b4217d4febf6a8a35af37bf0979`.

To regenerate, copy the PNG and `build/New-LayoutFixIcon.ps1` to a local Windows
directory, then run PowerShell 7. The output must not exist:

```powershell
.\New-LayoutFixIcon.ps1 -SourcePng .\terminal-lf.png -OutputIco .\terminal-lf-square.ico -TrimTransparentPadding
```

Omit `-TrimTransparentPadding` to reproduce the original padded variant.
Compare the result before replacing the reviewed asset. The generator never
overwrites an output; if a write fails, retain the partial file and choose a
fresh destination. The icon directory and PNG dimensions were independently
checked, and native `LoadImageW` loaded all nine sizes. Use that Windows API
when verifying the 256px frame: the .NET Icon size constructor selected a
smaller frame in our check despite successful native loading.

For the current pinned Stable source, overlay `terminal-lf-square.ico` only at
`res/terminal.ico`, after preserving the previous asset. The build recipe checks its exact hash along with the ten
existing patch files. Keep the four source patches unchanged. Release
`WindowsTerminal.rc` embeds this resource; `icon.cpp` loads it for window icons,
including after theme changes. High-contrast resources remain upstream.

Package into a fresh `-lf-square` candidate directory. A shortcut should target that
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
.\New-PortableShortcut.ps1 -TerminalExe "$env:LOCALAPPDATA\Programs\WT-Layout-Fix-1.25.2733.0-lf-square\terminal-1.25.2733.0\WindowsTerminal.exe" -ShortcutPath (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Terminal LF Square 1.25.lnk')
```

For taskbar use, open this shortcut and pin that running window manually;
an older pinned shortcut continues to select its old executable.

The 2026-10-27 LF candidate passed an embedded-resource comparison for all nine
frames and a live `WM_GETICON` pixel comparison at 16px and 32px. The new blank
window rendered successfully. These checks establish executable/window branding;
taskbar grouping and owner visual acceptance remain separate checks. Exact
artifacts and the live receipt are in the [dated record](../docs/upgrade-20261026.md).
