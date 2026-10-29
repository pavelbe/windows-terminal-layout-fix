#Requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$TerminalRoot,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [switch]$RequireDiagnostics
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new()
Set-StrictMode -Version Latest
$exe = Join-Path $TerminalRoot 'WindowsTerminal.exe'
if (Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Where-Object Path -EQ $exe) {
    throw 'Use an isolated, inactive test runtime.'
}
if (Test-Path $EvidenceDirectory) { throw 'Use a new evidence directory.' }
$settings = Get-Content (Join-Path $TerminalRoot 'settings\settings.json') -Raw | ConvertFrom-Json
if ($settings.defaultProfile -ne '{6f3ef6ab-cde4-478c-b5ca-6844c23e65b5}' -or
    $settings.firstWindowPreference -ne 'defaultProfile' -or
    $settings.windowingBehavior -ne 'useNew' -or $settings.profiles.defaults.closeOnExit -ne 'graceful') {
    throw 'Refusing non-fixture settings.'
}
$null = New-Item -ItemType Directory $EvidenceDirectory
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$fixture = Join-Path $EvidenceDirectory 'child.ps1'
@'
param([string]$Gate, [string]$Ready, [int]$ExitCode)
[IO.File]::WriteAllText($Ready, $env:WT_SESSION)
Write-Host ('LF FIXTURE ' + [IO.Path]::GetFileName($Ready))
while (!(Test-Path -LiteralPath $Gate)) { Start-Sleep -Milliseconds 50 }
exit $ExitCode
'@ | Set-Content -LiteralPath $fixture -Encoding utf8

function Wait-For([scriptblock]$Condition, [string]$Description) {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timeout: $Description"
}
function Get-Documents($Process) {
    $Process.Refresh()
    $handle = $Process.MainWindowHandle
    if ($Process.HasExited -or $handle -eq [IntPtr]::Zero) { return }
    $window = [Windows.Automation.AutomationElement]::FromHandle($handle)
    $condition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ClassNameProperty, 'TermControl')
    $elements = $window.FindAll([Windows.Automation.TreeScope]::Descendants, $condition)
    foreach ($element in $elements) { Write-Output -NoEnumerate $element }
}
function Stop-FixtureProcess($Process) {
    $Process.Refresh()
    if ($Process.HasExited) { return }
    if ($Process.Path -ne $exe) { throw 'Fixture process identity changed.' }
    # The observed error pane intentionally remains open. Cleanup is not a
    # window-close assertion: terminate only this newly launched fixture.
    if (!$Process.WaitForExit(500)) { $Process.Kill() }
    if (!$Process.WaitForExit(10000)) { throw 'Owned fixture process did not exit.' }
}

$results = @()
foreach ($name in @('success', 'failure', 'immediate-failure')) {
    $code = if ($name -eq 'success') { 0 } else { 1 }
    $anchorGate = Join-Path $EvidenceDirectory "anchor-$name.stop"
    $splitGate = Join-Path $EvidenceDirectory "split-$name.stop"
    $anchorReady = Join-Path $EvidenceDirectory "anchor-$name.ready"
    $splitReady = Join-Path $EvidenceDirectory "split-$name.ready"
    if ($name -eq 'immediate-failure') { [IO.File]::WriteAllText($splitGate, '') }
    $argsLine = '-w new new-tab --title LF-LIFECYCLE-TEST --suppressApplicationTitle powershell.exe -NoProfile -File "{0}" -Gate "{1}" -Ready "{2}" -ExitCode 0 ; split-pane -H --title LF-EXIT-{5} --suppressApplicationTitle powershell.exe -NoProfile -File "{0}" -Gate "{3}" -Ready "{4}" -ExitCode {5}' -f $fixture, $anchorGate, $anchorReady, $splitGate, $splitReady, $code
    $process = Start-Process -FilePath $exe -ArgumentList $argsLine -PassThru
    try {
        Wait-For { (Test-Path $anchorReady) -and (Test-Path $splitReady) } 'both real ConPTY children ready'
        $process.Refresh()
        if ($process.Path -ne $exe) { throw 'Unexpected process identity.' }
        Wait-For { @(Get-Documents $process).Count -eq 2 } 'two split terminal documents'
        $session = (Get-Content $splitReady -Raw).Trim()
        if ($session -notmatch '^[0-9a-fA-F-]{36}$') { throw 'Missing WT_SESSION fixture identity.' }
        [IO.File]::WriteAllText($splitGate, '')
        $expectedCount = if ($code -eq 0) { 1 } else { 2 }
        Wait-For {
            $documents = @(Get-Documents $process)
            if ($documents.Count -ne $expectedCount) { return $false }
            foreach ($document in $documents) {
                $pattern = $null
                if ($document.TryGetCurrentPattern([Windows.Automation.TextPattern]::Pattern, [ref]$pattern)) {
                    $text = $pattern.DocumentRange.GetText(-1)
                    if ($code -eq 0 -and $text.Contains("LF FIXTURE anchor-$name.ready")) { return $true }
                    if ($code -eq 1 -and $text.Contains('0x00000001')) { return $true }
                }
            }
            return $false
        } "exit $code pane count and error text"
        $log = Join-Path $env:LOCALAPPDATA 'TerminalLayoutFix\Diagnostics\connection-events.log'
        $logged = $false
        if (Test-Path $log) {
            $events = @(Get-Content $log | Where-Object { $_.Contains(" session={$session} ") })
            $logged = $events.Count -eq 2 -and $events[0] -match 'event=started code=0 ' -and
                $events[0] -notmatch 'child=0 ' -and $events[1] -match "event=exited code=$code "
        }
        $results += [ordered]@{ name = $name; exitCode = $code; documents = $expectedCount; session = $session; terminalPid = $process.Id; loggedInOrder = $logged }
    }
    finally {
        [IO.File]::WriteAllText($anchorGate, '')
        [IO.File]::WriteAllText($splitGate, '')
        Stop-FixtureProcess $process
    }
}
$log = Join-Path $env:LOCALAPPDATA 'TerminalLayoutFix\Diagnostics\connection-events.log'
$priorLines = if (Test-Path $log) { @(Get-Content $log).Count } else { 0 }
$process = Start-Process -FilePath $exe -ArgumentList '-w new new-tab --title LF-LAUNCH-FAILURE --suppressApplicationTitle lf-missing-executable-218b8566.exe' -PassThru
try {
    Wait-For {
        $process.Refresh()
        if ($process.Path -ne $exe) { throw 'Unexpected process identity.' }
        $documents = @(Get-Documents $process)
        if ($documents.Count -ne 1) { return $false }
        $pattern = $null
        if ($documents[0].TryGetCurrentPattern([Windows.Automation.TextPattern]::Pattern, [ref]$pattern)) {
            return $pattern.DocumentRange.GetText(-1).Contains('0x80070002')
        }
        return $false
    } 'failed launch remains visible with file-not-found HRESULT'
    $events = @()
    if (Test-Path $log) { $events = @(Get-Content $log | Select-Object -Skip $priorLines | Where-Object { $_ -match " pid=$($process.Id) " }) }
    $logged = $events.Count -eq 1 -and $events[0] -match 'event=launch-failed code=2147942402 '
    $results += [ordered]@{ name = 'launch-failure'; exitCode = '0x80070002'; documents = 1; terminalPid = $process.Id; loggedInOrder = $logged }
}
finally {
    Stop-FixtureProcess $process
}
$results | ConvertTo-Json | Set-Content (Join-Path $EvidenceDirectory 'result.json')
$results | ConvertTo-Json
if ($RequireDiagnostics -and @($results | Where-Object { !$_.loggedInOrder }).Count) {
    throw 'Missing persisted lifecycle evidence for observed shell exits.'
}
