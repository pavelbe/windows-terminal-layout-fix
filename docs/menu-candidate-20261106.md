# Menu candidate — 2026-11-06

Local portable build `WT-Layout-Fix-1.25.2733.0-lf-menu3` extends the accepted
`rmb3` build with the three menu patches, now generalized to named Explorer
targets, and a second utility profile. It is the daily runtime on this PC and is
not published: no archive, manifest or release asset changed.

## Build and package

| Item | Value |
| --- | --- |
| Build run | `20261106-103811-8e8f457559b14bdd89e2c81afc62aa4a` |
| Status | `BUILT_AND_TESTED`; Terminal Core tests succeeded |
| Source commit | `dc8ae365847d41f62d1ebca93815bb00959bc12f` plus ten reviewed patches |
| Key source pins | `TerminalPage.cpp` `d8933602…`, `AppActionHandlers.cpp` `c333c489…` |
| Packager | `build/Package-MenuCandidate3-20261106.ps1` |
| Runtime | `%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.2733.0-lf-menu3\terminal-1.25.2733.0` |
| Shortcut | Desktop **Terminal LF Menu 1.25** (retargeted) |
| Settings | reviewed snapshot, SHA-256 `94089b4422f452f73112ffa767aa4a96df7d874a426f198405187df435ed62af` |

## What changed

1. `patches/utility-menu-below-separator.patch` — unchanged; new-tab-menu
   entries placed after the last configured `separator` render below Terminal's
   own separator, next to the settings group.
2. `patches/explorer-profile-opens-folder.patch` — a profile whose command
   starts with `explorer.exe` opens a folder through `ShellExecute` from the
   menu item instead of creating a pane. Without an argument it opens this
   Terminal's folder; a following argument opens that target, for example
   `shell:MyComputerFolder`.
3. `patches/explorer-profile-shortcut.patch` — the same behaviour for the
   generated `Terminal.OpenNewTabProfileN` action, so the assigned shortcut does
   not open a tab either.

The reviewed settings add `Explorer: This PC` with `"commandline":
"explorer.exe shell:MyComputerFolder"` after `Explorer: Terminal folder`, both
below the `separator` entry. Default bindings cover profile indexes 0–8 only, so
the terminal-folder profile keeps Ctrl+Shift+9 through
`Terminal.OpenNewTabProfile8`, while index 9 is bound explicitly with
`Terminal.OpenNewTabProfile9` in `actions` and `keybindings`.

## Acceptance

Owner-confirmed 2026-11-06 in this candidate: both entries sit under the divider;
clicking `Explorer: This PC` and pressing Alt+0 open This PC without a pane;
Ctrl+Shift+9 still opens the running Terminal's folder without a flash. The same
owner check found that `Ctrl+Shift+0` and `Ctrl+Alt+0` never reach the window on
this PC, so Alt+0 is the accepted chord and any future change needs a manual
check. `layout-fix.3` remains the published archive without these patches.

## Residual risks

- The Alt+0 binding targets profile index 9. Reordering, hiding or removing a
  visible profile moves the index, so the chord follows whatever profile sits
  at index 9; recheck after profile-list changes.
- Tested on this PC only; a clean Windows installation is unverified.
- `rmb3` remains installed as a rollback runtime with its own shortcut
  **Terminal LF RMB3 1.25**; its settings keep the older PowerShell-based
  profile, which still opens a pane.
