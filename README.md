# Windows Terminal Layout Fix

Community patches and recovery builds for **Windows Terminal, Windows x64**.
The latest published archive `layout-fix.3` is based on Stable **1.25.2733.0**
(the owner-accepted `rmb3` build); `layout-fix.2` (Preview **1.25.1912.0**)
remains available as the previous archive.
The project addresses slow input-language switching with many tabs, clipboard
image/file paste for terminal applications, and application-owned right-button
paste behavior.

[Download](https://github.com/pavelbe/windows-terminal-layout-fix/releases/tag/v1.25.2733.0-layout-fix.3) · [Quick start](docs/quick-start.md) · [Source patches](patches) · [Build and upgrade](UPDATING.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

This is an unofficial downstream project based on
[Microsoft Terminal](https://github.com/microsoft/terminal), not a Microsoft
release. The patches have been posted for discussion; they are **not claimed
to be accepted or merged upstream**.

| Problem | Change | Evidence and limits |
| --- | --- | --- |
| RU/EN switching stalls with many tabs | Coalesce repeated theme updates during settings reload | Owner tested 10, then 50 terminals on one PC; no instrumented benchmark |
| Bitmap-only clipboard cannot be pasted as an image path | Snapshot bitmap, encode a temporary PNG, paste its quoted path | Owner-tested screenshot/text flow; temporary files remain local |
| Several Explorer images attach incompletely | Read the full file selection and preserve per-file paste events | Owner-tested multi-image paste in Codex and Claude Code |
| Right-button image paste is consumed by an application with mouse tracking | Keep only the secondary button with Terminal for paste; primary stays with the TUI | Owner-tested in Claude Code; left-button variant rejected because it broke TUI controls |

Public upstream evidence: [layout reproduction](https://github.com/microsoft/terminal/issues/11522#issuecomment-5677254631),
[layout patch](https://github.com/microsoft/terminal/issues/11522#issuecomment-5680525120),
[50-terminal follow-up](https://github.com/microsoft/terminal/issues/11522#issuecomment-5745315978),
[clipboard patches](https://github.com/microsoft/terminal/issues/19517#issuecomment-5745327476).
Both discussions were open when checked on 2026-09-28. The maintainer
[requested compliance with the upstream AI policy](https://github.com/microsoft/terminal/issues/11522#issuecomment-5747036212);
read [contribution guidance](CONTRIBUTING.md) before contacting upstream.

**New users:** read the recovery steps below, verify the archive checksum and
test in a separate directory. Included settings are the maintainer's example,
including an `Ubuntu` profile; review paths, profiles and keybindings for your
machine. HCA commands in the later maintenance notes are optional local tooling,
not a prerequisite for running the portable EXE.

**Current runtime check (2026-11-03):** the installed candidate on this PC is
`WT-Layout-Fix-1.25.2733.0-lf-rmb3`; the 1.25.1912.0 recovery folders are not
present. Inside a Windows Terminal session, HCA follows the current portable
runtime (`rmb3`). Outside Terminal, channel `layout-fix` now selects the same
`WT-Layout-Fix-1.25.2733.0-lf-rmb3\terminal-1.25.2733.0` runtime; the resolver,
its test and the HCA runbook were updated together on 2026-11-03. The public
`layout-fix.2` archive
remains available as the previous archive. `layout-fix.3` is published from the
accepted build described here and is independent of this local candidate. The owner passed the manual acceptance for `rmb3` on 2026-11-03
[docs/manual-acceptance-rmb3.md](docs/manual-acceptance-rmb3.md); runtime and
settings drift is checked by `build/Test-RuntimeState.sh`. The next public
archive is packaged and verified locally but not published; the recorded
artifact and remaining steps are in
[docs/release-layout-fix.3.md](docs/release-layout-fix.3.md).

## Tested build and maintainer recovery notes

**Right-button paste candidate, 2026-11-01 — accepted by the owner:**
Stable `1.25.2733.0-local-layoutfix-rmb3` adds
`patches/terminal-owned-right-button.patch`. Build receipt
`20261101-112434-9e0ea9d6f2ff43aa85d1aec277ce8bd5` reports
`BUILT_AND_TESTED`: the package build and all Terminal Core tests passed. The
portable layout is
`%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.2733.0-lf-rmb3\terminal-1.25.2733.0`
with shortcut **Terminal LF RMB3 1.25** and the reviewed settings.

The owner ran the earlier `-rmb` build of the same patch and confirmed that a
screenshot pasted with the right button now attaches in Claude Code. `-rmb3`
keeps the same behaviour with the drag guard added, and the owner has it open.
A `-rmb2` variant that also took the primary button was built and rejected: it
made every TUI widget unclickable. `-rmb` and `-rmb2` were removed together
with their shortcuts. The `-lf-diag2` runtime folder is no longer installed; its
shortcut and build record are historical pre-patch fallback evidence.

**Exit-notice suppression candidate, 2026-11-01 — built, not launched:** Stable
`1.25.2733.0-local-layoutfix-diag2` adds
`patches/suppress-exit-notice-on-auto-close.patch`, which skips the informational
`ProcessExited` text when `closeOnExit` will close the pane anyway, removing the
brief text flash before pane removal. Build and Terminal Core tests passed
(56/56); the build record lists package path
`%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.2733.0-lf-diag2\terminal-1.25.2733.0`,
shortcut **Terminal LF Diag2 1.25**, and the reviewed settings, but that folder
is not installed on this PC. No app was launched, registered, installed or
switched for this candidate; its exit-notice behaviour was accepted later inside
`rmb3` (see the manual acceptance results). Measured pane-removal delay,
design, behavior matrix and residual risks:
[exit-notice suppression](docs/exit-notice-suppression-20261101.md).

**Diagnostics candidate, 2026-10-29:** Stable `1.25.2733.0-local-layoutfix-diag1`
adds bounded local records of ConPTY process starts, launch failures and exits.
The square LF icon is unchanged. Build, 56 Terminal Core tests and four isolated
native split/exit scenarios passed. The same lifecycle test failed on the old
binary because its events were not persisted. The recorded local delivery was a
runtime folder and **Terminal LF Diagnostics 1.25** shortcut, without a ZIP; see
the current runtime check for the later state. This does not change
`closeOnExit` or establish the cause of the owner's intermittent split failure.
See [diagnosis, log location, limits and build evidence](docs/connection-diagnostics-20261029.md).

**Square LF candidate, 2026-10-28:** the original square artwork now fills
its icon canvas, matching Claude's 24x24/32x32 taskbar occupancy. Stable
`1.25.2733.0` was rebuilt; all 56 Terminal Core tests and all nine embedded
icon comparisons passed. Use the separate **Terminal LF Square 1.25** shortcut.
The owner confirmed the square taskbar icon's appearance and size against Claude.
Deliver future local builds as a ready runtime directory/EXE and shortcut,
without a ZIP. See the [square artifact record](docs/upgrade-20261026.md#square-lf-candidate-2026-10-28).

**Historical wide LF candidate, 2026-10-28:** rebuilt Stable `1.25.2733.0` embeds the
wider LF artwork. All 56 Terminal Core tests passed; all nine embedded icon
frames match the reviewed ICO. A separate portable ZIP/copy is prepared;
window launch/taskbar appearance and a daily-route switch are not accepted.
See the [dated artifact record](docs/upgrade-20261026.md#wide-lf-candidate-2026-10-28).

**LF candidate, 2026-10-27:** Stable now embeds our [teal LF icon](assets/README.md).
Rebuild and all 56 Terminal Core tests passed. The separate
`WT-Layout-Fix-1.25.2733.0-lf` portable copy launched successfully; its live
16px/32px window icons match the reviewed artwork pixel-for-pixel. Desktop
shortcut **Terminal LF 1.25** targets that exact copy. Taskbar pinning/grouping
and the full manual acceptance suite remain unverified at that stage. Existing
installations and launch routing were preserved at that time. See the dated
record below for artifact hashes.

**Stable candidate, 2026-10-27:** upstream `v1.25.2733.0` with the four-patch
chain used at that date built successfully using VS2026 Build Tools.
TerminalCore passed 56/56; the production-header clipboard smoke passed without
reading the clipboard. EXE and TerminalApp DLL report
`1.25.2733.0-local-layoutfix`. This is a local candidate, not a new public
release or manual UI acceptance. See the
[dated build record and reproduction steps](docs/upgrade-20261026.md).
At the start of the 2026-10-26 audit, the owner identified
`WT-Layout-Fix-1.25.1912.0-tab-color-test` as the then-current runtime; its
processes, settings and launch routing were preserved. Side-by-side UI checks
precede any switch.

**Tab-color candidate, 2026-09-28:**
`WT-Layout-Fix-1.25.1912.0-tab-color-test` adds
[runtime tab-color preservation](patches/preserve-runtime-tab-color.patch)
after the three released patches. The owner reports that RU/EN retains the tab
color in this candidate. TerminalCore: 56/56 tests passed, including an unchanged
regression that failed before the fix. Release/x64 build and packaging passed;
existing resource/XAML warnings remain. This is not a new published release or
a repeat of the 50-terminal/clipboard acceptance suite. At that time, existing
shortcuts and HCA routing remained unchanged.
[Candidate receipt](build/tab-color-candidate-20260928.json).

Launch `WindowsTerminal.exe` from that separate folder. `WTColorTest.exe` is a
byte-identical local test copy used to isolate the `WT-COLOR-TEST` window from
running installations. Do not replace a live installation until its processes
are closed intentionally. At that time the accepted clipboard-files build was
retained for rollback; it is no longer installed on this PC (see current
runtime check).

Codex 0.158 mouse selection is separate: local `~/.codex/config.toml` now sets
`[tui] fullscreen_transcript = false`. Native terminal selection/scrollback replaces
Codex-owned transcript selection/search; the owner confirmed plain mouse selection
and Ctrl+C work. Restart Codex to consume this setting, not Windows/WSL. It is
not embedded in Terminal or its recovery ZIP. Remove that key to restore Codex's
default mode. The keyboard-enhancement workaround remains independently required.

**Accepted recovery build, confirmed 2026-09-20:** the owner reports no RU/EN
freezes even with **50 terminals** in `WT-Layout-Fix-1.25.1912.0-clipboard-files-test`
and closes the layout-freeze task. Multiple Explorer images were already accepted
in both Codex and Claude Code on 2026-09-19. This is owner-observed behavior on
the current PC, not a timed benchmark or a clean-Windows installation test.

The historical `-test` directory name was retained to preserve the pinned
shortcut. At that September check, **HCA routing stayed on
`WT-Layout-Fix-1.25.1912.0` by owner decision**. The later owner-current runtime
is identified above; recovery acceptance alone does not switch HCA routing. At
that time both installations and the immutable `layout-fix.1` archive remained
intact. On 2026-11-03 only the `rmb3` candidate is installed under
`%LOCALAPPDATA%\Programs`; the 1.25.1912.0 folders are absent, and the HCA
resolver targets the installed `rmb3` runtime.

Release check, 2026-10-27: Stable `v1.25.2733.0` and Preview `v1.26.2734.0`
were the newest published versions in their channels. This is a dated check,
not a current-version claim. Recheck
[Microsoft releases](https://github.com/microsoft/terminal/releases) before an upgrade.

Current configuration: [settings/settings.json](settings/settings.json).
Official upgrades, patch porting, builds, acceptance and rollback:
[UPDATING.md](UPDATING.md). Terminal C++ patches, its settings and the HCA Codex
input workaround have separate owners; an official EXE does not include our patch.

Agent rules: [AGENTS.md](AGENTS.md); `CLAUDE.md` imports the same guide.

<a id="быстро-восстановить-на-другой-windows"></a>
## Quick recovery on another Windows installation

1. This repository and its release downloads are public. Review the tested
   platform and configuration notes above before installing.
2. Open [release layout-fix.2](https://github.com/pavelbe/windows-terminal-layout-fix/releases/tag/v1.25.1912.0-layout-fix.2).
   Download **WT-Layout-Fix-1.25.1912.0-layout-fix.2-win-x64.zip** and its **.zip.sha256**
   to Downloads. GitHub's "Source code (zip)" is not the executable package.
   This ZIP includes the reviewed configuration, all three source patches and
   the accepted runtime. The external release manifest records its exact bytes.
3. Run in ordinary Windows PowerShell:

```powershell
$ErrorActionPreference = 'Stop'
$zip = Join-Path $env:USERPROFILE 'Downloads\WT-Layout-Fix-1.25.1912.0-layout-fix.2-win-x64.zip'
$expected = ((Get-Content -LiteralPath ($zip + '.sha256') -Raw).Trim() -split '\s+')[0]
if ($expected -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid checksum file' }
if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ine $expected) {
    throw 'Archive checksum mismatch'
}
$programs = Join-Path $env:LOCALAPPDATA 'Programs'
$terminal = Join-Path $programs 'WT-Layout-Fix-1.25.1912.0-clipboard-files-test'
if (Test-Path -LiteralPath $terminal) {
    throw 'Destination already exists; keep it and extract this archive into a different folder'
}
Expand-Archive -LiteralPath $zip -DestinationPath $programs -ErrorAction Stop
$null = Get-Content -LiteralPath (Join-Path $terminal 'settings\settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
& (Join-Path $terminal 'WindowsTerminal.exe')
```

4. Pin **this running window** to the taskbar. Launch its shortcut without
   the old ten-tab diagnostic script.
5. On the new machine, check **+**, pane splitting, RU/EN at your normal tab
   count, clipboard images/text in both TUIs and restoration. Current-PC
   acceptance does not prove the replacement system.

Extraction into your `%LOCALAPPDATA%` needs no MSIX registration. The portable
copy does not replace Store/Preview; the system default-terminal selection is
available to packaged versions, while portable uses its EXE/shortcut and HCA.
See [Microsoft distributions](https://learn.microsoft.com/en-us/windows/terminal/distributions).
This is x64; the tested system is Windows 11 build 22631.6199.
Migration to another Windows version has not been tested.

If Windows reports missing `VCRUNTIME140*.dll` or `MSVCP140*.dll`, install the
official [Microsoft Visual C++ Redistributable x64](https://aka.ms/vs/17/release/vc_redist.x64.exe).
Never download individual DLLs from random sites. If absent on the new Windows,
install Cascadia Code 11 from the [official font project](https://github.com/microsoft/cascadia-code).
A missing font and a missing runtime are separate problems.

<a id="что-переносится-и-что-нужно-отдельно"></a>
## Included files and separate prerequisites

The archive contains EXE/DLL, XAML/PRI resources, `.portable`, license, all three
patches, README/UPDATING, historical build evidence and a new release receipt.
**Only** `settings/settings.json` is included from user data. The 64 runtime
files match the accepted candidate receipt; settings match the reviewed current
JSON. The complete archive inventory is
[build/recovery-manifest-layout-fix.2.json](build/recovery-manifest-layout-fix.2.json).
Its SHA256 describes this ZIP; the manifest is a separate release asset, avoiding
a self-referential archive hash. The build/acceptance boundary is recorded in
[build/release-receipt-layout-fix.2.json](build/release-receipt-layout-fix.2.json).

**Ubuntu/WSL, projects, HCA, Claude/Codex, authentication and session history are excluded.**
Back them up separately before replacing the system. The config expects a distro
named `Ubuntu`; verify with `wsl --list --verbose`. If absent, temporarily open
CMD from the menu beside **+**. Do not run `wsl --install` over a planned recovery
of the existing distro without a separate plan.

The first launch on another system will not restore old tabs: private `state.json`
and screen buffers are deliberately unpublished. New sessions persist after
normal exit. The settings file does not restore live agent processes.

HCA commands `wt`, `atreno`, `wtc`, `wtd`, `wtw`, `wtp` and `wth` have a separate
launch target. As checked on 2026-11-03, inside a Windows Terminal session HCA
resolves the current portable runtime, which is `rmb3` here; outside Terminal,
channel `layout-fix` selects the same
`Programs/WT-Layout-Fix-1.25.2733.0-lf-rmb3\terminal-1.25.2733.0` runtime.
Pinning the newer EXE does not change HCA. To inspect the live selection in an
idle Zsh prompt:

```zsh
source ~/.zshrc
wt-doctor
```

Inside Terminal, `wt-doctor` should report channel `current-portable` with the
`rmb3` launcher and settings; outside Terminal it reports channel `layout-fix`
with the same launcher (checked on this PC). A future candidate still needs the
resolver path, `tests/test-wt-commands.sh` and the HCA runbook updated together,
as in
[UPDATING section 7](UPDATING.md#7-переключить-запуск-и-оставить-откат);
recovery acceptance alone does not move the fallback. Launch the accepted
`rmb3` build directly or through its pinned shortcut. A project without a count
opens one new single-pane tab in the most recently active window of this build.
An explicit count enables splitting; named presets retain their layouts.
No Windows/WSL restart is needed. If the build is missing, HCA fails instead
of switching silently to installed Preview or Stable.

A separate workaround fixed Cyrillic duplication in Codex 0.154.0:
`CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT=1 codex`. Current HCA applies it to
`codex`/`cxr` inside Windows Terminal/WSL. After `source ~/.zshrc`, the owner
confirmed ordinary launch, typing, paste and newlines. It affects newly launched
Codex, including `codex resume`, not running processes or Claude. Routing source:
`~/hca-system-v3/modules/zsh/claude/55-ai-ip-guard.zsh`.
This is an HCA workaround, not a Terminal binary patch. Recheck Cyrillic and
Ctrl/Shift+Enter when changing Codex/Terminal versions.

These notes supersede the README in the original `layout-fix.1` ZIP.
That archive and SHA256 are unchanged. For migration use `layout-fix.2`,
this current guide and the [HCA runbook](https://github.com/pavelbe/hca-system-v3/blob/main/docs/04-commands/windows-terminal-tabs-panels.md).

<a id="цифровая-десятичная-клавиша-и-снимки-из-буфера"></a>
## Numpad decimal key and clipboard images

Since 2026-09-16 the Ubuntu profile sets
`"compatibility.kittyKeyboardMode": false`. Local Claude 2.1.273 mapped Kitty
code `57409` to a period regardless of layout. Ordinary input restores RU comma
and EN period; the owner confirmed both. This changes the profile, not Claude
or the EXE. Ctrl/Shift+Enter LF bindings and HCA's Codex workaround remain.

PrintScreen/Snipping Tool provides a bitmap; Explorer file copying provides
CF_HDROP. The original Terminal sends an empty bracketed paste for image-only
clipboard data. Claude can then read the bitmap itself, but Codex 0.154.0
expects an actual image-paste key event or a pasted image path.

On 2026-09-16 the missing WSLInterop handler also caused Windows EXEs to fail
with `Exec format error` while `/init` worked. Restoring that handler made
PowerShell and local `xclip`/`wl-paste` bridges work; the owner confirmed Claude
Ctrl+V. A separate read of the owner's 1320×176 screenshot returned PNG, proving
clipboard access. Alt+V did not solve Codex's input path. No WSL/Terminal/agent
restart was performed. Repeat interop diagnosis with the
[HCA runbook](https://github.com/pavelbe/hca-system-v3/blob/main/docs/04-commands/windows-terminal-tabs-panels.md#восстановление-interop-windows-11).

<a id="кандидат-с-универсальным-ctrlv"></a>
### Accepted clipboard build and historical candidates

Previous candidate: `%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.1912.0-clipboard-test`.
In `WT-PASTE-TEST`, the owner confirmed PrintScreen → Ctrl+V and ordinary text
in Codex on 2026-09-19. Its receipt remains historical:
[clipboard-candidate-20260919.json](build/clipboard-candidate-20260919.json).

The published `layout-fix.2` build adds multiple Explorer files. Normal launch
of that archive's portable runtime (the 1.25.1912.0 folder is not installed on
this PC; extract the published archive first if you need it):

```powershell
& "$env:LOCALAPPDATA\Programs\WT-Layout-Fix-1.25.1912.0-clipboard-files-test\WindowsTerminal.exe"
```

Paste precedence is text → Explorer files → bitmap. A file selection is read
completely, in clipboard order (maximum 256); each quoted Windows path gets its
own paste event, with a space before subsequent paths. Codex normalizes Windows
paths to WSL and recognizes **one image per paste**. Joining all paths into one
paste would turn them into text instead of several attachments. This follows
Atreno's `src/terminal/paste-paths.ts` protocol without importing its frontend.
Multi-pane broadcast preserves file boundaries and each receiving pane's
bracketed-paste mode. The complete selection is checked once for paste warnings
before any file is sent. No Enter is injected. Windows paths are preserved;
this does not add Atreno's profile-aware POSIX path conversion to WT clipboard
paste. Drag/drop remains a separate upstream path.

For a bitmap, Terminal copies pixels while the clipboard is open, releases it,
then encodes `%TEMP%\wt-clipboard-{GUID}.png` in the background and pastes its
path. The system clipboard is unchanged. Exclusive file creation prevents
replacement; failed writes remove their incomplete file. PNGs survive Terminal
exit so agents can read them later. Clean old files after finishing attachments;
they are private local data, excluded from Git and release archives.

Patch order depends on the base:

- Published 1.25.1912.0 archive:
  1. [layout-fix.patch](patches/layout-fix.patch), source `a34eea7`;
  2. [clipboard-image-paste.patch](patches/clipboard-image-paste.patch), source `2d4c28b`;
  3. [clipboard-files-paste.patch](patches/clipboard-files-paste.patch), the incremental multi-file fix.
- Current Stable 1.25.2733.0 candidate adds, in order:
  4. [preserve-runtime-tab-color.patch](patches/preserve-runtime-tab-color.patch);
  5. [connection-lifecycle-diagnostics.patch](patches/connection-lifecycle-diagnostics.patch);
  6. [suppress-exit-notice-on-auto-close.patch](patches/suppress-exit-notice-on-auto-close.patch);
  7. [terminal-owned-right-button.patch](patches/terminal-owned-right-button.patch),
     which keeps only the secondary button with Terminal when the application
     tracks the mouse; the primary button keeps reaching the application.
  8. [utility-menu-below-separator.patch](patches/utility-menu-below-separator.patch),
     which renders new-tab-menu entries placed after a separator below
     Terminal's own separator, next to the settings group. Prepared
     2026-11-03; not included in any published archive and not built yet. In a
     build that carries it, put `{ "type": "separator" }` before the utility
     profile in `newTabMenu`; without the patch that separator only adds a
     second divider.
  9. [explorer-profile-opens-folder.patch](patches/explorer-profile-opens-folder.patch),
     which makes a profile whose command is exactly `explorer.exe` open this
     Terminal's own folder through `ShellExecute` instead of creating a pane.
     Prepared 2026-11-03; not built yet. Patches 8 and 9 together serve a bare
     `explorer.exe` profile placed after a separator entry, so the menu item
     opens the running build's folder without a terminal flash.

The exact current pins, source hashes and patch status are in
[build/Build-StableCandidate-20261026.ps1](build/Build-StableCandidate-20261026.ps1)
and [UPDATING.md](UPDATING.md). Do not apply the later patches to the published
1.25.1912.0 archive without an explicit port and a new build.

### Why the right-button patch exists

Application-level switches do not solve this. Tried and rejected on 2026-11-01
with Claude Code 2.1.316 in the `-lf-diag2` build:

- `CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1` stopped Claude Code handling the click,
  but the terminal still did not receive it: both text and image paste stopped.
- `CLAUDE_CODE_DISABLE_MOUSE=1` restored text paste on the right button but a
  screenshot still did not attach, so the click was still consumed by the
  application's own clipboard reader.

Neither variable fixed the screenshot, because the cause is in Terminal:
`ControlInteractivity::PointerPressed` sends every button to an application
that enables mouse tracking, so `_canSendVTMouseInput()` is true and the
right-click paste branch never runs. The patch excludes **only the secondary
button** from that check in press, drag and release. Keyboard `Ctrl+V` was never
affected because it is a Terminal keybinding.

The primary button deliberately keeps reaching the application: Claude Code in
`/tui fullscreen` renders its dialogs inside the terminal, and a left click must
still activate them, as it must for `htop`, `mc` or `vim` with `mouse`. A
left-button variant was built, tested and rejected on 2026-11-01 — it made every
TUI widget unclickable. The known cost of keeping it: a stray click can select
an option in a Claude Code question dialog, and text selection in fullscreen
mode needs `Shift`+drag.

### Claude Code loses lines — not a Terminal bug

Recorded here so a future session does not rebuild the terminal looking for a
cause that is not in it.

- **Symptom:** while Claude Code streams the next answer, a few lines of the
  previous one vanish from the terminal buffer — the opening paragraph
  disappears while the list below it stays, or a whole message is missing. Not
  reproducible on demand; more likely in short panes (3-pane tabs).
- **Diagnosis, 2026-10-31:** the tab buffer was captured through UIA and compared
  with the session JSONL. The session was complete; the screen had lost text —
  five confirmed cases with neighbouring lines intact. The classic Claude Code
  renderer lets the streaming live frame grow past the viewport, and the repaint
  stops addressing rows that scrolled out. Codex is unaffected because it draws
  in the alternate screen.
- **Upstream** (checked 2026-11-01):
  [#92678](https://github.com/anthropics/claude-code/issues/92678) **open** —
  live frame outgrows the viewport and repaints reset the screen; the same
  mechanism, reported to reproduce on bare ConPTY/Windows.
  [#100566](https://github.com/anthropics/claude-code/issues/100566) **open** —
  stale or missing rows in the live viewport.
  [#10239](https://github.com/anthropics/claude-code/issues/10239) closed as not
  planned — typing makes a line of history disappear.
  [#28750](https://github.com/anthropics/claude-code/issues/28750) closed as not
  planned — second statusline row vanishes on narrow terminals.
- **What was tried:** `"tui": "fullscreen"` in `~/.claude/settings.json`
  (`/tui fullscreen`). It stopped the loss and was the owner's setting until
  2026-11-01, when he returned to `"tui": "default"` and is checking whether the
  loss returns.

Full write-up, evidence and the way back to fullscreen live in the HCA runbook,
which is the single source of truth for this problem:
<https://github.com/pavelbe/hca-system-v3/blob/main/docs/04-commands/windows-terminal-tabs-panels.md>
(section «Пропадают строки ответа в Claude Code — настройка `/tui`»).

Both variables stay rejected, including on this patched build:
`CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1` keeps the application in mouse-tracking
mode while ignoring clicks, so the terminal forwards every press and ordinary
text selection stops working (owner-observed 2026-11-01, `-lf-rmb`). Accidental
option clicks in a question dialog are accepted instead. The terminal-side fix
for the right button does not need either variable.

Native smoke compiles the production headers and checks all CF_HDROP entries,
order, separate payloads, Unicode/spaces, empty/single selections, malformed and
oversized refusal; it retains PNG lifetime, pixel/orientation, uniqueness and
write-failure tests. That is helper coverage, not a TUI acceptance claim.
Exact candidate build/runtime evidence:
[clipboard-files-candidate-20260919.json](build/clipboard-files-candidate-20260919.json).

**Owner acceptance, 2026-09-19:** the owner tested multiple Explorer images
in `WT-FILES-TEST` and confirmed they attach in both Codex and Claude Code.
**Acceptance extended, confirmed 2026-09-20:** the owner identifies this exact
folder as the build working without freezes with 50 terminals. The owner also
reports everything checked and working; the explicit per-feature screenshot/text
receipt remains from the preceding candidate. No instrumented 50-tab timings or
full UI regression are claimed. `layout-fix.2` preserves the accepted runtime
and current JSON without recompilation. Its shortcut was pinned; HCA then
selected the older installation at the owner's request. The current runtime
check above records the later migration to `rmb3`.

<a id="рабочие-настройки"></a>
## Working settings

| Setting | Behavior |
| --- | --- |
| Default profile | Ubuntu, `wsl.exe -d Ubuntu`, directory `~` |
| `firstWindowPreference` | `persistedLayoutAndContent`: layout and output |
| `windowingBehavior` | `useAnyExisting`: reuse a window |
| Font | Cascadia Code 11, ClearType |
| Scrollback | Default 9001 lines; old 50000 not carried over |
| Animations, bell | Disabled |
| `experimental.detectURLs` | Enabled; detect URLs and open with Ctrl+click |
| Copy | Plain text without formatting |
| `Ctrl+C`, `Ctrl+V`, `Alt+Shift+D` | Existing copy, paste and split bindings |
| `Ctrl+W` | Close the entire tab and its panes; Terminal intercepts the application's shortcut |
| `Ctrl+N` | New default-profile (Ubuntu) tab, like **+** |
| `Ctrl+Enter`, `Shift+Enter` | `User.AgentNewline`: send LF (`\n`) to the application |
| `Ctrl+Shift+F`, `Ctrl+Shift+P` | Standard search and command palette |

Automatic URL detection was restored on 2026-09-19 in the daily portable
configuration and the then-running `clipboard-files-test` candidate. It had remained
disabled after the layout-freeze investigation. Upstream defaults to `true`:
plain `http://localhost:3002` output is underlined on hover and opens via
Ctrl+left-click in the system browser. This needs a settings change, not a new
EXE. On 2026-09-19 the owner confirmed that Ctrl+click opens the URL and RU/EN
switching stays fast at the usual tab count; the exact tab count was not recorded.
Historical build/release receipts still describe their original settings and
must not be restamped.

`Ctrl+Shift+Period` is freed from Terminal suggestions, as in the previous Preview.
Ordinary Enter and Delete/Home/End are not remapped here. Ctrl/Shift+Enter send
LF; the receiving application decides its meaning, and a shell may execute a
command. The owner confirmed newlines from both shortcuts in Codex and Claude;
that acceptance is separate from the Cyrillic workaround. Working bindings
were preserved rather than reset to old defaults. Terminal intercepts
Ctrl+N/Ctrl+W; JSON checks passed, but separate manual acceptance of those two
shortcuts was not recorded. Test on an empty tab;
`warning.confirmCloseAllTabs=false` disables the window-close confirmation.
Other WSL profile names were preserved; their presence in JSON does not mean
the distros themselves have been migrated.

To restore one window, close **the window containing the desired tabs**, not
individual tabs. For multiple windows use **Quit / Выход** in `Ctrl+Shift+P`.
Save work and finish agents first. Panes/output restore; live programs do not.

<a id="исходный-код-и-границы-проверки"></a>
## Source and verification boundaries

- Published archive upstream: [microsoft/terminal, v1.25.1912.0](https://github.com/microsoft/terminal/tree/v1.25.1912.0).
- Published archive base: `1cea42d433253d95c4487a3037db48197b5e72f4`.
- Current candidate upstream: `v1.25.2733.0`, commit
  `dc8ae365847d41f62d1ebca93815bb00959bc12f`.
- Original local patch commit: `a34eea7b524f7516c68014a14bb94e215520e0fc`.
- [Full patch](patches/layout-fix.patch) changes three files: `TerminalPage.cpp`,
  `TerminalPage.h`, `TermControl.cpp`.
- [Microsoft report with full diff and test result](https://github.com/microsoft/terminal/issues/11522#issuecomment-5680525120).
- During settings application, intermediate window-wide theme refreshes are
  deferred to the existing final refresh. `BackgroundBrush` notifies on object/
  color changes, including acrylic. The source patch changes neither the
  language-switch handler nor input bindings.
- Published 1.25.1912.0 build: Release/x64, VS Build Tools 2022 17.11.1,
  MSVC 14.41.34120, Windows SDK 10.0.22621.0. Historical result: 0 errors,
  70 warnings. The 1.25.2733.0 candidate used VS 2026 Build Tools; exact
  versions and exits are in the [dated report](docs/upgrade-20261026.md).
- Stock/fix comparison with identical current settings and a complete UI
  regression remain unperformed. Cyrillic duplication occurred in both builds;
  HCA's accepted workaround above is independent of the Terminal binary patch.

To recover the published archive source, obtain `v1.25.1912.0` at the exact base
above and apply the first three patches. For the current candidate, use
`v1.25.2733.0` (`dc8ae365…`) and the ordered seven-patch chain above. Check and
apply patches with `git apply --check` / `git apply`, then follow that tag's
build guide. A clean rebuild from this recovery kit has not been performed; use
the tested binary release ZIP for quick recovery.

Current native checkout for Stable `v1.25.2733.0`:
`C:\Users\Pavel\Source\terminal-v1.25.2733.0`
(`/mnt/c/Users/Pavel/Source/terminal-v1.25.2733.0` from WSL), containing the C++
source used by the current `rmb3` build receipt. The older
`C:\Users\Pavel\Projects\terminal-layout-fix` checkout remains historical.
This recovery repository is separate: `~/Projects/windows-terminal-layout-fix`.
Inspect Git in the selected checkout before work; the saved build receipt does
not prove that checkout is currently clean.

`build/original-build-receipt.json` is unchanged; its settings hash belongs to
the test configuration **before** daily-use setup. `build/recovery-manifest.json`
describes only the immutable `layout-fix.1` archive and its original settings,
not the current Git `settings/settings.json`.

<a id="обновление-резервной-копии"></a>
## Updating the recovery copy

Current accepted runtime configuration on this PC:
`%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.2733.0-lf-rmb3\terminal-1.25.2733.0\settings\settings.json`.
Its SHA-256 is `1fe0c248f4e660596589ac95eb259b05c291383b924fbedf58aa05a07bf027e7`,
matching the repository snapshot checked on 2026-11-03. The snapshot adds a
new-tab-menu profile `Explorer: Terminal folder` (GUID
`{caa37a69-2b95-4277-8f08-1064a3fef5a2}`) that walks the process parents to the
running `WindowsTerminal` executable and opens its folder in Explorer, falling
back to `%LOCALAPPDATA%\Programs`; the pane closes through `closeOnExit`. It
follows the build actually in use, not a hardcoded path. The published archives
keep the settings snapshot they were packaged with. The
published
`layout-fix.2` settings path under `WT-Layout-Fix-1.25.1912.0-clipboard-files-test`
is historical; that runtime is not installed on this PC.

The reviewed snapshot was originally synchronized on 2026-09-19, including
automatic URL detection, newline bindings, Ctrl+N/Ctrl+W and disabled Kitty mode
for Ubuntu. After later changes review only this JSON first: it may contain
personal paths and command lines. Buffers, runtime state and authentication stay
out of Git.

In WSL, from this repository root, after reviewing the changes:

```bash
cp /mnt/c/Users/Pavel/AppData/Local/Programs/WT-Layout-Fix-1.25.2733.0-lf-rmb3/terminal-1.25.2733.0/settings/settings.json settings/settings.json
python3 -m json.tool settings/settings.json > /dev/null
cmp settings/settings.json /mnt/c/Users/Pavel/AppData/Local/Programs/WT-Layout-Fix-1.25.2733.0-lf-rmb3/terminal-1.25.2733.0/settings/settings.json
rtk proxy git diff -- settings/settings.json
```

A settings snapshot needs no EXE rebuild or new ZIP. If live JSON already
matches, do not copy or commit it again. Editing instructions also needs no new
archive manifest. A new binary archive needs a separate reviewed release,
SHA256, an actual file inventory and candidate acceptance. Never overwrite old
releases or receipts. Full procedure: [UPDATING.md](UPDATING.md).

The portable build does not receive Store updates. Before changing upstream,
check whether the official version fixes the problem. GitHub Actions is disabled.
