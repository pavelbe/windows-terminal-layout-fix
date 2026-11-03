# Clipboard candidate — 2026-11-03

`paste1` extends the owner-accepted `lf-menu2` source with
`patches/clipboard-paste-parity.patch`. The daily runtime, its settings and HCA
routing remain on `lf-menu2`. No public release assets are changed.

## Changes and evidence

- **P2: unquoted screenshot path.** `saveTemporaryPng` returns a raw path;
  the paste handler previously sent it without quotes. Paths containing spaces
  could be interpreted as several words. The handler now shares `quotePath`
  with Explorer-file paste. This preserves one attachment path without changing
  the saved PNG filename or system clipboard.
- **P2: broadcast text/image paste boundaries.** The source pane uses
  `ControlCore::PasteText`, which frames bracketed paste. Other panes previously
  received screenshot/text bytes through `RawWriteString` without those frames;
  the file-list branch already framed each item. Both broadcast branches now use
  the receiving pane's mode and the same upstream input filter as the source
  (CRLF/LF normalization and control-code removal). No Enter is added.
- **P2: async broadcast used the newly focused tab.** Clipboard access and paste
  confirmation can yield. Looking up the focused tab afterward could redirect
  the broadcast to another tab. The handler now retains the original tab before
  its first suspension and checks the current root before traversal: moving the
  final pane can detach that root while paste is pending. Tab-switch/pane-move UI
  acceptance is still required.
- **P3: ambiguous build identity.** The menu build retained the old `rmb3`
  product suffix. The new recipe uses `1.25.2733.0-local-layoutfix-paste1`;
  existing binaries and historical receipts retain their original identity.
- **Packaging:** the new build-specific recipe checks MSIX entries for a root
  `settings` directory before creating a destination or extracting files. The
  older packaging scripts remain historical recipes.

The existing `ClipboardFiles.h` owns the two small formatting helpers because
Explorer and screenshot paste share the path contract, and both broadcast
branches share destination framing. There is no new runtime dependency or flag.

## Verification

- The eleven-patch chain reconstructed all 17 affected source files from
  upstream `dc8ae365847d41f62d1ebca93815bb00959bc12f`, with no differences after
  CRLF/LF normalization. The LF icon is a separate existing overlay.
- Fresh native compilation and clipboard smoke passed without reading the live
  clipboard: quoted screenshot path with spaces/Cyrillic, framed/plain/empty
  paste, all existing Explorer-file and PNG lifetime/roundtrip/failure checks.
- Unchanged smoke tests failed at their intended assertions when isolated
  production-header variants returned an unquoted path or omitted paste frames.
- Offline packaging tests passed with real ZIP fixtures: private layout refusal,
  clean reviewed-settings copy, settings directory/file/case variants and a clean
  archive control. Disabling the package preflight condition made the unchanged
  test fail at `Package settings preflight did not refuse: settings/`.
- Independent native read-only review confirmed the final source delta and
  closed its root-lifetime and input-filter findings. Reviewed patch SHA-256:
  `8419a763a1205017d0f2bb3d7d9b9919a19baa3f184dcef2a81bd8f7ca475dda`.
- Final Release/x64 application build and all **56/56 Terminal Core tests**
  passed, with no skipped/blocked tests. Final build run:
  `20261103-214046-c60031bf24074242bcc460e7522eab7f`.
- Build receipt SHA-256:
  `b9cfb69570c74c25ed055ea81a1c31c216ca1c75db3fc3a3f3e4f90cdeea530f`.
- MSIX SHA-256:
  `41ddfb72f05d473167c7f67835f735535149d0dacd9add659ebd087f6bd10dc2`.
- All **17/17 Types tests** passed, with no skipped/blocked tests, including
  the upstream paste-filter cases. Changed C++ ranges passed clang-format checks.
- All **55 packaged runtime files** matched the package receipt by size and
  SHA-256 after delivery. Only the reviewed `settings/settings.json` was copied;
  its directory contains no session state or other files.
- Runtime-state checks passed: HCA still selects `lf-menu2`, and the live settings
  match the reviewed repository JSON.

## Local delivery

Status: **OWNER_CLIPBOARD_AND_DRAGDROP_PASS** (2026-11-03). The owner confirmed
screenshots, multiple-image paste, right-button paste and ordinary paste in
both Codex and Claude Code. Multiple-image drag/drop also works in both TUIs;
the proposed drag/drop parity change is therefore unnecessary. This does not
claim broadcast, delayed-paste tab/pane movement or restoration coverage.
The separate portable runtime is:

```text
C:\Users\Pavel\AppData\Local\Programs\WT-Layout-Fix-1.25.2733.0-lf-paste1\terminal-1.25.2733.0\WindowsTerminal.exe
```

The verified desktop shortcut is `C:\Users\Pavel\Desktop\Terminal LF Paste1 1.25.lnk`.
Package and original delivery receipts are in the runtime's parent directory;
their `NOT_LAUNCHED` status describes agent delivery before the owner's tests.
No archive, registration, live-runtime replacement or routing change was made.
The checks below retain their individual coverage boundaries.

Local diagnostic inputs, RED variants, logs and the preserved pre-edit source
are under `%LOCALAPPDATA%\TerminalLayoutFix\Review-20261103-paste1`.
These are private local evidence, excluded from Git and releases.

## Manual acceptance before switching

Use only the separate candidate after its build/package checks pass:

1. **OWNER PASS, 2026-11-03:** screenshots, multiple-image paste, right-button
   paste and ordinary paste in Codex and Claude Code. Multiple-image drag/drop
   was separately confirmed in both TUIs.
2. **AUTOMATED PASS in paste2/paste3:** with broadcast enabled in an isolated
   tab, paste into panes with different bracketed-paste modes. Check screenshot/text boundaries in each destination.
3. **AUTOMATED PASS in paste2/paste3:** with a controlled delayed clipboard
   provider, switch tabs while paste is pending. A different tab must receive no broadcast. Repeat while moving the
   last source pane; the old root must not be traversed. This requires a native
   runtime fixture (now implemented below); source review alone does not prove
   it. Use disposable local shells; never submit test text to running agents.
4. **OWNER PASS in paste2, 2026-11-03:** RU/EN, the menu folder item,
   Ctrl+Shift+9, splitting and closing panes. Tab color was accepted earlier;
   restoration remains a separate check.

Owner TUI acceptance is limited to the cases above. Restoration and routing
promotion remain separate; do not close working sessions to test restoration.

## Diagnostic build identity follow-up — paste2

Status: **OWNER_DAILY_SMOKE_PASS** (2026-11-03). The owner confirmed RU/EN,
the menu folder item, Ctrl+Shift+9, splitting and closing panes in `paste2`.
`paste2` retains the owner-tested
clipboard and drag/drop code from `paste1` unchanged. It adds only
`patches/diagnostic-build-version.patch`: the logger's fixed
`build=lf-diag-20261029` becomes the existing MSBuild `ProductStringVersion`,
passed as a compile-time string to TerminalConnection. No runtime file reads,
new dependencies, logging guards, storage cap or recovery behavior change.

- The twelve-patch chain reconstructed all **18 affected source files** from
  the pinned upstream SHA, with no differences after CRLF/LF normalization.
- Release/x64 package build and **56/56 Terminal Core tests** passed. Run:
  `20261103-224630-2b30db038e6944918bf7302cacea4399`.
- Build receipt SHA-256:
  `c23b4c712e616065cc4516f458cd899048e5879448d3582a98116acc1c7bba30`.
- MSIX SHA-256:
  `cf6427da7ff1ab7703181feff86f02318f8037bb2df7eac3457682bccbe9d067`.
- The unchanged lifecycle regression failed on isolated `paste1` bytes at the
  new build-version assertion: all four existing event-order checks passed,
  but all four version comparisons failed. On isolated `paste2` bytes, all
  four scenarios passed both checks, including launch failure. The expected
  version is read independently from `TerminalConnection.dll` resources:
  `1.25.2733.0-local-layoutfix-paste2`.
- These native fixtures intentionally displayed shell/launch errors and closed
  only their own exact-path processes. Working Terminal/WSL sessions were kept.
- Offline packaging regression passed for both pinned paste recipes. All
  **55 package files** were verified by size/SHA-256 before copying only the
  reviewed settings JSON. PowerShell AST and project XML checks passed.
- Scoped clang-format reported existing argument-layout debt in the logger:
  11 diagnostics on the pre-edit statement and 12 with the new argument.
  This formatting check is **not green**; no unrelated reformat was applied.
- All **nine embedded icon frames** in the delivered EXE match the reviewed
  square LF icon. EXE SHA-256:
  `d03879f28bc82f6198365bfe9253f27c5351c4f6f08da8c6a654b714042ea772`.
- Runtime-state checks passed: HCA fallback and its test/runbook remain on
  `lf-menu2`; its settings still match the reviewed repository JSON.

Ready local EXE:

```text
C:\Users\Pavel\AppData\Local\Programs\WT-Layout-Fix-1.25.2733.0-lf-paste2\terminal-1.25.2733.0\WindowsTerminal.exe
```

Desktop shortcut: **Terminal LF Paste2 1.25**. The delivered directory itself
was not launched; lifecycle smoke used a separate package-only copy with
synthetic fixture settings. No ZIP, public asset replacement, registration or
routing promotion was performed. The owner acceptance above applies to
`paste1`; the later owner daily-use checks above apply to `paste2`.
Automated broadcast/delayed-paste results are recorded in the follow-up below.
Private local evidence, frozen recipes and before-source copies:
`%LOCALAPPDATA%\TerminalLayoutFix\Review-20261103-diagver1`.

## Runtime verification and packaging follow-up — paste3

Status: **DELIVERED_RUNTIME_SMOKE_PASS_NOT_OWNER_ACCEPTED**. Native source differs
from `paste2` only in whitespace within the lifecycle logger, delivered as
`patches/diagnostic-format.patch`. The pre/post token comparison and scoped
upstream clang-format check passed. All thirteen patches reconstruct the same
18 affected upstream source files after CRLF/LF normalization.

- Release/x64 package build and **56/56 Terminal Core tests** passed. Run:
  `20261103-230446-16c99166ee3649759bc99192cef7e8f4`.
- Build receipt SHA-256:
  `e3993e7c703d9d6eee66742bf28cb043203d2718541c1528ad3abba307879983`.
- MSIX SHA-256:
  `f9009e6cc8965462a53ac8aacb4e48a4af43ad13cbcdf21d6478b9a407cdb5ff`.
- `Test-PasteRuntime.ps1` passed all **four native scenarios** on package-only
  copies of both `paste2` and `paste3`: text broadcast, bitmap broadcast, delayed
  paste while switching tabs, and delayed paste while moving the last pane.
  Native receivers record actual ConPTY bytes. Plain and bracketed receivers
  must receive their exact expected payload; the unrelated tab stays empty.
  The clipboard provider confirms a real `WM_RENDERFORMAT` request and waits
  for an explicit release after the UI transition. No running agent receives
  synthetic input. The empty-recipient observation window is 500 ms after input.
- With the final unchanged harness on isolated `menu2` bytes, the text case
  fails at `BRACKETED_PEER: paste framing differs.` and both delayed cases fail
  at `OTHER_TAB: unrelated recipient received paste.` These are product RED
  controls, separate from the initial harness-setup failures.
- Independent review found two harness-isolation gaps, both corrected: require
  a real adjacent `.portable` file before writes/launch, and send key messages
  directly to a PID/ancestry-checked XAML focus HWND instead of global input.
  Missing-marker controls refused both this runner and the existing lifecycle
  runner before creating evidence. A foreground-switch control delivered its
  command to the original Terminal; the second owned window saw zero key events.
- All **four lifecycle scenarios** passed on `paste3`, including exact log/DLL
  version equality. Intentional error windows belong only to those fixtures.
- The new pinned packager automatically compares **all nine icon frames in all
  languages of primary resource group 101** before writing a successful receipt.
  Correct artwork passes; an altered first-frame payload fails at
  `Embedded icon frame 0 payload differs.` No EXE code is loaded or launched.
- Offline packaging tests passed for all three immutable paste recipes; all
  **55 runtime files** matched the package inventory before delivery. Only the
  reviewed settings JSON was added; no session state was copied.

Use the separate **Terminal LF Paste3 1.25** desktop shortcut, targeting:

```text
C:\Users\Pavel\AppData\Local\Programs\WT-Layout-Fix-1.25.2733.0-lf-paste3\terminal-1.25.2733.0\WindowsTerminal.exe
```

The delivered directory was not launched. Native smoke used isolated copies;
owner daily-use acceptance above applies to `paste2`. Existing installations,
HCA fallback, public archives and working sessions remain unchanged. No ZIP.
Private evidence: `%LOCALAPPDATA%\TerminalLayoutFix\Review-20261103-paste3`.

### Repeat the native paste checks

Use a fresh package-only copy with its `.portable` marker. Create a new
`settings` directory and copy `build/paste-runtime-settings.json` into it as
`settings.json`; never use daily settings or session state. Terminal may add
built-in profiles when saving that synthetic file, so restore the fixture JSON
only in that isolated inactive copy before another run. The test temporarily
replaces clipboard contents with synthetic text/bitmap data, opens visible
witness windows, and addresses its own window controls. It closes only its own
witnesses. Run from native PowerShell 7.4+:

```powershell
.\build\Test-PasteRuntime.ps1 -TerminalRoot C:\scratch\paste-fixture -EvidenceDirectory C:\scratch\new-paste-evidence
```

`-Cases delayed-tab` selects one named case for diagnosis. The default runs all
four. Source compilation requires the same VS2026 C++ Build Tools as the build.
The renderer/receiver fixture is synthetic test code, not shipped runtime code.

### Clipboard failure and log review

The existing production-header smoke passed PNG lifetime/roundtrip and the
unwritable-destination case: saving refuses without returning a false path or
damaging an existing PNG. No routine screenshot-save failure was reproduced,
so no speculative notification or new logging path was added. The connection
log does not record clipboard failures; its silence cannot prove paste health.

The seven-day Application event scan inspected 76 events (IDs 1000/1001), with
no cap reached. Three Terminal crashes and their WER reports all reference the
old `Downloads\WT-Diagnostics-20261029\baseline` EXE: `TerminalApp.dll`,
`0xc0000005`, offset `0x14bc8d`. They do not identify a defect in the installed
`menu2`, `paste2` or `paste3` bytes. Their cause remains unknown; later successful
fixtures do not explain a historical crash. Existing nonzero connection records
match the documented lifecycle fixtures, including today's RED/GREEN runs;
`259` means still active when queried at close. These best-effort logs establish
neither absence of all defects nor a reason to alter working paste behavior.
