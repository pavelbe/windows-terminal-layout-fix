# Exit-notice suppression — 2026-11-01

> Historical candidate record. The current accepted runtime is `rmb3`; the
> exit-notice build is a historical, unlaunched pre-right-button fallback; its
> recorded `%LOCALAPPDATA%\Programs` runtime folder is not present on this PC.
> See [README](../README.md) for current status.

## Symptom and measured evidence

In a split layout, typing `exit` closes the pane correctly, but the
`[process exited with code 0 (0x00000000)]` text is visible for a moment before
the pane disappears. The owner described this as an error flash.

Measurements on the diagnostic build (`1.25.2733.0-local-layoutfix-diag1`,
EXE SHA256 `424b8f87…`; see
[connection diagnostics](connection-diagnostics-20261029.md)):

- Isolated portable fixture (UIA, 5 runs): the pane disappeared 46–149 ms after
  the gate released the child process (the child then exits); the notice text was
  never sampled.
- Live owner window (tab with 8 panes, PID 24452, 2026-11-01 01:06 MSK / 22:06 UTC):
  7 successful exits, `connection-events.log` recorded `event=exited code=0` in all
  of them. The TermControl count dropped 0–7 ms after two exits and 123–145 ms
  after the other five.

The strings are the standard `ProcessExited` and `CtrlDToClose` resources from
`TerminalConnection/Resources/ru-RU/Resources.resw`; this is not a crash or an
error path.

## Cause

`ConptyConnection::_LastConPtyClientDisconnected()` transitions the connection to
`Closed` and then unconditionally calls `_indicateExitWithStatus()`
(`ConptyConnection.cpp:616-617`), which writes the notice into the terminal
buffer. The pane close is decided later by the app on the UI thread
(`TerminalPaneContent::_controlConnectionStateChangedHandler`,
`TerminalPaneContent.cpp:205-252`). The notice therefore reaches the buffer
before the pane is removed and is painted for the intervening frames.

Upstream `main` has the same ordering; the downstream patches did not introduce
this behavior.

## Fix

New downstream patch
[`patches/suppress-exit-notice-on-auto-close.patch`](../patches/suppress-exit-notice-on-auto-close.patch).
It applies after `connection-lifecycle-diagnostics.patch` on Stable
`v1.25.2733.0` (`dc8ae365…`) and changes five files:

- `TerminalConnection/ConptyConnection.idl` and `.h`: new
  `SetExitNoticeSuppression(Boolean suppressOnClosed, Boolean suppressOnFailed)`
  and two `std::atomic<bool>` members.
- `TerminalConnection/ConptyConnection.cpp`: the notice is skipped when the
  corresponding suppression flag is set.
- `TerminalApp/TerminalPaneContent.h` and `.cpp`: the pane computes the flags
  from `profile.CloseOnExit()` and its defterm state, and pushes them to a
  `ConptyConnection` through `TermControl::Connection()`. The policy is applied
  in the constructor, on settings reload, in `MarkAsDefterm()` and on every
  control state change (covers Enter-restart with a fresh connection).

The decision stays where `closeOnExit` is interpreted, so the connection layer
keeps a single behavior: write the notice only when the pane is expected to
remain.

### Behavior matrix

| `closeOnExit` | Successful exit | Failed exit |
| --- | --- | --- |
| `never` | notice kept, pane stays | notice kept, pane stays |
| `graceful` / `automatic` | notice suppressed, pane closes | notice kept, pane stays |
| `always` | notice suppressed, pane closes | notice suppressed, pane closes |
| `automatic` + defterm | notice suppressed, pane closes | notice suppressed, pane closes |

`ProcessFailedToLaunch`, bad-path and elevation texts are separate paths and are
unchanged. Exit codes and the existing `closeOnExit` decisions are unchanged.

### Rejected alternatives

- Skipping the notice for every `Closed` state inside the connection: simpler,
  but it removes the “press Enter to restart / Ctrl+D to close” hint that
  `closeOnExit: never` users rely on.
- Hiding or collapsing the control from the pane handler before removal: the
  output write and the UI close are already racing, so the flash would remain
  timing-dependent.
- Delaying the notice with a timer: any finite delay races the pane removal and
  adds UI-code timing to the connection.

## Verification status

- `git apply --check` passes for the new patch on a clean copy of the current
  patched source state and on the live checkout
  `C:\Users\Pavel\Source\terminal-v1.25.2733.0`.
- Live and fixture traces plus the UIA poller scripts:
  `%USERPROFILE%\Downloads\WT-ExitFlash-20261101`; private, not committed.
- Build `20261101-013312-5924332ac2f84c6dadc803f1dfc3a449`:
  `BUILT_AND_TESTED`, every phase exit 0, Terminal Core 56/56.
- Packaged runtime:
  `%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.2733.0-lf-diag2\terminal-1.25.2733.0`
  (55 files, `PACKAGED_NOT_LAUNCHED`), product
  `1.25.2733.0-local-layoutfix-diag2`, EXE SHA256 `4c6bf3b7…`,
  `TerminalConnection.dll` SHA256 `3e7aee83…`, reviewed settings SHA256
  `20426242…`, shortcut **Terminal LF Diag2 1.25**.
- Isolated `build/Test-ConnectionLifecycle.ps1` on the diag2 runtime: all four
  cases passed and lifecycle records persisted in order. The fixture closes
  successful panes too quickly to prove notice suppression, so it does not
  replace the manual check.
- Not launched, registered, installed or switched; the then-live diag1 runtime
  and HCA routing were untouched. Manual split `exit` acceptance remains pending.

## Residual risks

- The notice still appears when the pane intentionally stays (`never`, or a
  failed exit under non-always modes) — that is the intended behavior.
- A policy change is read per exit; a race would only mean the notice appears or
  is skipped for one exit, never a state change.
- Handoff-created panes receive the policy once the pane content exists and
  `MarkAsDefterm()` runs; a handoff pane that exits before that point keeps the
  upstream notice behavior.
