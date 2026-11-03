---
name: windows-desktop-open
version: 1.1.1
description: Show a folder or file from this project on the Windows desktop - Explorer window, file selection, or a short open-in-Notepad++ request; includes the verified cmd-start recipe and the Explorer Home failure mode.
---

# Open paths on the Windows desktop

Use when the owner asks to show a folder in Explorer or to open an existing file
in Notepad++ from a WSL session on this host.

## Before launching

- Resolve the real path and confirm it exists (`ls` on `/mnt/c/...` or the WSL
  path).
- For a Terminal build folder, first distinguish the running runtime from a
  prepared candidate or published archive. Read [the current runtime record](../../../README.md)
  and its linked candidate record; verify the exact EXE/shortcut target. A folder
  name or ProductVersion alone does not identify which build is running.
- On this host a direct Windows executable call can fail with `exec format
  error` while `/init <windows-exe>` works. Run Windows commands from `/mnt/c`
  so CMD never receives a WSL UNC working directory.
- A successful launch request proves only that Windows accepted it. Do not
  report "opened" without owner confirmation or window evidence.

## Open the Terminal build's own folder

In a build carrying the three menu patches, the new-tab menu has
`Explorer: Terminal folder` under the divider, and its generated shortcut
(Ctrl+Shift+9) opens the folder of the running Terminal without creating a
pane. The owner accepted this in `lf-menu2`; check README for the build in use.
On an unpatched build the same profile opens a pane around `explorer.exe`. For an
arbitrary folder or an older build, use the Explorer recipe below.

## Open a folder in Explorer

```sh
cd /mnt/c && /init /mnt/c/Windows/System32/cmd.exe /c start "" "C:\path\to\folder"
```

- Verified 2026-11-03: this opened the requested folder.
- `explorer.exe "C:\path"` opened the Explorer **Home** view instead of the
  target on the same PC. Do not rely on it, and never claim success from its
  exit code.
- Open the deepest useful folder (for example the packaged runtime, not its
  parent) and name the exact path in the reply, so a wrong target is obvious.

## Select a file in its folder

```sh
cd /mnt/c && /init /mnt/c/Windows/System32/explorer.exe /select,"C:\path\to\file.zip"
```

Not yet exercised on this host; if it opens the wrong view, open the parent
folder with the `cmd start` recipe above instead.

## Short Notepad++ open

For an existing file when the owner says "open in Notepad++" — not for command
delivery:

```sh
cd /mnt/c && /init "/mnt/c/Program Files/Notepad++/notepad++.exe" -nosession "C:\path\to\file"
```

- Notepad++ lives at `C:\Program Files\Notepad++\notepad++.exe` on this PC.
- For a WSL file pass the UNC form, for example
  `\\wsl.localhost\Ubuntu\home\pavelbe\Projects\file.md`.
- Long or multiline commands meant for pasting still go through
  `~/.claude/skills/notepad-open/SKILL.md`; this short form only opens a file.
- Treat the launch as unverified until the owner confirms the window.

## Version history

- 1.1.1: distinguish running, candidate and archive paths before opening a build folder.
