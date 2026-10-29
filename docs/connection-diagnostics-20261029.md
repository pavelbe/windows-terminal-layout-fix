# Connection lifecycle diagnostics — 2026-10-29

## Diagnosis and limits

The owner reported a pane displaying exit code `1`, including after `exit` or
splitting. The main Terminal window remains open. A five-day bounded Application
event scan found no matching Terminal crash, and no Terminal dumps were present.
This does not prove that no other error occurred.

On the actual local Ubuntu, `zsh -f -c 'false; exit'` returns 1;
`zsh -f -c 'false; exit 0'` returns 0. With ordinary Terminal close-on-exit
behavior, a zero exit closes the pane and a nonzero exit keeps it visible.
The native fixture reproduced the owner's exact `0x00000001` message. This
explains one path to that message, not the intermittent split failure's cause.
Do not mask failures by globally forcing `closeOnExit: always` or changing Zsh's
standard exit semantics. Use `exit 0` when explicitly requesting a successful exit.

## Local log

`%LOCALAPPDATA%\TerminalLayoutFix\Diagnostics\connection-events.log`

The diagnostic patch records UTC time, build marker, Terminal/child PIDs,
session/profile GUIDs, event and numeric status. Events are `started`,
`launch-failed`, `exited` and `exit-query-failed`. Session GUIDs include braces;
`WT_SESSION` in the child does not. A `started` event means launch preparation
completed; it does not claim that the subsequent output thread started.

No command line, working directory, environment values, input or output are
recorded. This is a local file, not telemetry upload. It is append-only, capped
at 8 MiB, with no automatic rotation/deletion. A full, busy or unwritable file
can drop records; logging is best-effort. Synchronous filesystem operations can
still add latency. Inspect capacity before investigating a later incident;
preserve the file separately before an intentional manual reset.

Starts are recorded before the output thread can observe a fast exit. Exit
records precede connection-state/UI notifications, so closing a successful pane
does not remove its record. The patch preserves existing exit-state decisions.
It does not add a crash dump collector or promise to capture every UI exception.

## Build and delivery

- Base: official Stable `v1.25.2733.0`, commit
  `dc8ae365847d41f62d1ebca93815bb00959bc12f` (still newest Stable in the release API).
- Existing four downstream patches and accepted square icon retained.
- Added source: `src/cascadia/TerminalConnection/ConptyConnection.cpp`, SHA256
  `827fb15454eb79e83a074e5518214920ba06407d0f04c7156b07f968a0dcd00d`.
- Product version: `1.25.2733.0-local-layoutfix-diag1`.
- Build receipt under `%LOCALAPPDATA%\TerminalLayoutFix\BuildLogs\WT-v1.25.2733.0\20261029-115225-7fdbaddb74d94742a9baba15e3e44d88\build-receipt.json`,
  SHA256 `335b7dc1090f50fc15fe453af4e4f9a143cea59b5f2fd2fc825863f8b3ed248e`.
- Runtime: `%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.2733.0-lf-diag1\terminal-1.25.2733.0`.
- Desktop shortcut: `Terminal LF Diagnostics 1.25`.
- EXE SHA256: `424b8f87068bc1d5c6e9434f52ef83f00bb7b92c3556895e071ce5931b313a26`.
- TerminalConnection DLL SHA256: `09391c3be942c868b145b292e07dff20bc72d00cd346782cbfe49306c9c147e7`.

The pinned packaging recipe now uses upstream `-TerminalLayout`, returning a
directory, and records all 55 runtime files. No ZIP was created. Only the reviewed
daily `settings.json` was copied afterward; its SHA256 remains
`20426242513f01c691e127f2f26415721260aa7dc7868a3cf9faccbb733cdeda`.
Session state/buffers were not transferred. Working Terminal PID 7380, previous
installations, pinned shortcuts and HCA routing were preserved. No public release.

## Verification and repeatable native smoke

The full Release/x64 package build exited 0 (563 seconds). Terminal Core passed
56/56. Packaging's existing dirty-layout refusal regression passed. All nine
embedded icon payloads match the accepted square ICO.

`build/Test-ConnectionLifecycle.ps1` runs real ConPTY processes in an isolated
portable copy. It uses CLI splitting and reads only that process's UIA
`TermControl` elements. It checks the remaining anchor's text identity, not only
the pane count. Cases: success (0), failure (1), immediate failure (1), and
missing executable (`0x80070002`). It verifies ordered per-session log records.
On the old binary, all four UI cases completed and the persisted-evidence
assertion failed. The unchanged test passed all four cases on the new binary.

Use a new runtime copy, `.portable`, and fixture JSON with default profile GUID
`{6f3ef6ab-cde4-478c-b5ca-6844c23e65b5}`, `firstWindowPreference: defaultProfile`,
`windowingBehavior: useNew`, and `profiles.defaults.closeOnExit: graceful`.
Include that GUID as a `cmd.exe /d` profile. Never copy live session state.
Then run in a fresh native PowerShell 7 process:

```powershell
.\build\Test-ConnectionLifecycle.ps1 -TerminalRoot C:\scratch\terminal-fixture -EvidenceDirectory C:\scratch\new-smoke-run -RequireDiagnostics
```

The fixture refuses an already-running EXE path. Teardown releases its synthetic
children and terminates only its own verified process if an error pane remains.
This is not native window-close acceptance. UIA/Win32 lessons: compare HWND
explicitly with `[IntPtr]::Zero`; its PowerShell truthiness is not a zero test.
Do not infer a product close defect from `Process.CloseMainWindow` or an Invoke
RPC error without independently verifying the actual UI action/outcome.

Private evidence is under `%USERPROFILE%\Downloads\WT-Diagnostics-20261029`;
baseline/candidate acceptance logs and the frozen build/package recipes remain
there. Raw session data and logs are not committed. Longer daily-use behavior,
the owner's exact intermittent split failure, full restoration/clipboard smoke
and migration of active sessions remain unverified.
