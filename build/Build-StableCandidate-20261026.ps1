#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$Run,
    [string]$SourceRoot = 'C:\Users\Pavel\Source\terminal-v1.25.2733.0',
    [string]$GitExePath,
    [string]$VcpkgSeedReceiptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExpectedTag = 'v1.25.2733.0'
$ExpectedCommit = 'dc8ae365847d41f62d1ebca93815bb00959bc12f'
$WindowsTerminalBranding = 'Release'
$ExpectedVsInstallPath = 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools'
$VcpkgRepoUri = 'https://github.com/microsoft/vcpkg'
$VcpkgCacheRoot = Join-Path $env:LOCALAPPDATA 'TerminalLayoutFix\Tools\vcpkg'
# Run 2 hit the 260-character Windows path boundary with a 127-character Vcpkg root;
# this cap leaves room for the observed 133-character versioning-registry suffix.
$VcpkgMaxRootPathLength = 80
$VersioningCacheRoot = Join-Path $env:LOCALAPPDATA 'TerminalLayoutFix\Versioning'
$VersioningMaxPackageFilePathLength = 240
$MinGitVersion = '2.56.0.4'
$MinGitUri = 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/MinGit-2.56.0.4-64-bit.zip'
$MinGitSha256 = 'e3bf78351fe777fba47ddee5950082f8a98bb0f02604fdc7ba3ee2cb68ffa877'
$VersioningPackageId = 'Microsoft.Windows.Terminal.Versioning'
$VersioningPackageVersion = '0.5.240906013'
$VersioningPackageSha256 = 'ddcdf629c60f142fcd8bdb2ae005bdc79952240663f70499fffb1d40102ebc2b'
$VersioningTagVersion = $ExpectedTag.Substring(1)
$VersioningTagParts = @($VersioningTagVersion.Split('.'))
if ($VersioningTagParts.Count -ne 4 -or @($VersioningTagParts | Where-Object { $_ -notmatch '^\d+$' }).Count -gt 0) {
    throw "The expected source tag is not a four-part numeric version: $ExpectedTag"
}
$VersioningMajor = [int]$VersioningTagParts[0]
$VersioningMinor = [int]$VersioningTagParts[1]
$VersioningBuildNumber = [int]$VersioningTagParts[2]
$VersioningBuildRevision = [int]$VersioningTagParts[3]
$VersioningLocalProductVersion = "$VersioningTagVersion-local-layoutfix"
$VersioningFeedKey = 'TerminalDependencies'
$VersioningOverlayPropsName = 'Directory.Build.props'
$VersioningOverlayTargetsName = 'Directory.Build.targets'
$LogRoot = Join-Path $env:LOCALAPPDATA 'TerminalLayoutFix\BuildLogs\WT-v1.25.2733.0'
$SolutionRestoreTarget = 'OpenConsole.slnx'
$SharedRestoreTarget = 'dep\nuget\packages.config'
$PackageBuildTarget = 'Terminal\CascadiaPackage'
$TerminalCoreTestProject = 'src\cascadia\UnitTests_TerminalCore\UnitTests.vcxproj'
$TestDll = 'bin\x64\Release\UnitTests_TerminalCore\Terminal.Core.Unit.Tests.dll'
$TaefExe = 'packages\Microsoft.Taef.10.100.251104001\build\Binaries\x64\te.exe'

$ExpectedStatus = [ordered]@{
    'res/terminal.ico' = ' M'
    'src/cascadia/TerminalApp/TerminalAppLib.vcxproj' = ' M'
    'src/cascadia/TerminalApp/TerminalPage.cpp' = ' M'
    'src/cascadia/TerminalApp/TerminalPage.h' = ' M'
    'src/cascadia/TerminalApp/dll/TerminalApp.vcxproj' = ' M'
    'src/cascadia/TerminalControl/TermControl.cpp' = ' M'
    'src/cascadia/TerminalCore/Terminal.cpp' = ' M'
    'src/cascadia/TerminalCore/Terminal.hpp' = ' M'
    'src/cascadia/UnitTests_TerminalCore/TerminalApiTest.cpp' = ' M'
    'src/cascadia/TerminalApp/ClipboardFiles.h' = '??'
    'src/cascadia/TerminalApp/ClipboardImage.h' = '??'
}

$ExpectedSourceHashes = [ordered]@{
    'res/terminal.ico' = '6a0a1ab4c869add88fd38761d945563d35d4836751e2fd38c040a7329b10cade'
    'src/cascadia/TerminalApp/TerminalAppLib.vcxproj' = '4a0e19b3cecfa5b3918f71b01bb496757a009138e81d17d29d22a50224001611'
    'src/cascadia/TerminalApp/TerminalPage.cpp' = '1244f5459fc180ca6e53759af58b04b0c0d5177b3227604900af864190b6edf9'
    'src/cascadia/TerminalApp/TerminalPage.h' = 'be74cd1284822fe784dd81607d3777646ca810fa6d916d87c594629a2e64c417'
    'src/cascadia/TerminalApp/dll/TerminalApp.vcxproj' = '86c7b61659b99d2bfb468210ccea1b81f50f6ae310c49b67f57d40172f946cce'
    'src/cascadia/TerminalControl/TermControl.cpp' = '4fdd6aa1a62d6507bf4ff92a710b6a53493fb341b028e56cb58568fc8cfd3323'
    'src/cascadia/TerminalCore/Terminal.cpp' = '668e39077527ffdeb5d774a67d399a46667f91b4d2f91d620ed92e068d0dc48c'
    'src/cascadia/TerminalCore/Terminal.hpp' = '33eddaf6de362f030901d06ff67bd0a220dff57c571a87782b90282cf8ab12d6'
    'src/cascadia/UnitTests_TerminalCore/TerminalApiTest.cpp' = 'e3eacabf2096abc46ff01ae72c540545a433630fe8d1a7880a22381d2ddf975b'
    'src/cascadia/TerminalApp/ClipboardFiles.h' = '1c8547a9ec18603d6ed69e5e469f1a98986f4c85b031c8c7fef745b176008b77'
    'src/cascadia/TerminalApp/ClipboardImage.h' = '2ec2f844a73792635e8800a142f5dc169cb4e74590afe8a5c192380e4ea8f5cd'
}

function Get-GitValue {
    param([string[]]$GitArguments)
    $value = & $GitExe @GitArguments
    if ($LASTEXITCODE -ne 0) {
        throw "git.exe failed ($LASTEXITCODE): $($GitArguments -join ' ')"
    }
    return ($value -join "`n").Trim()
}

function Resolve-GitExecutable {
    param([string]$ExplicitPath)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $explicitFullPath = [System.IO.Path]::GetFullPath($ExplicitPath)
        if (-not (Test-Path -LiteralPath $explicitFullPath -PathType Leaf)) {
            throw "The supplied Git executable does not exist: $explicitFullPath"
        }
        return $explicitFullPath
    }

    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($command in @(Get-Command -Name 'git.exe' -All -ErrorAction SilentlyContinue)) {
        if ($command.CommandType -eq [System.Management.Automation.CommandTypes]::Application -and $command.Source) {
            $candidates.Add([string]$command.Source)
        }
    }

    $programFilesX86 = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ProgramFilesX86)
    $programFiles = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ProgramFiles)
    $roots = @($programFilesX86, $programFiles) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($root in $roots) {
        $candidates.Add((Join-Path $root 'Git\cmd\git.exe'))
        $candidates.Add((Join-Path $root 'Git\bin\git.exe'))
        $vsGitRoot = Join-Path $root 'Microsoft Visual Studio\18\BuildTools\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Git'
        $candidates.Add((Join-Path $vsGitRoot 'cmd\git.exe'))
        $candidates.Add((Join-Path $vsGitRoot 'mingw64\bin\git.exe'))
    }

    if ($env:LOCALAPPDATA) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe'))
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\git.exe'))
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Scoop\apps\git\current\cmd\git.exe'))
    }
    if ($env:USERPROFILE) {
        $candidates.Add((Join-Path $env:USERPROFILE 'scoop\apps\git\current\cmd\git.exe'))
    }
    $candidates.Add('C:\ProgramData\chocolatey\bin\git.exe')

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        try { $fullPath = [System.IO.Path]::GetFullPath($candidate) }
        catch { continue }
        if ($seen.Add($fullPath) -and (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            return $fullPath
        }
    }
    return $null
}

function Add-GitDirectoryToProcessPath {
    param([string]$ExecutablePath)

    $directory = [System.IO.Path]::GetDirectoryName($ExecutablePath)
    $env:PATH = "$directory;$env:PATH"
}

function Test-VcpkgRoot {
    param([string]$Root)
    if ([string]::IsNullOrWhiteSpace($Root)) { return $false }
    return (
        (Test-Path -LiteralPath (Join-Path $Root 'vcpkg.exe') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Root 'scripts\buildsystems\msbuild\vcpkg.props') -PathType Leaf)
    )
}

function Test-VcpkgCheckout {
    param([string]$Root)
    if ([string]::IsNullOrWhiteSpace($Root)) { return $false }
    return (
        (Test-Path -LiteralPath (Join-Path $Root '.git') -PathType Container) -and
        (Test-Path -LiteralPath (Join-Path $Root 'scripts\buildsystems\msbuild\vcpkg.props') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Root 'bootstrap-vcpkg.bat') -PathType Leaf)
    )
}

function Test-VcpkgRootPathLength {
    param([string]$Root)
    if ([string]::IsNullOrWhiteSpace($Root)) { return $false }
    try { $fullPath = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') }
    catch { return $false }
    return $fullPath.Length -le $VcpkgMaxRootPathLength
}

function Get-AppxManifestFacts {
    param([Parameter(Mandatory)][string]$Path)

    [xml]$manifest = Get-Content -LiteralPath $Path -Raw
    $identity = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
    if ($null -eq $identity) { throw "The Appx manifest has no Package/Identity element: $Path" }
    $aliases = @($manifest.SelectNodes("//*[local-name()='ExecutionAlias']") | ForEach-Object {
        [string]$_.GetAttribute('Alias')
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    return [ordered]@{
        identityName = [string]$identity.GetAttribute('Name')
        identityVersion = [string]$identity.GetAttribute('Version')
        executionAliases = $aliases
    }
}

function Assert-CandidateSource {
    param([switch]$CheckStatus)

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        throw "Source checkout does not exist: $SourceRoot"
    }
    if ($SourceRoot -notmatch '^[A-Za-z]:\\') {
        throw 'SourceRoot must be a local Windows drive path, not a WSL or UNC path.'
    }

    $head = Get-GitValue -GitArguments @('-C', $SourceRoot, 'rev-parse', 'HEAD')
    if ($head -ne $ExpectedCommit) {
        throw "Unexpected source HEAD: $head (expected $ExpectedCommit)."
    }
    $tag = Get-GitValue -GitArguments @('-C', $SourceRoot, 'describe', '--tags', '--exact-match', 'HEAD')
    if ($tag -ne $ExpectedTag) {
        throw "Unexpected source tag: $tag (expected $ExpectedTag)."
    }

    if ($CheckStatus) {
        $statusLines = @(& $GitExe -C $SourceRoot status --porcelain=v1 --untracked-files=all)
        if ($LASTEXITCODE -ne 0) { throw "git status failed with exit code $LASTEXITCODE." }
        $actualStatus = @{}
        foreach ($line in $statusLines) {
            if ($line.Length -lt 4) { throw "Unrecognized git status line: $line" }
            $actualStatus[$line.Substring(3)] = $line.Substring(0, 2)
        }
        if ($actualStatus.Count -ne $ExpectedStatus.Count) {
            throw "Source status has $($actualStatus.Count) entries; expected $($ExpectedStatus.Count) patch files only."
        }
        foreach ($path in $ExpectedStatus.Keys) {
            if (-not $actualStatus.ContainsKey($path) -or $actualStatus[$path] -ne $ExpectedStatus[$path]) {
                throw "Unexpected or missing candidate patch state: $path"
            }
        }
    }

    foreach ($path in $ExpectedSourceHashes.Keys) {
        $absolutePath = Join-Path $SourceRoot ($path -replace '/', '\')
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            throw "Expected candidate source file is missing: $path"
        }
        $actualHash = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $ExpectedSourceHashes[$path]) {
            throw "Candidate source hash changed: $path"
        }
    }
}

$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
$GitExe = Resolve-GitExecutable -ExplicitPath $GitExePath
if (-not $GitExe) {
    $missingGitPlan = [ordered]@{
        mode = if ($Run) { 'run' } else { 'plan-only' }
        preflightStatus = 'MISSING_GIT'
        sourceValidation = 'NOT_RUN_GIT_UNAVAILABLE'
        gitExecutable = $null
        missingPrerequisite = 'Windows git.exe is not resolvable from PATH, standard user/system Git locations, Scoop/Chocolatey locations, or the Visual Studio 18 Build Tools Git locations checked.'
        minGitVersion = $MinGitVersion
        minGitAsset = $MinGitUri
        minGitSha256 = $MinGitSha256
        minGitSizeBytes = 39846926
        suggestedPrivatePath = (Join-Path $env:LOCALAPPDATA 'TerminalLayoutFix\Tools\MinGit-2.56.0.4')
        suggestedGitExeArgument = '-GitExePath <MinGitRoot>\cmd\git.exe'
        extractionNote = 'Extract the verified ZIP under the suggested user-local directory; the build recipe prepends cmd to PATH only inside its own PowerShell process.'
        receipt = 'NOT_CREATED_NO_BUILD_OR_RESTORE_STARTED'
    }
    if (-not $Run) {
        $missingGitPlan | ConvertTo-Json -Depth 5
        Write-Error 'Git is missing; source validation and build phases did not run. Extract the SHA-256-verified MinGit asset and rerun this plan with -GitExePath.'
    }
    throw "Git is missing; source validation and build phases did not run. Use MinGit x64 $MinGitVersion ($MinGitSha256) at $MinGitUri, then pass -GitExePath."
}

# This only affects this PowerShell process and children it starts; it does not
# write the user or machine PATH. The VS helper and MSBuild can therefore use
# the same resolved Git executable.
Add-GitDirectoryToProcessPath -ExecutablePath $GitExe
Assert-CandidateSource -CheckStatus

$VcpkgManifestPath = Join-Path $SourceRoot 'vcpkg.json'
if (-not (Test-Path -LiteralPath $VcpkgManifestPath -PathType Leaf)) {
    throw "Tagged vcpkg manifest is missing: $VcpkgManifestPath"
}
$VcpkgManifest = Get-Content -LiteralPath $VcpkgManifestPath -Raw | ConvertFrom-Json
$VcpkgBaseline = [string]$VcpkgManifest.'builtin-baseline'
if ($VcpkgBaseline -notmatch '^[0-9a-fA-F]{40}$') {
    throw 'The tagged vcpkg.json does not contain a 40-character builtin-baseline commit.'
}

$VcpkgSeedRoot = $null
$VcpkgSeedCommit = $null
$VcpkgSeedReceipt = $null
if (-not [string]::IsNullOrWhiteSpace($VcpkgSeedReceiptPath)) {
    if ($VcpkgSeedReceiptPath -notmatch '^[A-Za-z]:\\') {
        throw 'VcpkgSeedReceiptPath must be a local Windows drive path.'
    }
    $VcpkgSeedReceiptPath = [System.IO.Path]::GetFullPath($VcpkgSeedReceiptPath)
    if (-not (Test-Path -LiteralPath $VcpkgSeedReceiptPath -PathType Leaf)) {
        throw "The supplied Vcpkg seed receipt does not exist: $VcpkgSeedReceiptPath"
    }
    try {
        $VcpkgSeedReceipt = Get-Content -LiteralPath $VcpkgSeedReceiptPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "The supplied Vcpkg seed receipt is not valid JSON: $VcpkgSeedReceiptPath"
    }
    if ([string]$VcpkgSeedReceipt.tag -ne $ExpectedTag) {
        throw "The supplied Vcpkg seed receipt is for an unexpected Terminal tag: $($VcpkgSeedReceipt.tag)"
    }
    $seedBootstrapPhases = @($VcpkgSeedReceipt.phases | Where-Object { $_.name -eq 'vcpkg-bootstrap' })
    if ($seedBootstrapPhases.Count -ne 1 -or $seedBootstrapPhases[0].status -ne 'SUCCEEDED' -or $seedBootstrapPhases[0].exitCode -ne 0) {
        throw 'The supplied receipt does not prove one successful Vcpkg bootstrap phase.'
    }
    $seedRootValue = [string]$VcpkgSeedReceipt.vcpkgRoot
    if ([string]::IsNullOrWhiteSpace($seedRootValue)) {
        throw 'The supplied receipt does not record a Vcpkg root.'
    }
    $VcpkgSeedRoot = [System.IO.Path]::GetFullPath($seedRootValue).TrimEnd('\')
    if (-not (Test-VcpkgRoot -Root $VcpkgSeedRoot)) {
        throw 'The Vcpkg seed root recorded in the receipt is missing required Vcpkg files.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $VcpkgSeedRoot '.git') -PathType Container)) {
        throw 'The Vcpkg seed root does not contain its Git metadata.'
    }
    $VcpkgSeedCommit = Get-GitValue -GitArguments @('-C', $VcpkgSeedRoot, 'rev-parse', 'HEAD')
    if ($VcpkgSeedCommit -ne [string]$VcpkgSeedReceipt.vcpkgToolCommit) {
        throw 'The Vcpkg seed checkout commit does not match its receipt.'
    }
    $seedOrigin = (Get-GitValue -GitArguments @('-C', $VcpkgSeedRoot, 'remote', 'get-url', 'origin')).TrimEnd('/')
    if ($seedOrigin -match '\.git$') { $seedOrigin = $seedOrigin.Substring(0, $seedOrigin.Length - 4) }
    if ($seedOrigin -ine $VcpkgRepoUri) {
        throw 'The Vcpkg seed checkout origin is not the expected Microsoft repository.'
    }
}

$Plan = [ordered]@{
    mode = if ($Run) { 'run' } else { 'plan-only' }
    sourceRoot = $SourceRoot
    gitExe = $GitExe
    gitDirectoryForChildProcesses = [System.IO.Path]::GetDirectoryName($GitExe)
    tag = $ExpectedTag
    commit = $ExpectedCommit
    windowsTerminalBranding = $WindowsTerminalBranding
    upstreamVersioningPackageId = $VersioningPackageId
    upstreamVersioningPackageVersion = $VersioningPackageVersion
    upstreamVersioningPackageSha256 = $VersioningPackageSha256
    versioningPackageInstallRoot = 'Unique per-run directory under %LOCALAPPDATA%\TerminalLayoutFix\Versioning; the longest pinned package file path is guarded at 240 characters.'
    appxIdentityVersion = $VersioningTagVersion
    unpackagedAboutProductVersion = $VersioningLocalProductVersion
    versioningSetupScriptInvoked = $false
    versioningOverlay = 'Unique run-local Directory.Build.props/.targets imports original source files first and pinned upstream versioning files second; WAP IntDir is bound to IntermediateOutputPath only for .wapproj; GeneratedVersionInputs points at the run-local props file.'
    expectedPatchFiles = $ExpectedStatus.Keys
    expectedPatchFileSha256 = $ExpectedSourceHashes
    vcpkgBuiltinBaseline = $VcpkgBaseline
    vcpkgRootSetup = 'Before restore, use an explicitly validated seed receipt when supplied; otherwise reuse a complete short-path VCPKG_ROOT or selected VS root, then the validated short user-local cache, and clone the tag pipeline repository there only if needed.'
    vcpkgCacheRoot = $VcpkgCacheRoot
    vcpkgMaxRootPathLength = $VcpkgMaxRootPathLength
    vcpkgSeedReceipt = $VcpkgSeedReceiptPath
    vcpkgSeedToolCommit = $VcpkgSeedCommit
    phases = @(
        'Update git submodules only if the pinned tag contains .gitmodules (this tag has none)'
        'Resolve a Vcpkg root no longer than 80 characters; reuse the validated local cache or seed it from an explicit successful receipt before any remote clone'
        'Run bootstrap-vcpkg.bat only when the selected short-path root lacks vcpkg.exe'
        'Install the tag-pipeline Microsoft.Windows.Terminal.Versioning package in a unique short-path user-local directory, verify its SHA-256, and evaluate the tag-derived version properties without running Setup.ps1 or changing source-root Directory.Build files'
        'Restore OpenConsole.slnx with dep\nuget\nuget.exe'
        'Restore dep\nuget\packages.config with dep\nuget\nuget.exe'
        'Back up and invalidate only a recognized stale generated Release appx manifest after restore; fail closed for any unrecognized manifest'
        'Build OpenConsole.slnx target Terminal\CascadiaPackage, Release/x64, WindowsTerminalBranding=Release, tag-derived manifest/file versions, unsigned, /m:2'
        'Verify generated Release package identity/alias and PE fixed/localized version resources before the tests'
        'Build src\cascadia\UnitTests_TerminalCore\UnitTests.vcxproj, Release/x64, WindowsTerminalBranding=Release, same tag-derived version properties, /m:2'
        'Run the tagged Invoke-OpenConsoleTests terminalCore x64 Release test selection'
    )
    msbuildWorkers = 2
    output = 'Tagged source build outputs plus a user-local Vcpkg bootstrap when needed; no Visual Studio or Terminal installation, app launch, live replacement, or routing change.'
    localLogs = $LogRoot
    requiresInstalledVisualStudioAt = $ExpectedVsInstallPath
    noVisualStudioInstall = $true
    noTerminalInstall = $true
    noLaunch = $true
    changesLiveTerminal = $false
}

if (-not $Run) {
    $Plan | ConvertTo-Json -Depth 7
    Write-Output 'Plan only: source identity/status/hashes were checked; no logs, restore, build, or tests were run.'
    exit 0
}

$NuGetExe = Join-Path $SourceRoot 'dep\nuget\nuget.exe'
if (-not (Test-Path -LiteralPath $NuGetExe -PathType Leaf)) {
    throw "Tagged NuGet executable is missing: $NuGetExe"
}
if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $SolutionRestoreTarget) -PathType Leaf)) {
    throw "Tagged solution is missing: $SolutionRestoreTarget"
}
if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $SharedRestoreTarget) -PathType Leaf)) {
    throw "Tagged shared NuGet package list is missing: $SharedRestoreTarget"
}

$RunId = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N'))
$RunDirectory = Join-Path $LogRoot $RunId
if (Test-Path -LiteralPath $RunDirectory) {
    throw "Refusing to overwrite an existing build receipt directory: $RunDirectory"
}
New-Item -ItemType Directory -Path $RunDirectory -ErrorAction Stop | Out-Null
$ReceiptPath = Join-Path $RunDirectory 'build-receipt.json'
$Receipt = [ordered]@{
    schemaVersion = 1
    runId = $RunId
    status = 'PREFLIGHT_PASSED'
    startedUtc = [DateTime]::UtcNow.ToString('o')
    finishedUtc = $null
    sourceRoot = $SourceRoot
    gitExe = $GitExe
    gitDirectoryForChildProcesses = [System.IO.Path]::GetDirectoryName($GitExe)
    tag = $ExpectedTag
    commit = $ExpectedCommit
    windowsTerminalBranding = $WindowsTerminalBranding
    vcpkgBuiltinBaseline = $VcpkgBaseline
    vcpkgRoot = $null
    vcpkgRootSource = $null
    vcpkgToolCommit = $null
    vcpkgSeedReceipt = $VcpkgSeedReceiptPath
    vcpkgSeedRoot = $VcpkgSeedRoot
    patchFileSha256 = $ExpectedSourceHashes
    phases = [System.Collections.Generic.List[object]]::new()
    versioningPackage = $null
    staleAppxManifest = $null
    packageIdentity = $null
    applicationVersions = $null
    noVisualStudioInstall = $true
    noTerminalInstall = $true
    noLaunch = $true
    noLiveReplacement = $true
    failure = $null
}

function Save-Receipt {
    $json = $Receipt | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText(
        $ReceiptPath,
        $json,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Add-SkippedPhase {
    param([string]$Name, [string]$Reason)
    $Receipt.phases.Add([ordered]@{
        name = $Name
        status = 'SKIPPED'
        reason = $Reason
        exitCode = $null
        startedUtc = $null
        finishedUtc = [DateTime]::UtcNow.ToString('o')
    })
    Save-Receipt
}

function Invoke-LoggedProcess {
    param(
        [string]$Name,
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    $stdoutPath = Join-Path $RunDirectory "$Name.stdout.log"
    $stderrPath = Join-Path $RunDirectory "$Name.stderr.log"
    $phase = [ordered]@{
        name = $Name
        status = 'RUNNING'
        executable = $Executable
        arguments = $Arguments
        workingDirectory = $WorkingDirectory
        startedUtc = [DateTime]::UtcNow.ToString('o')
        finishedUtc = $null
        exitCode = $null
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        failure = $null
    }
    $Receipt.phases.Add($phase)
    Save-Receipt

    $process = [System.Diagnostics.Process]::new()
    $stdoutStream = $null
    $stderrStream = $null
    try {
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $Executable
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in $Arguments) {
            [void]$startInfo.ArgumentList.Add([string]$argument)
        }
        $process.StartInfo = $startInfo
        $stdoutStream = [System.IO.File]::Create($stdoutPath)
        $stderrStream = [System.IO.File]::Create($stderrPath)
        if (-not $process.Start()) { throw "Could not start $Executable." }
        $stdoutCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
        $stderrCopy = $process.StandardError.BaseStream.CopyToAsync($stderrStream)
        $process.WaitForExit()
        [System.Threading.Tasks.Task]::WaitAll(
            [System.Threading.Tasks.Task[]]@($stdoutCopy, $stderrCopy)
        )
        $phase.exitCode = $process.ExitCode
        $phase.status = if ($process.ExitCode -eq 0) { 'SUCCEEDED' } else { 'FAILED' }
    }
    catch {
        $phase.status = 'START_OR_CAPTURE_FAILED'
        $phase.failure = $_.Exception.Message
        throw
    }
    finally {
        $phase.finishedUtc = [DateTime]::UtcNow.ToString('o')
        if ($null -ne $stdoutStream) { $stdoutStream.Dispose() }
        if ($null -ne $stderrStream) { $stderrStream.Dispose() }
        $process.Dispose()
        Save-Receipt
    }

    if ($phase.exitCode -ne 0) {
        throw "Build phase '$Name' failed with exit code $($phase.exitCode). See $stdoutPath and $stderrPath."
    }
}

try {
    Save-Receipt
    if (Test-Path -LiteralPath (Join-Path $SourceRoot '.gitmodules') -PathType Leaf) {
        Invoke-LoggedProcess -Name 'submodule-update' -Executable $GitExe `
            -Arguments @('-C', $SourceRoot, 'submodule', 'update', '--init', '--recursive') `
            -WorkingDirectory $SourceRoot
    }
    else {
        Add-SkippedPhase -Name 'submodule-update' -Reason 'The pinned tag has no .gitmodules file.'
    }

    # Keep PowerShell and native child processes on NTFS. Push-Location alone
    # may leave CMD inheriting the WSL UNC process CWD.
    [System.Environment]::CurrentDirectory = $SourceRoot
    Set-Location -LiteralPath $SourceRoot
    Import-Module (Join-Path $SourceRoot 'tools\OpenConsole.psm1') -Force
    Set-MsBuildDevEnvironment
    $selectedVs = ([string]$env:VSINSTALLDIR).TrimEnd('\')
    if ($selectedVs -ine $ExpectedVsInstallPath.TrimEnd('\')) {
        throw "The tagged helper selected '$selectedVs'; expected '$ExpectedVsInstallPath'."
    }
    $MsBuildExe = (Get-Command msbuild.exe -ErrorAction Stop).Source
    $PwshExe = (Get-Command pwsh.exe -ErrorAction Stop).Source
    $Receipt.selectedVsInstallPath = $selectedVs
    $Receipt.msbuildExe = $MsBuildExe

    $VersioningConfigPath = Join-Path $SourceRoot 'NuGet.Config'
    if (-not (Test-Path -LiteralPath $VersioningConfigPath -PathType Leaf)) {
        throw "The tagged NuGet configuration is missing: $VersioningConfigPath"
    }
    [xml]$versioningConfig = Get-Content -LiteralPath $VersioningConfigPath -Raw
    $versioningFeedSources = @($versioningConfig.configuration.packageSources.add | Where-Object {
        [string]$_.key -eq $VersioningFeedKey
    })
    if ($versioningFeedSources.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$versioningFeedSources[0].value)) {
        throw "The tagged NuGet.Config must define exactly one '$VersioningFeedKey' package source."
    }
    $VersioningInstallRoot = Join-Path $VersioningCacheRoot $RunId
    if (Test-Path -LiteralPath $VersioningInstallRoot) {
        throw "The unique versioning package directory already exists: $VersioningInstallRoot"
    }
    $VersioningTargetPathProbe = Join-Path (Join-Path $VersioningInstallRoot "$VersioningPackageId.$VersioningPackageVersion") `
        'build\Microsoft.Windows.Terminal.Versioning.csproj.win32res.targets'
    $VersioningTargetPathLength = [System.IO.Path]::GetFullPath($VersioningTargetPathProbe).Length
    if ($VersioningTargetPathLength -gt $VersioningMaxPackageFilePathLength) {
        throw "The pinned versioning package extraction path is too long for the tagged NuGet client ($VersioningTargetPathLength characters; maximum $VersioningMaxPackageFilePathLength): $VersioningTargetPathProbe"
    }
    if (-not (Test-Path -LiteralPath $VersioningCacheRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $VersioningCacheRoot -ErrorAction Stop | Out-Null
    }
    New-Item -ItemType Directory -Path $VersioningInstallRoot -ErrorAction Stop | Out-Null
    $Receipt.versioningPackage = [ordered]@{
        status = 'INSTALLING'
        packageId = $VersioningPackageId
        version = $VersioningPackageVersion
        sha256 = $VersioningPackageSha256
        packageSourceName = $VersioningFeedKey
        packageSourceUri = [string]$versioningFeedSources[0].value
        installRoot = $VersioningInstallRoot
        maximumPackageFilePathLength = $VersioningMaxPackageFilePathLength
        pinnedPackageFilePathProbe = $VersioningTargetPathProbe
        pinnedPackageFilePathLength = $VersioningTargetPathLength
        packageRoot = $null
        setupScriptInvoked = $false
        overlayPropsPath = $null
        overlayTargetsPath = $null
        generatedVersionInputs = $null
        appxIdentityVersion = $VersioningTagVersion
        unpackagedAboutProductVersion = $VersioningLocalProductVersion
    }
    Save-Receipt
    Invoke-LoggedProcess -Name 'install-terminal-versioning' -Executable $NuGetExe `
        -Arguments @(
            'install',
            $VersioningPackageId,
            '-Version', $VersioningPackageVersion,
            '-OutputDirectory', $VersioningInstallRoot,
            '-ConfigFile', $VersioningConfigPath,
            '-PackageSaveMode', 'nuspec;nupkg',
            '-NonInteractive'
        ) -WorkingDirectory $SourceRoot

    $VersioningNupkgCandidates = @(Get-ChildItem -LiteralPath $VersioningInstallRoot `
        -Filter "$VersioningPackageId.$VersioningPackageVersion.nupkg" -File -Recurse)
    if ($VersioningNupkgCandidates.Count -ne 1) {
        throw "NuGet preserved $($VersioningNupkgCandidates.Count) copies of the pinned versioning package archive; expected exactly one."
    }
    $VersioningNupkgPath = $VersioningNupkgCandidates[0].FullName
    $VersioningPackageRoot = Split-Path -Parent $VersioningNupkgPath
    $actualVersioningPackageSha256 = (Get-FileHash -LiteralPath $VersioningNupkgPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualVersioningPackageSha256 -ne $VersioningPackageSha256) {
        $Receipt.versioningPackage.status = 'FAILED_SHA256_MISMATCH'
        $Receipt.versioningPackage.actualSha256 = $actualVersioningPackageSha256
        Save-Receipt
        throw "The versioning package SHA-256 differs from the pinned package: $actualVersioningPackageSha256"
    }
    $VersioningNuspecPath = Join-Path $VersioningPackageRoot "$VersioningPackageId.nuspec"
    if (-not (Test-Path -LiteralPath $VersioningNuspecPath -PathType Leaf)) {
        throw "The installed versioning package nuspec is missing: $VersioningNuspecPath"
    }
    [xml]$versioningNuspec = Get-Content -LiteralPath $VersioningNuspecPath -Raw
    $versioningMetadata = $versioningNuspec.SelectSingleNode("/*[local-name()='package']/*[local-name()='metadata']")
    if ($null -eq $versioningMetadata -or
        [string]$versioningMetadata.id -ne $VersioningPackageId -or
        [string]$versioningMetadata.version -ne $VersioningPackageVersion) {
        throw 'The installed versioning package metadata does not match the pinned package ID and version.'
    }

    $VersioningPropsPath = Join-Path $VersioningPackageRoot 'build\Microsoft.Windows.Terminal.Versioning.props'
    $VersioningTargetsPath = Join-Path $VersioningPackageRoot 'build\Microsoft.Windows.Terminal.Versioning.targets'
    foreach ($requiredVersioningFile in @($VersioningPropsPath, $VersioningTargetsPath)) {
        if (-not (Test-Path -LiteralPath $requiredVersioningFile -PathType Leaf)) {
            throw "The pinned versioning package is missing a required MSBuild file: $requiredVersioningFile"
        }
    }

    $VersioningOverlayDirectory = Join-Path $RunDirectory 'versioning-overlay'
    if (Test-Path -LiteralPath $VersioningOverlayDirectory) {
        throw "The unique versioning overlay directory already exists: $VersioningOverlayDirectory"
    }
    New-Item -ItemType Directory -Path $VersioningOverlayDirectory -ErrorAction Stop | Out-Null
    $VersioningOverlayPropsPath = Join-Path $VersioningOverlayDirectory $VersioningOverlayPropsName
    $VersioningOverlayTargetsPath = Join-Path $VersioningOverlayDirectory $VersioningOverlayTargetsName
    $SourceDirectoryBuildPropsPath = Join-Path $SourceRoot 'Directory.Build.props'
    $SourceDirectoryBuildTargetsPath = Join-Path $SourceRoot 'Directory.Build.targets'
    $versioningImportPaths = @(
        $SourceDirectoryBuildPropsPath,
        $VersioningPropsPath,
        $SourceDirectoryBuildTargetsPath,
        $VersioningTargetsPath
    ) | ForEach-Object { [System.Security.SecurityElement]::Escape($_) }
    $overlayPropsText = @"
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$($versioningImportPaths[0])" Condition="Exists('$($versioningImportPaths[0])')" />
  <Import Project="$($versioningImportPaths[1])" />
</Project>
"@
    $overlayTargetsText = @"
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$($versioningImportPaths[2])" Condition="Exists('$($versioningImportPaths[2])')" />
  <PropertyGroup Condition="'`$(MSBuildProjectExtension)' == '.wapproj' and '`$(IntDir)' == ''">
    <IntDir>`$(IntermediateOutputPath)</IntDir>
  </PropertyGroup>
  <Import Project="$($versioningImportPaths[3])" />
</Project>
"@
    [System.IO.File]::WriteAllText($VersioningOverlayPropsPath, $overlayPropsText, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($VersioningOverlayTargetsPath, $overlayTargetsText, [System.Text.UTF8Encoding]::new($false))
    $Receipt.versioningPackage.status = 'PACKAGE_HASH_AND_METADATA_VERIFIED'
    $Receipt.versioningPackage.packageRoot = $VersioningPackageRoot
    $Receipt.versioningPackage.overlayPropsPath = $VersioningOverlayPropsPath
    $Receipt.versioningPackage.overlayTargetsPath = $VersioningOverlayTargetsPath
    $Receipt.versioningPackage.generatedVersionInputs = $VersioningOverlayPropsPath
    $Receipt.versioningPackage.tagVersionParts = [ordered]@{
        major = $VersioningMajor
        minor = $VersioningMinor
        build = $VersioningBuildNumber
        revision = $VersioningBuildRevision
    }
    Save-Receipt

    $WapProjectPath = Join-Path $SourceRoot 'src\cascadia\CascadiaPackage\CascadiaPackage.wapproj'
    $ExpectedWapManifestPath = Join-Path $SourceRoot 'src\cascadia\CascadiaPackage\bin\x64\Release\AppxManifest.xml'
    $VersioningEvaluationName = 'evaluate-terminal-versioning'
    Invoke-LoggedProcess -Name $VersioningEvaluationName -Executable $MsBuildExe `
        -Arguments @(
            $WapProjectPath,
            '-nologo',
            '-getProperty:WindowsTerminalBranding,VersionMajor,VersionMinor,VersionBuildNumber,VersionBuildRevision,XefAppxManifestVersion,XefFileStringVersion,NuGetPackVersion,ProductStringVersion,IntDir,IntermediateOutputPath,FinalAppxManifestName,DirectoryBuildPropsPath,DirectoryBuildTargetsPath,GeneratedVersionInputs',
            '-getItem:AppxManifest',
            '/p:Configuration=Release',
            '/p:Platform=x64',
            "/p:WindowsTerminalBranding=$WindowsTerminalBranding",
            "/p:VersionMajor=$VersioningMajor",
            "/p:VersionMinor=$VersioningMinor",
            "/p:VersionBuildNumber=$VersioningBuildNumber",
            "/p:VersionBuildRevision=$VersioningBuildRevision",
            "/p:XefAppxManifestVersion=$VersioningTagVersion",
            "/p:NuGetPackVersion=$VersioningLocalProductVersion",
            "/p:ProductStringVersion=$VersioningLocalProductVersion",
            "/p:GeneratedVersionInputs=$VersioningOverlayPropsPath",
            "/p:DirectoryBuildPropsPath=$VersioningOverlayPropsPath",
            "/p:DirectoryBuildTargetsPath=$VersioningOverlayTargetsPath"
        ) -WorkingDirectory $SourceRoot

    $versioningEvaluationPath = Join-Path $RunDirectory "$VersioningEvaluationName.stdout.log"
    $versioningEvaluation = Get-Content -LiteralPath $versioningEvaluationPath -Raw | ConvertFrom-Json
    $versioningProperties = $versioningEvaluation.Properties
    $expectedVersioningProperties = [ordered]@{
        WindowsTerminalBranding = $WindowsTerminalBranding
        VersionMajor = [string]$VersioningMajor
        VersionMinor = [string]$VersioningMinor
        VersionBuildNumber = [string]$VersioningBuildNumber
        VersionBuildRevision = [string]$VersioningBuildRevision
        XefAppxManifestVersion = $VersioningTagVersion
        XefFileStringVersion = '{0}.{1}.{2}.{3:00000}' -f $VersioningMajor, $VersioningMinor, $VersioningBuildNumber, $VersioningBuildRevision
        NuGetPackVersion = $VersioningLocalProductVersion
        ProductStringVersion = $VersioningLocalProductVersion
        IntDir = 'obj\x64\Release\'
        IntermediateOutputPath = 'obj\x64\Release\'
        FinalAppxManifestName = [System.IO.Path]::GetFullPath($ExpectedWapManifestPath)
        DirectoryBuildPropsPath = [System.IO.Path]::GetFullPath($VersioningOverlayPropsPath)
        DirectoryBuildTargetsPath = [System.IO.Path]::GetFullPath($VersioningOverlayTargetsPath)
        GeneratedVersionInputs = [System.IO.Path]::GetFullPath($VersioningOverlayPropsPath)
    }
    foreach ($propertyName in $expectedVersioningProperties.Keys) {
        $actualValue = [string]$versioningProperties.$propertyName
        if ($propertyName -match 'Path$|IntDir|IntermediateOutputPath') {
            $actualValue = $actualValue.Replace('/', '\')
        }
        if ($actualValue -ine [string]$expectedVersioningProperties[$propertyName]) {
            throw "Versioning preflight property '$propertyName' is '$actualValue'; expected '$($expectedVersioningProperties[$propertyName])'."
        }
    }
    $appxManifestItems = @($versioningEvaluation.Items.AppxManifest)
    if ($appxManifestItems.Count -ne 1 -or
        [string]$appxManifestItems[0].Identity -ne 'Package.appxmanifest' -or
        [string]$appxManifestItems[0].FullPath -ine (Join-Path $SourceRoot 'src\cascadia\CascadiaPackage\Package.appxmanifest')) {
        throw 'Versioning preflight did not select the stable Package.appxmanifest source item.'
    }
    $VersioningIntermediateManifestPath = Join-Path (
        Join-Path $SourceRoot 'src\cascadia\CascadiaPackage'
    ) (Join-Path $versioningProperties.IntDir 'GeneratedPackage.appxmanifest')
    $VersioningIntermediateManifestPath = [System.IO.Path]::GetFullPath($VersioningIntermediateManifestPath)
    $ExpectedVersioningIntermediateManifestPath = [System.IO.Path]::GetFullPath((Join-Path $SourceRoot 'src\cascadia\CascadiaPackage\obj\x64\Release\GeneratedPackage.appxmanifest'))
    if ($VersioningIntermediateManifestPath -ine $ExpectedVersioningIntermediateManifestPath) {
        throw "The versioning Appx target path is unexpected: $VersioningIntermediateManifestPath"
    }
    $Receipt.versioningPackage.status = 'EVALUATION_VERIFIED'
    $Receipt.versioningPackage.evaluationLog = $versioningEvaluationPath
    $Receipt.versioningPackage.intermediateManifestPath = $VersioningIntermediateManifestPath
    $Receipt.versioningPackage.evaluationProperties = $expectedVersioningProperties
    $Receipt.versioningPackage.manifestSourceItem = [string]$appxManifestItems[0].FullPath
    Save-Receipt

    $VcpkgCandidates = @(
        [ordered]@{ path = [string]$env:VCPKG_ROOT; source = 'inherited VCPKG_ROOT' }
        [ordered]@{ path = (Join-Path $selectedVs 'VC\vcpkg'); source = 'selected Visual Studio VC\vcpkg' }
    )
    $VcpkgToolCommit = $null
    $VcpkgRootSource = $null
    $overlongRoots = @($VcpkgCandidates | Where-Object {
        (Test-VcpkgRoot -Root $_.path) -and -not (Test-VcpkgRootPathLength -Root $_.path)
    })
    if ($overlongRoots.Count -gt 0) {
        Add-SkippedPhase -Name 'vcpkg-long-root-rejected' -Reason "A complete existing Vcpkg root exceeded the $VcpkgMaxRootPathLength-character root limit required to leave room for versioning registry paths."
    }
    $VcpkgSelection = if ([string]::IsNullOrWhiteSpace($VcpkgSeedReceiptPath)) {
        $VcpkgCandidates | Where-Object {
            (Test-VcpkgRoot -Root $_.path) -and (Test-VcpkgRootPathLength -Root $_.path)
        } | Select-Object -First 1
    }
    else {
        $null
    }
    if ($null -ne $VcpkgSelection) {
        $VcpkgRoot = [System.IO.Path]::GetFullPath($VcpkgSelection.path).TrimEnd('\')
        $VcpkgRootSource = $VcpkgSelection.source
        if (Test-Path -LiteralPath (Join-Path $VcpkgRoot '.git')) {
            $VcpkgToolCommit = Get-GitValue -GitArguments @('-C', $VcpkgRoot, 'rev-parse', 'HEAD')
        }
        Add-SkippedPhase -Name 'vcpkg-clone' -Reason "Using existing valid Vcpkg root from $VcpkgRootSource."
        Add-SkippedPhase -Name 'vcpkg-bootstrap' -Reason 'The selected Vcpkg root already contains vcpkg.exe and its MSBuild props.'
    }
    else {
        $VcpkgRoot = [System.IO.Path]::GetFullPath($VcpkgCacheRoot).TrimEnd('\')
        if (-not (Test-VcpkgRootPathLength -Root $VcpkgRoot)) {
            throw "The configured user-local Vcpkg cache exceeds the $VcpkgMaxRootPathLength-character safe root limit: $VcpkgRoot"
        }

        if (Test-Path -LiteralPath $VcpkgRoot) {
            if (-not (Test-VcpkgCheckout -Root $VcpkgRoot)) {
                throw "The Vcpkg cache path exists but is not a complete Git checkout; refusing to overwrite it: $VcpkgRoot"
            }
            $VcpkgToolCommit = Get-GitValue -GitArguments @('-C', $VcpkgRoot, 'rev-parse', 'HEAD')
            $cacheOrigin = (Get-GitValue -GitArguments @('-C', $VcpkgRoot, 'remote', 'get-url', 'origin')).TrimEnd('/')
            if ($cacheOrigin -match '\.git$') { $cacheOrigin = $cacheOrigin.Substring(0, $cacheOrigin.Length - 4) }
            if ($cacheOrigin -ine $VcpkgRepoUri) {
                throw 'The existing short-path Vcpkg cache has an unexpected origin; refusing to reuse it.'
            }
            if ($VcpkgSeedCommit -and $VcpkgToolCommit -ne $VcpkgSeedCommit) {
                throw 'The existing short-path Vcpkg cache does not match the explicitly supplied seed receipt commit.'
            }
            $VcpkgRootSource = if ($VcpkgSeedCommit) {
                'validated short-path cache matching the explicitly supplied seed receipt'
            }
            else {
                'validated short-path user-local cache'
            }
            Add-SkippedPhase -Name 'vcpkg-clone' -Reason "Reusing validated short-path cache at $VcpkgRoot."
        }
        elseif ($VcpkgSeedRoot) {
            Invoke-LoggedProcess -Name 'vcpkg-seed-clone' -Executable $GitExe `
                -Arguments @('clone', '--local', $VcpkgSeedRoot, $VcpkgRoot) -WorkingDirectory $SourceRoot
            $VcpkgToolCommit = Get-GitValue -GitArguments @('-C', $VcpkgRoot, 'rev-parse', 'HEAD')
            if ($VcpkgToolCommit -ne $VcpkgSeedCommit) {
                throw 'The short-path Vcpkg clone does not match the explicitly validated seed receipt commit.'
            }
            Invoke-LoggedProcess -Name 'vcpkg-cache-origin' -Executable $GitExe `
                -Arguments @('-C', $VcpkgRoot, 'remote', 'set-url', 'origin', $VcpkgRepoUri) -WorkingDirectory $SourceRoot
            $VcpkgRootSource = "local clone from validated Vcpkg receipt commit $VcpkgSeedCommit"
        }
        else {
            Invoke-LoggedProcess -Name 'vcpkg-clone' -Executable $GitExe `
                -Arguments @('clone', $VcpkgRepoUri, $VcpkgRoot) -WorkingDirectory $SourceRoot
            $VcpkgRootSource = 'tag pipeline fallback: cloned microsoft/vcpkg into the short-path user-local cache'
            $VcpkgToolCommit = Get-GitValue -GitArguments @('-C', $VcpkgRoot, 'rev-parse', 'HEAD')
        }
        $Receipt.vcpkgRoot = $VcpkgRoot
        $Receipt.vcpkgRootSource = $VcpkgRootSource
        $Receipt.vcpkgToolCommit = $VcpkgToolCommit
        Save-Receipt

        if (Test-VcpkgRoot -Root $VcpkgRoot) {
            Add-SkippedPhase -Name 'vcpkg-bootstrap' -Reason 'The validated short-path cache already contains vcpkg.exe and its MSBuild props.'
        }
        else {
            $BootstrapBatch = Join-Path $VcpkgRoot 'bootstrap-vcpkg.bat'
            if (-not (Test-Path -LiteralPath $BootstrapBatch -PathType Leaf)) {
                throw "The Vcpkg checkout is missing its bootstrap script: $BootstrapBatch"
            }
            $BootstrapRunnerPath = Join-Path $RunDirectory 'run-vcpkg-bootstrap.ps1'
            $BootstrapRunnerContent = @'
param([Parameter(Mandatory)][string]$VcpkgRoot)
$ErrorActionPreference = 'Stop'
[System.Environment]::CurrentDirectory = $VcpkgRoot
Set-Location -LiteralPath $VcpkgRoot
& (Join-Path $VcpkgRoot 'bootstrap-vcpkg.bat')
$bootstrapExit = $LASTEXITCODE
if ($null -eq $bootstrapExit) { throw 'bootstrap-vcpkg.bat did not leave a native exit code.' }
exit [int]$bootstrapExit
'@
            [System.IO.File]::WriteAllText(
                $BootstrapRunnerPath,
                $BootstrapRunnerContent,
                [System.Text.UTF8Encoding]::new($false)
            )
            Invoke-LoggedProcess -Name 'vcpkg-bootstrap' -Executable $PwshExe `
                -Arguments @('-NoProfile', '-File', $BootstrapRunnerPath, '-VcpkgRoot', $VcpkgRoot) `
                -WorkingDirectory $VcpkgRoot
        }
    }

    if (-not (Test-VcpkgRoot -Root $VcpkgRoot) -or -not (Test-VcpkgRootPathLength -Root $VcpkgRoot)) {
        throw "Selected Vcpkg root is incomplete; expected vcpkg.exe and scripts\buildsystems\msbuild\vcpkg.props: $VcpkgRoot"
    }
    $env:VCPKG_ROOT = $VcpkgRoot
    if (-not $VcpkgToolCommit -and (Test-Path -LiteralPath (Join-Path $VcpkgRoot '.git'))) {
        $VcpkgToolCommit = Get-GitValue -GitArguments @('-C', $VcpkgRoot, 'rev-parse', 'HEAD')
    }
    $Receipt.vcpkgRoot = $VcpkgRoot
    $Receipt.vcpkgRootSource = $VcpkgRootSource
    $Receipt.vcpkgToolCommit = $VcpkgToolCommit
    $Receipt.vcpkgRootForChildProcesses = $env:VCPKG_ROOT
    $Receipt.msbuildExe = $MsBuildExe
    Save-Receipt

    Invoke-LoggedProcess -Name 'restore-solution' -Executable $NuGetExe `
        -Arguments @('restore', $SolutionRestoreTarget) -WorkingDirectory $SourceRoot
    Invoke-LoggedProcess -Name 'restore-shared-packages' -Executable $NuGetExe `
        -Arguments @('restore', $SharedRestoreTarget) -WorkingDirectory $SourceRoot

    $AppxManifestPath = [System.IO.Path]::GetFullPath($ExpectedWapManifestPath)
    $StaleAppxManifestBackupPath = Join-Path $RunDirectory 'stale-generated-AppxManifest.before-invalidation.xml'
    if (-not (Test-Path -LiteralPath $AppxManifestPath -PathType Leaf)) {
        $Receipt.staleAppxManifest = [ordered]@{
            status = 'ABSENT_BEFORE_BUILD'
            sourcePath = $AppxManifestPath
            backupPath = $null
            sha256 = $null
            identity = $null
        }
    }
    else {
        $manifestItem = Get-Item -LiteralPath $AppxManifestPath -Force
        if (($manifestItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "The generated Appx manifest is a reparse point; refusing to remove it: $AppxManifestPath"
        }
        $existingManifestFacts = Get-AppxManifestFacts -Path $AppxManifestPath
        $existingManifestSha256 = (Get-FileHash -LiteralPath $AppxManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $isExpectedReleaseManifest = (
            $existingManifestFacts.identityName -ceq 'Microsoft.WindowsTerminal' -and
            $existingManifestFacts.identityVersion -ceq $VersioningTagVersion -and
            @($existingManifestFacts.executionAliases).Count -eq 1 -and
            [string]$existingManifestFacts.executionAliases[0] -ceq 'wt.exe'
        )
        if ($isExpectedReleaseManifest) {
            $Receipt.staleAppxManifest = [ordered]@{
                status = 'ALREADY_EXPECTED_RELEASE_MANIFEST'
                sourcePath = $AppxManifestPath
                backupPath = $null
                sha256 = $existingManifestSha256
                identity = $existingManifestFacts
            }
        }
        else {
            $isKnownStaleDevManifest = (
                $existingManifestFacts.identityName -ceq 'WindowsTerminalDev' -and
                $existingManifestFacts.identityVersion -ceq '0.0.1.0' -and
                @($existingManifestFacts.executionAliases).Count -eq 1 -and
                [string]$existingManifestFacts.executionAliases[0] -ceq 'wtd.exe'
            )
            $isKnownStaleUnversionedReleaseManifest = (
                $existingManifestFacts.identityName -ceq 'Microsoft.WindowsTerminal' -and
                $existingManifestFacts.identityVersion -ceq '1.0.0.0' -and
                @($existingManifestFacts.executionAliases).Count -eq 1 -and
                [string]$existingManifestFacts.executionAliases[0] -ceq 'wt.exe'
            )
            if (-not ($isKnownStaleDevManifest -or $isKnownStaleUnversionedReleaseManifest)) {
                throw "The generated Appx manifest has an unrecognized identity/version/alias; refusing to remove it: $AppxManifestPath"
            }
            if (Test-Path -LiteralPath $StaleAppxManifestBackupPath) {
                throw "The stale Appx manifest evidence path already exists: $StaleAppxManifestBackupPath"
            }
            $Receipt.staleAppxManifest = [ordered]@{
                status = 'BACKUP_IN_PROGRESS'
                sourcePath = $AppxManifestPath
                backupPath = $StaleAppxManifestBackupPath
                sha256 = $existingManifestSha256
                identity = $existingManifestFacts
            }
            Save-Receipt
            Copy-Item -LiteralPath $AppxManifestPath -Destination $StaleAppxManifestBackupPath -ErrorAction Stop
            $backupManifestSha256 = (Get-FileHash -LiteralPath $StaleAppxManifestBackupPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($backupManifestSha256 -ne $existingManifestSha256) {
                throw "The copied stale Appx manifest hash differs from the source: $StaleAppxManifestBackupPath"
            }
            $currentManifestSha256 = (Get-FileHash -LiteralPath $AppxManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($currentManifestSha256 -ne $existingManifestSha256) {
                throw "The generated Appx manifest changed after backup; refusing to remove it: $AppxManifestPath"
            }
            $Receipt.staleAppxManifest = [ordered]@{
                status = 'BACKUP_HASH_VERIFIED'
                sourcePath = $AppxManifestPath
                backupPath = $StaleAppxManifestBackupPath
                sha256 = $existingManifestSha256
                identity = $existingManifestFacts
            }
            Save-Receipt
            Remove-Item -LiteralPath $AppxManifestPath -ErrorAction Stop
            if (Test-Path -LiteralPath $AppxManifestPath) {
                throw "The recognized stale generated Appx manifest still exists after removal: $AppxManifestPath"
            }
            $Receipt.staleAppxManifest.status = 'BACKED_UP_AND_INVALIDATED'
        }
    }
    Save-Receipt

    Invoke-LoggedProcess -Name 'build-terminal-package' -Executable $MsBuildExe `
        -Arguments @(
            $SolutionRestoreTarget,
            "/t:$PackageBuildTarget",
            '/p:Configuration=Release',
            '/p:Platform=x64',
            '/p:AppxPackageSigningEnabled=false',
            "/p:WindowsTerminalBranding=$WindowsTerminalBranding",
            "/p:VersionMajor=$VersioningMajor",
            "/p:VersionMinor=$VersioningMinor",
            "/p:VersionBuildNumber=$VersioningBuildNumber",
            "/p:VersionBuildRevision=$VersioningBuildRevision",
            "/p:XefAppxManifestVersion=$VersioningTagVersion",
            "/p:NuGetPackVersion=$VersioningLocalProductVersion",
            "/p:ProductStringVersion=$VersioningLocalProductVersion",
            "/p:GeneratedVersionInputs=$VersioningOverlayPropsPath",
            "/p:DirectoryBuildPropsPath=$VersioningOverlayPropsPath",
            "/p:DirectoryBuildTargetsPath=$VersioningOverlayTargetsPath",
            '/m:2',
            "/bl:$(Join-Path $RunDirectory 'terminal-package.binlog')"
        ) -WorkingDirectory $SourceRoot

    $GeneratedAppxManifestFacts = Get-AppxManifestFacts -Path $AppxManifestPath
    if ($GeneratedAppxManifestFacts.identityName -cne 'Microsoft.WindowsTerminal' -or
        $GeneratedAppxManifestFacts.identityVersion -cne $VersioningTagVersion -or
        @($GeneratedAppxManifestFacts.executionAliases).Count -ne 1 -or
        [string]$GeneratedAppxManifestFacts.executionAliases[0] -cne 'wt.exe') {
        throw "The generated package manifest is not the expected stable identity/version/alias: $AppxManifestPath"
    }
    $TerminalAppDllPath = Join-Path $SourceRoot 'src\cascadia\CascadiaPackage\bin\x64\Release\TerminalApp.dll'
    $WindowsTerminalExePath = Join-Path $SourceRoot 'src\cascadia\CascadiaPackage\bin\x64\Release\WindowsTerminal.exe'
    $verifiedApplicationVersions = [System.Collections.Generic.List[object]]::new()
    foreach ($versionedBinaryPath in @($TerminalAppDllPath, $WindowsTerminalExePath)) {
        if (-not (Test-Path -LiteralPath $versionedBinaryPath -PathType Leaf)) {
            throw "The versioned package binary is missing: $versionedBinaryPath"
        }
        $binaryVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($versionedBinaryPath)
        if ($binaryVersion.FileMajorPart -ne $VersioningMajor -or
            $binaryVersion.FileMinorPart -ne $VersioningMinor -or
            $binaryVersion.FileBuildPart -ne $VersioningBuildNumber -or
            $binaryVersion.FilePrivatePart -ne $VersioningBuildRevision -or
            [string]$binaryVersion.ProductVersion -cne $VersioningLocalProductVersion) {
            throw "The binary version resources do not match the tag and local About version: $versionedBinaryPath"
        }
        $verifiedApplicationVersions.Add([ordered]@{
            path = $versionedBinaryPath
            fileVersion = [string]$binaryVersion.FileVersion
            productVersion = [string]$binaryVersion.ProductVersion
            fileVersionParts = @(
                $binaryVersion.FileMajorPart,
                $binaryVersion.FileMinorPart,
                $binaryVersion.FileBuildPart,
                $binaryVersion.FilePrivatePart
            )
        })
    }
    $Receipt.packageIdentity = [ordered]@{
        manifestPath = $AppxManifestPath
        manifestSha256 = (Get-FileHash -LiteralPath $AppxManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        identity = $GeneratedAppxManifestFacts
    }
    $Receipt.applicationVersions = $verifiedApplicationVersions.ToArray()
    Save-Receipt

    Invoke-LoggedProcess -Name 'build-terminalcore-tests' -Executable $MsBuildExe `
        -Arguments @(
            $TerminalCoreTestProject,
            '/t:Build',
            '/p:Configuration=Release',
            '/p:Platform=x64',
            "/p:WindowsTerminalBranding=$WindowsTerminalBranding",
            "/p:VersionMajor=$VersioningMajor",
            "/p:VersionMinor=$VersioningMinor",
            "/p:VersionBuildNumber=$VersioningBuildNumber",
            "/p:VersionBuildRevision=$VersioningBuildRevision",
            "/p:XefAppxManifestVersion=$VersioningTagVersion",
            "/p:NuGetPackVersion=$VersioningLocalProductVersion",
            "/p:ProductStringVersion=$VersioningLocalProductVersion",
            "/p:GeneratedVersionInputs=$VersioningOverlayPropsPath",
            "/p:DirectoryBuildPropsPath=$VersioningOverlayPropsPath",
            "/p:DirectoryBuildTargetsPath=$VersioningOverlayTargetsPath",
            "/p:SolutionDir=$SourceRoot\",
            '/m:2',
            "/bl:$(Join-Path $RunDirectory 'terminalcore-tests.binlog')"
        ) -WorkingDirectory $SourceRoot

    $testDllPath = Join-Path $SourceRoot $TestDll
    $taefPath = Join-Path $SourceRoot $TaefExe
    if (-not (Test-Path -LiteralPath $testDllPath -PathType Leaf)) {
        throw "Tagged Terminal Core test DLL was not produced: $testDllPath"
    }
    if (-not (Test-Path -LiteralPath $taefPath -PathType Leaf)) {
        throw "Tagged TAEF test runner is missing after restore: $taefPath"
    }

        $testRunnerPath = Join-Path $RunDirectory 'run-terminalcore-tests.ps1'
        $testRunnerContent = @'
param([Parameter(Mandatory)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $SourceRoot 'tools\OpenConsole.psm1') -Force
[System.Environment]::CurrentDirectory = $SourceRoot
Set-Location -LiteralPath $SourceRoot
$global:LASTEXITCODE = 0
Invoke-OpenConsoleTests -Test terminalCore -Platform x64 -Configuration Release
$testExit = $global:LASTEXITCODE
if ($null -eq $testExit) { throw 'The tagged test helper did not leave a native test exit code.' }
exit [int]$testExit
'@
        [System.IO.File]::WriteAllText(
            $testRunnerPath,
            $testRunnerContent,
            [System.Text.UTF8Encoding]::new($false)
        )
        $Receipt.testDllPath = $testDllPath
        $Receipt.taefPath = $taefPath
        $Receipt.testRunnerPath = $testRunnerPath
        Save-Receipt
        Invoke-LoggedProcess -Name 'test-terminalcore' -Executable $PwshExe `
            -Arguments @('-NoProfile', '-File', $testRunnerPath, '-SourceRoot', $SourceRoot) `
            -WorkingDirectory $SourceRoot

    Assert-CandidateSource
    $Receipt.status = 'BUILT_AND_TESTED'
    $Receipt.finishedUtc = [DateTime]::UtcNow.ToString('o')
    Save-Receipt
    Write-Output "Build and Terminal Core tests passed. Receipt and local logs: $RunDirectory"
    Write-Output 'No app was launched, registered, installed, or copied over a live Terminal path.'
}
catch {
    $Receipt.status = 'FAILED'
    $Receipt.finishedUtc = [DateTime]::UtcNow.ToString('o')
    $Receipt.failure = $_.Exception.Message
    if ($null -ne $Receipt.versioningPackage -and $Receipt.versioningPackage.status -eq 'INSTALLING') {
        $Receipt.versioningPackage.status = 'FAILED'
        $Receipt.versioningPackage.failure = $_.Exception.Message
    }
    Save-Receipt
    throw
}
