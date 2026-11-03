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
2. **NOT RUN:** with broadcast enabled in an isolated tab, paste into panes with different
   bracketed-paste modes. Check screenshot/text boundaries in each destination.
3. **NOT RUN:** with a controlled delayed clipboard provider, switch tabs while paste is
   pending. A different tab must receive no broadcast. Repeat while moving the
   last source pane; the old root must not be traversed. This requires a native
   runtime fixture; source review alone does not prove it. Use disposable local
   shells; never submit test text to running agents.
4. **NOT RUN in this build:** check the menu folder item and Ctrl+Shift+9, RU/EN, tab color and normal split
   exit. These behaviors were accepted in earlier binaries, not in this build.

Owner TUI acceptance is limited to the cases above. Restoration and routing
promotion remain separate; do not close working sessions to test restoration.

## Diagnostic build identity follow-up — paste2

Status: **DELIVERED_NOT_MANUALLY_ACCEPTED**. `paste2` retains the owner-tested
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
`paste1`; the remaining manual checks also remain unproven in `paste2`.
Private local evidence, frozen recipes and before-source copies:
`%LOCALAPPDATA%\TerminalLayoutFix\Review-20261103-diagver1`.
