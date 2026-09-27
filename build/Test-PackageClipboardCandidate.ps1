# Offline packaging regression: synthetic build files, no Terminal process or compiler.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('wt-package-test-' + [guid]::NewGuid().ToString('N'))
try {
    $source = Join-Path $root 'source'
    $release = Join-Path $source 'bin/x64/Release'
    $layout = Join-Path $release 'WindowsTerminal'
    $null = New-Item -ItemType Directory -Path $layout -Force
    foreach ($name in @('WindowsTerminal.exe','OpenConsole.exe','TerminalApp.dll',
        'Microsoft.Terminal.Control.dll','Microsoft.Terminal.Settings.Model.dll',
        'Microsoft.Terminal.Settings.Editor.dll','Microsoft.Terminal.UI.dll',
        'Microsoft.Terminal.UI.Markdown.dll','Microsoft.UI.Xaml.dll',
        'TerminalConnection.dll','TerminalThemeHelpers.dll')) {
        Set-Content -LiteralPath (Join-Path $layout $name) -Value 'synthetic runtime'
    }
    foreach ($name in @('Microsoft.Terminal.Control/Microsoft.Terminal.Control.pri',
        'Microsoft.Terminal.Control.Lib/Microsoft.Terminal.Control.pri',
        'Microsoft.Terminal.UI/Microsoft.Terminal.UI.pri','TerminalCore/Microsoft.Terminal.Core.pri',
        'TerminalConnection/Microsoft.Terminal.TerminalConnection.pri',
        'Microsoft.Terminal.Settings.Model/Microsoft.Terminal.Settings.Model.pri',
        'Microsoft.Terminal.Settings.Model.Lib/Microsoft.Terminal.Settings.Model.pri',
        'TerminalApp/TerminalApp.pri','TerminalAppLib/TerminalApp.pri',
        'Microsoft.Terminal.Settings.Editor/Microsoft.Terminal.Settings.Editor.pri',
        'Microsoft.Terminal.UI.Markdown/Microsoft.Terminal.UI.Markdown.pri',
        'TerminalSettingsAppAdapterLib/TerminalSettingsAppAdapterLib.pri',
        'WindowsTerminal/_xaml/resources.pri')) {
        $path = Join-Path $release $name
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
        Set-Content -LiteralPath $path -Value 'synthetic resources'
    }
    $null = New-Item -ItemType Directory -Path (Join-Path $source 'build/scripts') -Force
    Set-Content -LiteralPath (Join-Path $source 'build/scripts/Merge-PriFiles.ps1') -Value @'
param($Path, $OutputPath)
Set-Content -LiteralPath $OutputPath -Value 'synthetic merged resources'
'@
    Set-Content -LiteralPath (Join-Path $source 'LICENSE') -Value 'synthetic license'
    Set-Content -LiteralPath (Join-Path $release 'OpenConsoleProxy.dll') -Value 'synthetic proxy'
    $settings = Join-Path $root 'reviewed.json'
    Set-Content -LiteralPath $settings -Value '{"profiles":{"list":[]}}'
    $privateSettings = Join-Path $layout 'settings'
    $null = New-Item -ItemType Directory -Path $privateSettings
    Set-Content -LiteralPath (Join-Path $privateSettings 'state.json') -Value '{"sentinel":"PRIVATE_SESSION"}'
    $destination = Join-Path $root 'rejected'
    $failure = $null
    try { & (Join-Path $PSScriptRoot 'Package-ClipboardCandidate.ps1') -SourceRoot $source -SettingsFile $settings -Destination $destination }
    catch { $failure = $_ }
    if (Test-Path -LiteralPath (Join-Path $destination 'settings/state.json')) {
        throw 'PRIVATE_STATE_COPIED: packaging copied unreviewed session state into the candidate'
    }
    if ($null -eq $failure -or (Test-Path -LiteralPath $destination)) {
        throw 'DIRTY_LAYOUT: expected refusal before creating a candidate'
    }
    if (Test-Path -LiteralPath (Join-Path $layout 'resources.pri')) {
        throw 'DIRTY_LAYOUT: must refuse before modifying build resources'
    }
    Remove-Item -LiteralPath $privateSettings -Recurse -Force
    $destination = Join-Path $root 'accepted'
    & (Join-Path $PSScriptRoot 'Package-ClipboardCandidate.ps1') -SourceRoot $source -SettingsFile $settings -Destination $destination
    foreach ($name in @('WindowsTerminal.exe','resources.pri','OpenConsoleProxy.dll','LICENSE','.portable','settings/settings.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $destination $name) -PathType Leaf)) { throw "Missing candidate file: $name" }
    }
    if ((Get-Content -LiteralPath (Join-Path $destination 'settings/settings.json') -Raw) -ne
        (Get-Content -LiteralPath $settings -Raw)) { throw 'Reviewed settings changed' }
    Write-Host 'PASS: dirty layout refused before writes; clean candidate includes only the reviewed settings'
}
finally { if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }
