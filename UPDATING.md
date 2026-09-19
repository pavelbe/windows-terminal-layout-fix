# Updating Windows Terminal and porting our patches

This is a procedure for the next upgrade, **not evidence of a completed rebuild**.
[README.md](README.md) owns the working build, candidates and recovery status.
Obtain Microsoft's source separately; this repository is the recovery kit.

<a id="1-сначала-проверить-официальный-релиз"></a>
## 1. Check the exact official release

Read [Microsoft releases](https://github.com/microsoft/terminal/releases) and
[#11522](https://github.com/microsoft/terminal/issues/11522), including linked PRs.
Check the **exact release tag**, not only `main`, a closed issue or "Latest":
stable and Preview/prereleases are distinct. The historical check on 2026-09-15
found Preview `v1.25.1912.0`, stable `v1.24.11911.0` and an open #11522.
Recheck for the actual upgrade; these are not current-version claims.

Read-only discovery:

```bash
rtk-run -- gh api 'repos/microsoft/terminal/releases?per_page=10' --jq '.[] | [.tag_name, .prerelease, .published_at] | @tsv'
rtk-run -- gh issue view 11522 --repo microsoft/terminal --comments
```

First test an **official unpatched x64 unpackaged ZIP** beside the working build.
Extract to a new directory; create `.portable` beside the EXE **before first
launch**, then copy only the reviewed JSON to `settings/settings.json`.
Launch the full `WindowsTerminal.exe` path and verify the actual process path.
A new window is not proof that a new build/process was launched.
See [Microsoft distribution types](https://learn.microsoft.com/en-us/windows/terminal/distributions).

- If upstream passes section 6, prefer it. Retire only patches whose behavior
  is now covered; configuration and the HCA Codex workaround need separate checks.
- If the layout freeze remains, port that patch using sections 3–5.
- If source or behavior is unclear, keep the working build and investigate the
  exact candidate. A clean patch application does not prove a fix.

<a id="2-сохранить-рабочее-состояние"></a>
## 2. Preserve the working installation

Save the current JSON and review its diff as described in README.
Keep `%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.1912.0` intact.
Candidates use separate directories, never a symlink to shared live settings.

To migrate tabs/buffers later, save work and exit the old Terminal normally,
then make a **private local copy of its complete settings directory**.
It contains session text: never commit or release it. Initial comparisons need
only the JSON; move session state separately after acceptance.
Keep the old state copy because newer formats may not be backward-compatible.
This does not preserve live agent processes.

An upgrade does not require `wsl --shutdown`, BIOS changes or reinstalling the
distribution. Close working windows only in the owner-approved transition window.

<a id="3-получить-исходники-и-проверить-патч"></a>
## 3. Obtain source and check each patch

Historical base: `v1.25.1912.0`,
SHA `1cea42d433253d95c4487a3037db48197b5e72f4`.
[patches/layout-fix.patch](patches/layout-fix.patch) comes from source commit
`a34eea7b524f7516c68014a14bb94e215520e0fc`.
It is a C++ source diff; **it cannot be applied to an EXE or MSIX**.

Choose an exact release tag in WSL. This example reproduces the old base;
replace `wt_tag` with the verified new tag for an upgrade.
Keep the Windows/MSBuild checkout on NTFS, for example
`C:\Users\Pavel\Source`, rather than a UNC path.

```bash
wt_tag='v1.25.1912.0'
wt_source="/mnt/c/Users/Pavel/Source/terminal-$wt_tag"
wt_patch='/home/pavelbe/Projects/windows-terminal-layout-fix/patches/layout-fix.patch'
```

Use a new, nonexistent destination, not an old checkout:

```bash
test ! -e "$wt_source"
/home/pavelbe/.claude/bin/heavy-lock.sh --wait 600 -- git -c core.autocrlf=false clone --branch "$wt_tag" --single-branch --depth 1 https://github.com/microsoft/terminal.git "$wt_source"
```

Stop on any failed command. These are operator templates, not an admission
bypass: agents replace Git/lock variables with verified **literal paths/tags**
and set the source working directory. Continue as separate commands:

```bash
rtk proxy git -C "$wt_source" rev-parse HEAD
rtk proxy git -C "$wt_source" describe --tags --exact-match
rtk proxy git -C "$wt_source" status --short
/home/pavelbe/.claude/bin/heavy-lock.sh --wait 600 -- git -C "$wt_source" submodule update --init --recursive
rtk proxy git -C "$wt_source" apply --check "$wt_patch"
```

Match HEAD to the selected tag's commit; release API `target_commitish: main`
is not a pinned SHA. The tree must be clean before patch checking.

| Result | Action |
| --- | --- |
| `apply --check` passes | Read all three affected contexts, then apply |
| Forward check fails; `apply --reverse --check` passes | Changes are already present; do not reapply; verify behavior |
| Both fail | Investigate refactoring, partial fixes or a different base manually |

Apply **only after a successful forward check and context review**:

```bash
rtk proxy git -C "$wt_source" apply "$wt_patch"
rtk proxy git -C "$wt_source" diff --check
rtk proxy git -C "$wt_source" diff --stat
```

Do not force incompatibility with `--reject`, whitespace ignoring or automatic
`--3way`. Preserve original patch bytes, including CRLF context in
`TermControl.cpp`; do not run a formatter on patch files.

Preserve semantics when porting:

1. `TerminalPage.h`: `_updatingTerminalSettings` belongs to the page.
2. `TerminalPage.cpp`: defer window-wide `_updateThemeColors` while applying
   settings to tabs; restore previous state with a scope guard. Preserve the
   existing final refresh and icon/title/ActionMap/tab updates.
3. `TermControl.cpp`: notify `BackgroundBrush` changes when the object **or
   color** changes, including SolidColorBrush and AcrylicBrush. Equal backgrounds
   must not generate redundant notifications; preserve TintColor/FallbackColor changes.

Do not transplant a guard if upstream replaced its underlying path.
Record the new diff against the **new upstream SHA**, exact file list and patch
SHA256. Keep old patches in history/releases. A clean `git apply` proves context,
not semantics, compilation or behavior.

Clipboard patches have independent acceptance from the layout fix. On the
original base, apply `layout-fix.patch`, then `clipboard-image-paste.patch`
(source `2d4c28b`), then `clipboard-files-paste.patch`; check and read each diff
before applying it. On a new upstream tag, test screenshot **and multi-file**
paste first: either patch may become unnecessary independently of the others.

Preserve text precedence, complete CF_HDROP enumeration, one paste per file,
one warning for the whole selection, per-pane bracketed-paste behavior,
background bitmap encoding after CloseClipboard, exclusive unique PNG creation
and failed-write cleanup. Never inject Enter or replace the system clipboard.
The owner accepted screenshots/text in the first candidate; multi-file candidate
acceptance and promotion are tracked in README, not inferred from build success.

<a id="4-собрать-на-windows"></a>
## 4. Build on Windows

Read README, `doc/building.md`, `.vsconfig` and build scripts from the
**selected tag**. The [main-branch guide](https://github.com/microsoft/terminal/blob/main/doc/building.md)
is only a pointer; requirements can change. The original base documents
PowerShell 7+, VS 2022 Desktop C++, UWP/v143 tools and Windows SDK 22621;
tests need the .NET Framework Targeting Pack. See the
[base README](https://github.com/microsoft/terminal/blob/v1.25.1912.0/README.md).

Do not treat old receipt versions as a new release's requirements.
Record actual VS/MSBuild/MSVC/SDK/NuGet versions and submodule SHAs.
Do not upgrade dependencies beyond the tag's requirements merely to make it build.

Open **Windows PowerShell 7 (`pwsh.exe`)** in the checkout.
This recipe assumes `OpenConsole.slnx`; adapt it from the selected build scripts
if the layout changes. This documentation edit did not execute a rebuild.

```powershell
$ErrorActionPreference = 'Stop'
Set-Location 'C:\Users\Pavel\Source\terminal-v1.25.1912.0' # selected checkout
Import-Module .\tools\OpenConsole.psm1
Set-MsBuildDevEnvironment
& .\dep\nuget\nuget.exe restore .\OpenConsole.slnx
if ($LASTEXITCODE -ne 0) { throw 'Solution restore failed' }
& .\dep\nuget\nuget.exe restore .\dep\nuget\packages.config
if ($LASTEXITCODE -ne 0) { throw 'Shared packages restore failed' }
& msbuild.exe .\OpenConsole.slnx /t:Terminal\CascadiaPackage /p:Configuration=Release /p:Platform=x64 /p:AppxPackageSigningEnabled=false /m:2 /bl:terminal-release-x64.binlog
if ($LASTEXITCODE -ne 0) { throw 'Terminal build failed' }
```

Restore commands are separate because the
[base helper](https://github.com/microsoft/terminal/blob/v1.25.1912.0/tools/OpenConsole.psm1)
calls NuGet multiple times before MSBuild; an early failure must survive.
Building CascadiaPackage does not execute unit tests. Build/run the appropriate
TerminalApp/Control/Settings Model tests from the chosen tag and record each exit.
Missing dependencies or unexecuted tests are `NOT RUN`.
UIA tests control the mouse; run them only during an agreed test window.

Agent clone/submodule/restore/build/test/package phases run sequentially under
the machine-global heavy lock, preserving logs and exits. For Windows phases,
use a reviewed `.ps1` through `pwsh.exe -File` under an outer WSL lock; do not
start a second GUI build. Binlogs stay local because they can contain paths and
environment parameters. Do not run GitHub Actions.

Put the reviewed script in a local Windows directory and pass its full Windows
path. RemoteSigned may treat `\\wsl.localhost\Ubuntu\...` as remote and refuse
an unsigned script. Do not change ExecutionPolicy to run it. This does not
authorize unblocking downloaded scripts; verify their provenance/signature
requirements separately.

<a id="5-получить-полный-portable-кандидат"></a>
## 5. Package a complete portable candidate

One EXE is insufficient: matching DLLs, XAML/PRI resources and dependencies
must come from **the same build**. Do not overlay old DLLs on a new release.
`OpenConsole.exe` is the console host, not the tabbed application.

The base provides
[New-UnpackagedTerminalDistribution.ps1](https://github.com/microsoft/terminal/blob/v1.25.1912.0/build/scripts/New-UnpackagedTerminalDistribution.ps1).
Recheck parameters in the new tag. For AppX packaging, select exact paths to
**your freshly built** Terminal MSIX/AppX and the matching Microsoft.UI.Xaml
x64 AppX dependency; never select the first file found.

```powershell
& {
    if ($PSVersionTable.PSVersion -lt [version]'7.4') { throw 'Use PowerShell 7.4+ for this packaging recipe' }
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $true
    $terminalPackage = Read-Host 'Full path to the newly built Terminal .msix/.appx'
    $xamlPackage = Read-Host 'Full path to matching Microsoft.UI.Xaml x64 .appx'
    $makeAppx = Read-Host 'Full path to MakeAppx.exe from the selected Windows SDK'
    $staging = Read-Host 'New empty staging directory outside the live installation'
    if (Test-Path -LiteralPath $staging) { throw 'Use a new staging directory' }
    $result = @(& .\build\scripts\New-UnpackagedTerminalDistribution.ps1 -TerminalAppX $terminalPackage -XamlAppX $xamlPackage -MakeAppxPath $makeAppx -Destination $staging -PortableMode)
    if ($result.Count -ne 1 -or $result[0] -isnot [System.IO.FileInfo] -or $result[0].Extension -ne '.zip' -or $result[0].Length -le 0) {
        throw 'Packaging did not return one nonempty ZIP; do not use partial output'
    }
    $result[0]
}
```

Native-error propagation is mandatory and scoped to this scriptblock, without
changing the PowerShell profile. In the base chain, `Merge-PriFiles.ps1` does
not check `MakePri.exe new`; a later successful tar can hide its failure.
Checking only `$LASTEXITCODE` after the outer script sees the last native exit,
not every phase. See
[`$LASTEXITCODE`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables#lastexitcode)
and [`$PSNativeCommandUseErrorActionPreference`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables#psnativecommanduseerroractionpreference).
Inspect the new tag's complete helper chain for local overrides/error handling.
A ZIP's presence does not establish valid resources.

Historical proof, 2026-09-15, PowerShell 7.6.6: the actual base
`Merge-PriFiles.ps1` continued after a stub tool exited 23 in the old mode;
a subsequent native success yielded 0. The new mode stopped at the first failure;
the exit-0 control passed. This was an isolated error-contract probe, not a
Terminal rebuild or Windows UI smoke. The historical ZIP was unchanged.

With only an `AppxManifest.xml` layout, the base helper accepts
`-TerminalLayout` instead of `-TerminalAppX`; it returns a temporary directory,
not a ZIP in `-Destination`. Verify the returned path and move the complete
result to a new candidate folder. Do not run a lasting installation from TEMP.
If the helper changes/disappears, rederive supported upstream packaging instead
of assembling an incomplete file set manually.

Extract separately, verify `.portable` and copy only the current JSON before
launch. Name the directory for the new version (`WT-Layout-Fix-<version>`);
do not rename or overwrite the old installation.

<a id="повторить-текущую-проверку-clipboard-кандидата"></a>
### Reproduce the clipboard candidate checks

For the existing v1.25.1912.0 checkout with restored dependencies, use
[build/Test-ClipboardImage.ps1](build/Test-ClipboardImage.ps1) and
[build/Package-ClipboardCandidate.ps1](build/Package-ClipboardCandidate.ps1).
Copy both scripts and `build/clipboard-image-smoke.cpp` to one local Windows
directory. The test compiles the **production headers from SourceRoot**, including
CF_HDROP enumeration. It does not change the clipboard. Optional `-ReadClipboard`
reads the current bitmap and retains a local PNG; no bitmap means failure.

```powershell
.\Test-ClipboardImage.ps1 -SourceRoot 'C:\Users\Pavel\Projects\terminal-layout-fix' -OutputDirectory 'C:\Users\Pavel\Diagnostics\clipboard-smoke-new'
```

After smoke passes, build `src\cascadia\WindowsTerminal\WindowsTerminal.vcxproj`
in the VS developer shell with `/t:Build /p:Configuration=Release /p:Platform=x64`
and `/p:SolutionDir=<absolute checkout path ending in \>`; stop on nonzero
`$LASTEXITCODE`. A fresh checkout first needs section 4 dependencies. The package
helper does not build them.

```powershell
.\Package-ClipboardCandidate.ps1 -SourceRoot 'C:\Users\Pavel\Projects\terminal-layout-fix' -SettingsFile 'C:\Users\Pavel\AppData\Local\Programs\WT-Layout-Fix-1.25.1912.0\settings\settings.json' -Destination 'C:\Users\Pavel\AppData\Local\Programs\WT-Clipboard-New'
```

OutputDirectory and Destination must not exist. Packaging merges this tag's
exact PRI list through the upstream helper with native-error propagation, copies
and hashes the complete runtime, adds proxy/license/portable marker and only the
settings JSON. A package is not proof of a fresh build: bind source, build exit
and output hashes in a separate receipt. Recheck `_WTPrepareUnpackagedLayoutForRun`
when changing tags; never copy its resource list blindly. Agent test/build/package
commands still run under the machine-global heavy lock.

<a id="6-проверить-кандидата-до-переключения"></a>
## 6. Accept the candidate before switching

Compare the old working, new official and new patched (if needed) builds with
equivalent JSON copies, tabs and output volume. Product version and FileVersion
are different; record the full EXE path and PID. A new window does not prove a
separate process.

| Check | Acceptance |
| --- | --- |
| 2 → 10 → 20 empty CMD/PowerShell tabs, then Ubuntu | RU/EN causes no multi-second input freeze |
| Ten isolated layout changes with pauses, then a separate rapid series | No accumulating freezes; record the observed maximum delay |
| Change language in Notepad → return to Terminal; switch tabs | No former layout-change freeze |
| Normal workload and scrollback in working tabs | Improvement persists beyond empty test tabs |
| Tab color, light/dark, background/acrylic/opacity, settings reload | Colors update both on ordinary reload and after language changes |
| `+`, Ctrl+N; Ctrl+W on an empty split tab | New Ubuntu in `~`; close the entire selected tab |
| Split, resize, drag tab, search and command palette | No lost panes/focus or new failures |
| Fresh `codex`, `codex resume`, Claude | Type/paste `перевари тест`, Latin text and Ctrl/Shift+Enter correctly |
| Numpad decimal in Claude/Codex with Num Lock on | RU comma, EN period; Ubuntu keeps `compatibility.kittyKeyboardMode: false` |
| Fresh PrintScreen screenshot; 1 and 3 Explorer images (spaces/Cyrillic); text in each TUI | Every image attaches once, in order; text and single-image paste still work |
| Normal exit/relaunch after saving work | Expected tabs/panes return; agents must be started again |

Keep `CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT=1` during comparisons.
Removing it is a separate experiment after acceptance; a newer Terminal does
not prove a Codex fix. Do not submit test text to agents.
A zero build exit does not replace any manual acceptance check.

<a id="7-переключить-запуск-и-оставить-откат"></a>
## 7. Switch launch routing and retain rollback

Only after acceptance, save work, finish the necessary agents and close old
windows normally. Copy private state while the candidate is closed; verify
restoration again. If incompatible, keep the candidate's clean state and the
original backup; do not hand-edit state. Launch and pin the new EXE.

**HCA routing needs a separate change.** `_wt_resolve_terminal()` in
`~/hca-system-v3/modules/zsh/terminal/81-wt-split-panes.zsh` currently selects
`Programs/WT-Layout-Fix-1.25.1912.0`. Recheck the live implementation.
For a new portable build, update it to the verified directory together with
`tests/test-wt-commands.sh` and the HCA runbook; keep channel `layout-fix`.
Do not hide new binaries in a folder bearing an old version.

For an official **installed** Preview/Stable package, set
`settings.windows_terminal_channel: preview` or `stable` in HCA
`config/workspaces.yaml`. These packages have separate JSON files: reconcile
settings through the UI/reviewed diff. Taskbar pinning does not change HCA routing.

After an HCA routing edit, run `tests/test-wt-commands.sh` under the heavy lock,
then `source ~/.zshrc` and `wt-doctor` in a free Zsh.
Check `atreno`: one tab and one pane in the selected Terminal, no extra windows.

Rollback: close only new/test sessions normally, restore the prior HCA channel/
path and shortcut to the preserved EXE, and use the original settings copy.
Do not feed state migrated by a new release into the old one without verification.
Routing rollback requires no Windows/WSL restart.

<a id="8-зафиксировать-новую-резервную-копию"></a>
## 8. Record a new recovery release

Record the exact upstream tag/SHA, patch diff/SHA256 (or `patch not needed`),
tool versions, build/test exits and separate manual acceptance.
The private release contains the complete runtime, licenses, current JSON and
instructions. Exclude state, screen buffers, dumps, traces, credentials and binlogs.
The new tag/ZIP/SHA256/manifest must describe the **actual new archive**.
Verify extraction, inventory, sizes and hashes before publication.

`build/original-build-receipt.json` and `build/recovery-manifest.json` belong
to historical `layout-fix.1`; do not modify them for a configuration commit.
Use a separate receipt/manifest for a new release and update README links.
Do not replace an old published asset or reuse old manual acceptance as proof
for a new release. Pushing a Git commit does not publish a ZIP.
