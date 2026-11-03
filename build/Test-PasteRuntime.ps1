#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TerminalRoot,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [string]$VsInstallPath = 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools',
    [ValidateNotNullOrEmpty()]
    [ValidateSet('text-broadcast', 'bitmap-broadcast', 'delayed-tab', 'delayed-last-pane')]
    [string[]]$Cases = @('text-broadcast', 'bitmap-broadcast', 'delayed-tab', 'delayed-last-pane')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$exe = Join-Path $TerminalRoot 'WindowsTerminal.exe'
if (!(Test-Path -LiteralPath (Join-Path $TerminalRoot '.portable') -PathType Leaf)) {
    throw 'Fixture runtime requires its adjacent .portable marker before any writes or launches.'
}
$fixtureSettings = Join-Path $TerminalRoot 'settings\settings.json'
$settings = Get-Content -LiteralPath $fixtureSettings -Raw | ConvertFrom-Json
if ($settings.defaultProfile -ne '{6f3ef6ab-cde4-478c-b5ca-6844c23e65b5}' -or
    $settings.windowingBehavior -ne 'useNew' -or $settings.profiles.list.Count -ne 1 -or
    $settings.profiles.list[0].name -ne 'LF paste witness') {
    throw 'Use only the isolated paste-fixture runtime and synthetic settings.'
}
if (Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Where-Object Path -EQ $exe) {
    throw 'Fixture runtime is already active.'
}
if (Test-Path -LiteralPath $EvidenceDirectory) { throw 'Use a new evidence directory.' }
$null = New-Item -ItemType Directory -Path $EvidenceDirectory
Set-Location -LiteralPath $EvidenceDirectory
[Environment]::CurrentDirectory = $EvidenceDirectory
Import-Module (Join-Path $VsInstallPath 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $VsInstallPath -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
$fixture = Join-Path $EvidenceDirectory 'paste-runtime-fixture.exe'
& cl.exe /nologo /std:c++20 /EHsc /W4 /WX /utf-8 (Join-Path $PSScriptRoot 'paste-runtime-fixture.cpp') "/Fe:$fixture" /link user32.lib gdi32.lib
if ($LASTEXITCODE -ne 0) { throw 'Native paste witness compilation failed.' }
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LFPasteKeys {
    [StructLayout(LayoutKind.Sequential)]
    public struct GuiThreadInfo {
        public uint size, flags;
        public IntPtr active, focus, capture, menuOwner, moveSize, caret;
        public int left, top, right, bottom;
    }
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll")] private static extern bool GetGUIThreadInfo(uint thread, ref GuiThreadInfo info);
    [DllImport("user32.dll")] private static extern bool IsChild(IntPtr parent, IntPtr window);
    [DllImport("user32.dll")] private static extern uint MapVirtualKey(uint key, uint type);
    [DllImport("user32.dll")] private static extern bool PostMessage(IntPtr window, uint message, IntPtr key, IntPtr data);
    public static IntPtr OwnedFocus(IntPtr window, uint expectedProcess) {
        uint process;
        var thread = GetWindowThreadProcessId(window, out process);
        if (thread == 0 || process != expectedProcess) throw new InvalidOperationException("Lost owned window.");
        var info = new GuiThreadInfo { size = (uint)Marshal.SizeOf<GuiThreadInfo>() };
        if (!GetGUIThreadInfo(thread, ref info) || info.focus == IntPtr.Zero ||
            !(info.focus == window || IsChild(window, info.focus))) throw new InvalidOperationException("No owned focus child.");
        GetWindowThreadProcessId(info.focus, out process);
        if (process != expectedProcess) throw new InvalidOperationException("Focus child belongs to another process.");
        return info.focus;
    }
    public static void SendToOwnedChild(IntPtr window, IntPtr child, uint expectedProcess, uint key) {
        uint process;
        GetWindowThreadProcessId(child, out process);
        if (child == IntPtr.Zero || process != expectedProcess ||
            !(child == window || IsChild(window, child))) throw new InvalidOperationException("Lost owned focus child.");
        long data = 1 | ((long)MapVirtualKey(key, 0) << 16);
        if (!PostMessage(child, 0x100, (IntPtr)key, (IntPtr)data) ||
            !PostMessage(child, 0x101, (IntPtr)key, (IntPtr)(data | 0xC0000000L)))
            throw new InvalidOperationException("Owned child key delivery failed.");
    }
}
'@
function Wait-For([scriptblock]$Condition, [string]$Description) {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 50
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timeout: $Description"
}
function Get-Elements($Process, [string]$ClassName) {
    $Process.Refresh()
    if ($Process.HasExited -or $Process.MainWindowHandle -eq [IntPtr]::Zero) { return }
    $window = [Windows.Automation.AutomationElement]::FromHandle($Process.MainWindowHandle)
    $condition = if ($ClassName -eq 'TabViewItem') {
        [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::TabItem)
    } else {
        [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ClassNameProperty, $ClassName)
    }
    foreach ($item in $window.FindAll([Windows.Automation.TreeScope]::Descendants, $condition)) {
        Write-Output -NoEnumerate $item
    }
}
function Send-Key($Process, [int]$Key) {
    $Process.Refresh()
    if ($Process.HasExited -or $Process.Path -ine $exe) { throw 'Lost owned fixture window.' }
    $window = $Process.MainWindowHandle
    $null = [LFPasteKeys]::SetForegroundWindow($window)
    Wait-For { [LFPasteKeys]::GetForegroundWindow() -eq $window } 'owned fixture foreground window'
    foreach ($modifier in @(0x10, 0x11, 0x12, 0x5B, 0x5C)) {
        if ([LFPasteKeys]::GetAsyncKeyState($modifier) -lt 0) { throw 'User modifier held; refusing fixture input.' }
    }
    $child = [LFPasteKeys]::OwnedFocus($window, [uint32]$Process.Id)
    [LFPasteKeys]::SendToOwnedChild($window, $child, [uint32]$Process.Id, [uint32]$Key)
}
function Assert-SelectedTab($Process, [int]$Index, [int]$Count) {
    Wait-For {
        $tabs = @(Get-Elements $Process 'TabViewItem')
        if ($tabs.Count -ne $Count) { return $false }
        $selection = $tabs[$Index].GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern)
        return $selection.Current.IsSelected
    } "selected tab $Index of $Count"
}
function Stop-Owned($Process, [string]$ExpectedPath) {
    if ($null -eq $Process) { return }
    $Process.Refresh()
    if ($Process.HasExited) { return }
    if ($Process.Path -ine $ExpectedPath) { throw 'Fixture process identity changed.' }
    if (!$Process.WaitForExit(1500)) { $Process.Kill() }
    if (!$Process.WaitForExit(10000)) { throw 'Owned fixture did not exit.' }
}
function Read-Witness([string]$Directory, [string]$Name) {
    $path = Join-Path $Directory "$Name.bin"
    $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8)
    try { return $reader.ReadToEnd() }
    finally { $reader.Dispose() }
}

$results = @()
foreach ($case in $Cases) {
    $caseRoot = Join-Path $EvidenceDirectory $case
    $null = New-Item -ItemType Directory -Path $caseRoot
    $single = $case -eq 'delayed-last-pane'
    $bitmap = $case -eq 'bitmap-broadcast'
    $token = 'LF-PASTE-' + [guid]::NewGuid().ToString('N')
    $provider = $null
    $terminal = $null
    try {
        $command = '-w new new-tab --title LF-PASTE-WITNESS --suppressApplicationTitle "{0}" receive "{1}" bracketed A' -f $fixture, $caseRoot
        if (!$single) {
            $command += ' ; split-pane -V --title LF-PASTE-WITNESS --suppressApplicationTitle "{0}" receive "{1}" plain B' -f $fixture, $caseRoot
        }
        $command += ' ; new-tab --title LF-PASTE-OTHER --suppressApplicationTitle "{0}" receive "{1}" plain C' -f $fixture, $caseRoot
        $terminal = Start-Process -FilePath $exe -ArgumentList $command -PassThru
        Wait-For { (Test-Path "$caseRoot\A.ready") -and (Test-Path "$caseRoot\C.ready") -and
            ($single -or (Test-Path "$caseRoot\B.ready")) } 'real ConPTY recipients ready'
        Assert-SelectedTab $terminal 1 2
        Send-Key $terminal 0x75 # F6: broadcast on the other tab too.
        Send-Key $terminal 0x74 # F5: original tab.
        Assert-SelectedTab $terminal 0 2
        Send-Key $terminal 0x75 # F6: broadcast on the original tab.
        $kind = if ($bitmap) { 'bitmap' } else { 'text' }
        $provider = Start-Process -FilePath $fixture -ArgumentList ('provide "{0}" {1} {2}' -f $caseRoot, $kind, $token) -PassThru -WindowStyle Hidden
        Wait-For { Test-Path "$caseRoot\provider.ready" } 'synthetic clipboard owner ready'
        if ($case -in @('text-broadcast', 'bitmap-broadcast')) { [IO.File]::WriteAllText("$caseRoot\release", '') }
        Send-Key $terminal 0x76 # F7: real Terminal paste action.
        Wait-For { Test-Path "$caseRoot\requested" } 'clipboard render requested by Terminal'
        if ($case -eq 'delayed-tab') {
            Send-Key $terminal 0x77 # F8: switch while GetClipboardData is blocked.
            Assert-SelectedTab $terminal 1 2
        }
        elseif ($single) {
            Send-Key $terminal 0x78 # F9: move the last source pane to tab 1.
            Assert-SelectedTab $terminal 0 1
            Wait-For { @(Get-Elements $terminal 'TermControl').Count -eq 2 } 'moved pane and target pane present'
        }
        [IO.File]::WriteAllText("$caseRoot\release", '')
        Wait-For { Test-Path "$caseRoot\rendered" } 'synthetic data rendered'
        $source = if ($single) { 'A' } else { 'B' }
        Wait-For { (Read-Witness $caseRoot $source).Length -gt 0 } 'source received paste'
        if (!$single) {
            Wait-For { (Read-Witness $caseRoot 'A').Length -gt 0 -or (Read-Witness $caseRoot 'C').Length -gt 0 } 'broadcast destination received paste'
        }
        # Drain queued dispatch before asserting the unrelated recipient stayed empty.
        Start-Sleep -Milliseconds 500
        $a = Read-Witness $caseRoot 'A'
        $c = Read-Witness $caseRoot 'C'
        if ($c.Length -ne 0) { throw 'OTHER_TAB: unrelated recipient received paste.' }
        $body = if ($single) { $a.Substring(6, $a.Length - 12) } else { Read-Witness $caseRoot 'B' }
        if ($bitmap) {
            if ($body -notmatch '^"([^"\r\n]+\.png)"$' -or !(Test-Path -LiteralPath $Matches[1])) {
                throw 'BITMAP_PATH: expected exactly one quoted existing PNG path.'
            }
            $png = [IO.File]::ReadAllBytes($Matches[1])
            if ([Convert]::ToHexString($png[0..7]) -ne '89504E470D0A1A0A') { throw 'BITMAP_PATH: PNG signature differs.' }
        }
        elseif ($body -cne $token) { throw 'SOURCE_DATA: delayed or broadcast paste body differs.' }
        if ($a -cne ("`e[200~" + $body + "`e[201~")) { throw 'BRACKETED_PEER: paste framing differs.' }
        $results += [ordered]@{ case = $case; sourceMatches = $true; bracketedPeerMatches = $true; unrelatedTabEmpty = $true; delayedRenderBarrier = $case.StartsWith('delayed-') }
    }
    finally {
        [IO.File]::WriteAllText("$caseRoot\release", '')
        [IO.File]::WriteAllText("$caseRoot\provider.stop", '')
        [IO.File]::WriteAllText("$caseRoot\stop", '')
        Stop-Owned $provider $fixture
        Stop-Owned $terminal $exe
    }
}
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'result.json') -Encoding utf8NoBOM
$results | ConvertTo-Json -Depth 4
