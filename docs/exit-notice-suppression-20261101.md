# Exit-notice suppression — 2026-11-01

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
- Not built and not smoke-tested yet; the owner schedules a later combined build.
- Before that build, refresh `$ExpectedStatus` and `$ExpectedSourceHashes` in
  `build/Build-StableCandidate-20261026.ps1` from the exact patched tree, after
  all pending source fixes are applied. The status map gains
  `ConptyConnection.h`, `ConptyConnection.idl`, `TerminalPaneContent.h` and
  `TerminalPaneContent.cpp`; the `ConptyConnection.cpp` hash changes.
- Planned acceptance: full Release/x64 build, Terminal Core tests, isolated
  `build/Test-ConnectionLifecycle.ps1` run, then a manual split `exit` check with
  the connection log. Build success alone is not UI acceptance.

## Residual risks

- The notice still appears when the pane intentionally stays (`never`, or a
  failed exit under non-always modes) — that is the intended behavior.
- A policy change is read per exit; a race would only mean the notice appears or
  is skipped for one exit, never a state change.
- Handoff-created panes receive the policy once the pane content exists and
  `MarkAsDefterm()` runs; a handoff pane that exits before that point keeps the
  upstream notice behavior.
