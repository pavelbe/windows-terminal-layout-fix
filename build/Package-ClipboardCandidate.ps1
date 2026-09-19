# For the existing v1.25.1912.0 Release/x64 checkout, after a successful
# WindowsTerminal.vcxproj build. Does not build, install, or replace a live app.
param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$SettingsFile,
    [Parameter(Mandatory)][string]$Destination
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.4') { throw 'PowerShell 7.4+ required' }
$PSNativeCommandUseErrorActionPreference = $true
if (Test-Path -LiteralPath $Destination) { throw 'Destination must not exist' }
$null = Get-Content -LiteralPath $SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
$release = Join-Path $SourceRoot 'bin\x64\Release'
$layout = Join-Path $release 'WindowsTerminal'
$required = @(
    'WindowsTerminal.exe', 'OpenConsole.exe', 'TerminalApp.dll',
    'Microsoft.Terminal.Control.dll', 'Microsoft.Terminal.Settings.Model.dll',
    'Microsoft.Terminal.Settings.Editor.dll', 'Microsoft.Terminal.UI.dll',
    'Microsoft.Terminal.UI.Markdown.dll', 'Microsoft.UI.Xaml.dll',
    'TerminalConnection.dll', 'TerminalThemeHelpers.dll'
)
foreach ($name in $required) {
    if ((Get-Item -LiteralPath (Join-Path $layout $name)).Length -le 0) { throw "Empty runtime: $name" }
}
# The dependency PRI list from this tag's _WTPrepareUnpackagedLayoutForRun.
# Run the upstream merger in this process so native failures cannot be masked.
$priNames = @(
    'Microsoft.Terminal.Control\Microsoft.Terminal.Control.pri',
    'Microsoft.Terminal.Control.Lib\Microsoft.Terminal.Control.pri',
    'Microsoft.Terminal.UI\Microsoft.Terminal.UI.pri',
    'TerminalCore\Microsoft.Terminal.Core.pri',
    'TerminalConnection\Microsoft.Terminal.TerminalConnection.pri',
    'Microsoft.Terminal.Settings.Model\Microsoft.Terminal.Settings.Model.pri',
    'Microsoft.Terminal.Settings.Model.Lib\Microsoft.Terminal.Settings.Model.pri',
    'TerminalApp\TerminalApp.pri', 'TerminalAppLib\TerminalApp.pri',
    'Microsoft.Terminal.Settings.Editor\Microsoft.Terminal.Settings.Editor.pri',
    'Microsoft.Terminal.UI.Markdown\Microsoft.Terminal.UI.Markdown.pri',
    'TerminalSettingsAppAdapterLib\TerminalSettingsAppAdapterLib.pri',
    'WindowsTerminal\_xaml\resources.pri'
)
$pri = @($priNames | ForEach-Object { (Get-Item -LiteralPath (Join-Path $release $_)).FullName })
$merged = Join-Path $layout 'resources.pri'
& (Join-Path $SourceRoot 'build\scripts\Merge-PriFiles.ps1') -Path $pri -OutputPath $merged
if ((Get-Item -LiteralPath $merged).Length -le 0) { throw 'Missing merged resources' }

New-Item -ItemType Directory -Path $Destination | Out-Null
foreach ($item in Get-ChildItem -LiteralPath $layout -Recurse -File) {
    $relative = [IO.Path]::GetRelativePath($layout, $item.FullName)
    if ($relative -match '^_xaml[\\/]' -or $item.Name -eq 'stamp' -or
        $item.Extension -in @('.pdb', '.lib', '.exp', '.winmd', '.recipe')) { continue }
    $target = Join-Path $Destination $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    Copy-Item -LiteralPath $item.FullName -Destination $target
    if ((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath $item.FullName).Hash) {
        throw "Copied runtime differs: $relative"
    }
}
Copy-Item -LiteralPath (Join-Path $release 'OpenConsoleProxy.dll') -Destination $Destination
Copy-Item -LiteralPath (Join-Path $SourceRoot 'LICENSE') -Destination $Destination
New-Item -ItemType File -Path (Join-Path $Destination '.portable') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Destination 'settings') | Out-Null
Copy-Item -LiteralPath $SettingsFile -Destination (Join-Path $Destination 'settings\settings.json')
Write-Output "CANDIDATE=$Destination"
