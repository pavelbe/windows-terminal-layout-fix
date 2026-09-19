# Windows Terminal Layout Fix

Private recovery kit for the owner's patched **Windows Terminal Preview
1.25.1912.0, Windows x64**: portable runtime, reviewed settings and source patches.

**Accepted recovery build, confirmed 2026-09-20:** the owner reports no RU/EN
freezes even with **50 terminals** in `WT-Layout-Fix-1.25.1912.0-clipboard-files-test`
and closes the layout-freeze task. Multiple Explorer images were already accepted
in both Codex and Claude Code on 2026-09-19. This is owner-observed behavior on
the current PC, not a timed benchmark or a clean-Windows installation test.

The `-test` directory name is retained to preserve the pinned shortcut. The owner
still works in the older `WT-Layout-Fix-1.25.1912.0` installation; **HCA routing
stays there by owner decision**. Recovery acceptance does not switch daily use.
Both installations and the immutable `layout-fix.1` archive remain intact.

Official release check, 2026-09-20: Preview `v1.25.1912.0` and stable
`v1.24.11911.0` remain the newest published versions in their channels.
No new upstream version needs downloading or rebuilding now. Recheck
[Microsoft releases](https://github.com/microsoft/terminal/releases) before an upgrade.

Current configuration: [settings/settings.json](settings/settings.json).
Official upgrades, patch porting, builds, acceptance and rollback:
[UPDATING.md](UPDATING.md). Terminal C++ patches, its settings and the HCA Codex
input workaround have separate owners; an official EXE does not include our patch.

Agent rules: [AGENTS.md](AGENTS.md); `CLAUDE.md` imports the same guide.

<a id="быстро-восстановить-на-другой-windows"></a>
## Quick recovery on another Windows installation

1. Sign in to GitHub with access to this private repository.
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
launch target. As checked on 2026-09-20, channel `layout-fix` still selects
`Programs/WT-Layout-Fix-1.25.1912.0`, **not this accepted recovery folder**.
The owner explicitly keeps that daily route for now. Pinning the newer EXE does
not change HCA. To inspect the live selection in an idle Zsh prompt:

```zsh
source ~/.zshrc
wt-doctor
```

Doctor currently shows channel `layout-fix`, the EXE in `Programs/WT-Layout-Fix-1.25.1912.0`
and adjacent `settings/settings.json`. When the owner chooses to migrate HCA,
follow [UPDATING section 7](UPDATING.md#7-переключить-запуск-и-оставить-откат)
and update the resolver/test/runbook together. Until then launch the accepted
build directly or through its pinned shortcut. A project without a count opens one new
single-pane tab in the most recently active window of this build. An explicit
count enables splitting; named presets retain their layouts.
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

The accepted build adds multiple Explorer files. Normal launch (no test tabs):

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

Apply patches in order:
1. [layout-fix.patch](patches/layout-fix.patch), source `a34eea7`;
2. [clipboard-image-paste.patch](patches/clipboard-image-paste.patch), source `2d4c28b`;
3. [clipboard-files-paste.patch](patches/clipboard-files-paste.patch), the incremental multi-file fix.

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
and current JSON without recompilation. Its shortcut is pinned; HCA still
selects the older installation at the owner's request.

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
configuration and the running `clipboard-files-test` candidate. It had remained
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

- Upstream: [microsoft/terminal, v1.25.1912.0](https://github.com/microsoft/terminal/tree/v1.25.1912.0).
- Base: `1cea42d433253d95c4487a3037db48197b5e72f4`.
- Original local patch commit: `a34eea7b524f7516c68014a14bb94e215520e0fc`.
- [Full patch](patches/layout-fix.patch) changes three files: `TerminalPage.cpp`,
  `TerminalPage.h`, `TermControl.cpp`.
- [Microsoft report with full diff and test result](https://github.com/microsoft/terminal/issues/11522#issuecomment-5680525120).
- During settings application, intermediate window-wide theme refreshes are
  deferred to the existing final refresh. `BackgroundBrush` notifies on object/
  color changes, including acrylic. The source patch changes neither the
  language-switch handler nor input bindings.
- Build: Release/x64, VS Build Tools 2022 17.11.1, MSVC 14.41.34120,
  Windows SDK 10.0.22621.0. Historical result: 0 errors, 70 warnings.
- Stock/fix comparison with identical current settings and a complete UI
  regression remain unperformed. Cyrillic duplication occurred in both builds;
  HCA's accepted workaround above is independent of the Terminal binary patch.

To recover source, obtain the official repository at the exact base above;
check/apply `patches/layout-fix.patch` using `git apply --check` and `git apply`.
Follow that upstream tag's build guide. HCA clone/build/dependency commands
require the machine-global heavy lock. A clean rebuild from this recovery kit
has not been performed; use the tested binary release ZIP for quick recovery.

Existing native checkout: `C:\Users\Pavel\Projects\terminal-layout-fix`
(`/mnt/c/Users/Pavel/Projects/terminal-layout-fix` from WSL), containing C++ source.
This recovery repository is separate: `~/Projects/windows-terminal-layout-fix`.
Inspect Git in the selected checkout before work; the saved build receipt does
not prove that checkout is currently clean.

`build/original-build-receipt.json` is unchanged; its settings hash belongs to
the test configuration **before** daily-use setup. `build/recovery-manifest.json`
describes only the immutable `layout-fix.1` archive and its original settings,
not the current Git `settings/settings.json`.

<a id="обновление-резервной-копии"></a>
## Updating the recovery copy

Accepted recovery configuration on this PC:
`%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.1912.0-clipboard-files-test\settings\settings.json`.
The still-used older installation has an identical JSON at:
`%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.1912.0\settings\settings.json`.
The reviewed snapshot was synchronized on 2026-09-19, including automatic URL
detection, newline bindings, Ctrl+N/Ctrl+W and disabled Kitty mode for Ubuntu.
After later changes review only this JSON first: it may contain personal paths
and command lines. Buffers, runtime state and authentication stay out of Git.

In WSL, from this repository root, after reviewing the changes:

```bash
cp /mnt/c/Users/Pavel/AppData/Local/Programs/WT-Layout-Fix-1.25.1912.0-clipboard-files-test/settings/settings.json settings/settings.json
python3 -m json.tool settings/settings.json > /dev/null
cmp settings/settings.json /mnt/c/Users/Pavel/AppData/Local/Programs/WT-Layout-Fix-1.25.1912.0-clipboard-files-test/settings/settings.json
rtk proxy git diff -- settings/settings.json
```

A settings snapshot needs no EXE rebuild or new ZIP. If live JSON already
matches, do not copy or commit it again. Editing instructions also needs no new
archive manifest. A new binary archive needs a separate private release,
SHA256, an actual file inventory and candidate acceptance. Never overwrite old
releases or receipts. Full procedure: [UPDATING.md](UPDATING.md).

The portable build does not receive Store updates. Before changing upstream,
check whether the official version fixes the problem. GitHub Actions is disabled.
