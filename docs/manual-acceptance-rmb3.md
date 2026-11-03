# Manual acceptance — rmb3 candidate (2026-11-03)

Owner-run checklist for `WT-Layout-Fix-1.25.2733.0-lf-rmb3`. It covers the
behaviour the automated build and Terminal Core tests cannot prove: the exit
notice during pane removal, right-button paste ownership, taskbar rendering and
multi-file paste. Record results in the table at the end; a failed check is an
issue with the exact EXE path, Windows version and reproduction.

## Prerequisites

- Launch the accepted runtime through the pinned shortcut **Terminal LF RMB3
  1.25**, not through a Store package or an older recovery folder.
- Keep the repository settings snapshot in sync:
  `build/Test-RuntimeState.sh` must report `RESULT: PASS` for the runtime.
- Do not change `settings/settings.json` during the checks; a settings edit
  invalidates the hash comparison below.

## Checks

1. **Exit notice on pane close** (exit-notice patch).
   Split the window, run a command that exits normally (`exit`), and watch the
   pane leave. The pane must disappear without the informational
   `Process exited with code N` text flashing first. Closing the last pane must
   still follow `closeOnExit`, and a pane killed by a failure must still show
   the same behaviour as before the patch.
2. **Right-button image paste** (right-button patch).
   Copy a screenshot, right-click inside Claude Code, and confirm the image
   attaches as a quoted temporary path. Repeat inside a TUI that tracks the
   mouse (Codex or the same Claude Code session) and confirm the right button
   no longer reaches the application while the left button still does.
3. **Left-button regression guard.**
   In the same mouse-tracking application, click widgets, menu entries and
   selection with the left button. Every control must respond; the rejected
   `-rmb2` variant made them unclickable and must not reappear.
4. **Multi-file paste.**
   Select two or three images in Explorer, paste, and confirm every file
   attaches in order.
5. **Taskbar pin and grouping.**
   Pin the running window and check that it groups under one taskbar icon with
   the 32px LF artwork, not a scaled-down or generic icon. Close and reopen to
   confirm the pin survives.
6. **Settings untouched.**
   Rerun `build/Test-RuntimeState.sh`. The settings hash must still match the
   repository snapshot; the app must not rewrite the file during normal use.

## Results

| # | Check | Result | Notes |
| --- | --- | --- | --- |
| 1 | Exit notice on pane close | PASS | Owner-confirmed 2026-11-03 |
| 2 | Right-button image paste | PASS | Owner-confirmed 2026-11-03 |
| 3 | Left-button regression guard | PASS | Owner-confirmed 2026-11-03 |
| 4 | Multi-file paste | PASS | Owner-confirmed 2026-11-03 |
| 5 | Taskbar pin and grouping | PASS | Owner-confirmed 2026-11-03 |
| 6 | Settings untouched | PASS | Owner-confirmed 2026-11-03 |

The owner reported all six checks passing on 2026-11-03. These results close the
manual acceptance noted in README for the `rmb3` candidate. They do not
by themselves authorize a public release archive: a new archive still needs its
own versioned manifest measured from the packaged bytes and a fresh Windows
smoke of that exact package.
