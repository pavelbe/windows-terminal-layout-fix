# Menu candidate — 2026-11-03

Local portable build `WT-Layout-Fix-1.25.2733.0-lf-menu2` extends the accepted
`rmb3` build with the three prepared menu patches. It is the daily runtime on
this PC and is not published: no archive, manifest or release asset changed.

## Build and package

| Item | Value |
| --- | --- |
| Build run | `20261103-200344-9d9b342ccc144f05999b8fc3632e8d26` |
| Status | `BUILT_AND_TESTED`; Terminal Core tests succeeded |
| Source commit | `dc8ae365847d41f62d1ebca93815bb00959bc12f` plus ten reviewed patches |
| Key source pins | `TerminalPage.cpp` `16bb852f…`, `AppActionHandlers.cpp` `d6ae2b20…` |
| Packager | `build/Package-MenuCandidate2-20261103.ps1` |
| Runtime | `%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.2733.0-lf-menu2\terminal-1.25.2733.0` |
| Shortcut | Desktop **Terminal LF Menu 1.25** |
| Settings | reviewed snapshot, SHA-256 `d662100c4bf90241f2ef2234949fcf91f74cba3a49f1764abe7f15b3fa68317a` |

## What changed

1. `patches/utility-menu-below-separator.patch` — new-tab-menu entries placed
   after the last configured `separator` render below Terminal's own separator,
   next to the settings group.
2. `patches/explorer-profile-opens-folder.patch` — a profile whose command is
   exactly `explorer.exe` opens this Terminal's folder through `ShellExecute`
   from the menu item instead of creating a pane.
3. `patches/explorer-profile-shortcut.patch` — the same behaviour for the
   generated `Terminal.OpenNewTabProfileN` action, so the assigned shortcut
   (Ctrl+Shift+9 for the ninth profile) does not open a tab either.

The reviewed settings therefore use `"commandline": "explorer.exe"` for the
`Explorer: Terminal folder` profile and place it after a `separator` entry in
`newTabMenu`. Without the patches, that commandline would start a pane around a
GUI process and the separator would only add a second divider.

## Acceptance

Owner-confirmed 2026-11-03 in this candidate: the entry sits under the divider,
the menu item and Ctrl+Shift+9 both open the running Terminal's folder, and
neither path flashes an empty pane. The previously accepted `rmb3` behaviours
are unchanged; `layout-fix.3` remains the published archive without these
patches.

## Residual risks

- Tested on this PC only; a clean Windows installation is unverified.
- `rmb3` remains installed as a rollback runtime with its own shortcut
  **Terminal LF RMB3 1.25**; its settings keep the older PowerShell-based
  profile, which still opens a pane.
