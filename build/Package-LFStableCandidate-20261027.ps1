#Requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Destination,
    [string]$SourceRoot = 'C:\Users\Pavel\Source\terminal-v1.25.2733.0',
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
if (-not $IsWindows) { throw 'Run this recipe with PowerShell 7.4+ on Windows.' }
$Destination = [System.IO.Path]::GetFullPath($Destination)
if ($Destination -notmatch '^[A-Za-z]:\\') { throw 'Use a local Windows destination.' }
if (Test-Path -LiteralPath $Destination) { throw 'Destination already exists; preserve it and choose a new directory.' }
$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$packageRoot = Join-Path $SourceRoot 'src\cascadia\CascadiaPackage\AppPackages\CascadiaPackage_1.25.2733.0_x64_Test'
$msix = Join-Path $packageRoot 'CascadiaPackage_1.25.2733.0_x64.msix'
$xaml = Join-Path $packageRoot 'Dependencies\x64\Microsoft.UI.Xaml.2.8.appx'
$scripts = Join-Path $SourceRoot 'build\scripts'
$buildReceipt = Join-Path $env:LOCALAPPDATA 'TerminalLayoutFix\BuildLogs\WT-v1.25.2733.0\20261028-220907-f8bd4185dfe043b5b19b9d126c40c83f\build-receipt.json'
$makeAppx = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\MakeAppx.exe'
$pins = [ordered]@{
    $buildReceipt = '41acc8861d1473eacdf26f2df3335682a609361ac1d46337dbc0b65b71222067'
    $msix = '695f70c56e34e1cc1d725234cd14ea0e8dbc91a5313174cc9dc9bb6e436ce57e'
    $xaml = '0c1d46883629a75bff7881661e4bb8ac2510983f9341f35d87dc63702cb85118'
    (Join-Path $scripts 'New-UnpackagedTerminalDistribution.ps1') = 'd30bdd45862e44855f505a4339cabc2a1abcfbd1ea3a12bcef9eec10dc4fa7bd'
    (Join-Path $scripts 'Merge-TerminalAndXamlResources.ps1') = 'f1feae943935f651cd133d8126dd3ac6431a70785e1440c88fe364c207708ea3'
    (Join-Path $scripts 'Merge-PriFiles.ps1') = 'e00337d397c642ebf95bfafc0e996ed245c1e54ff5c3eafb3463b49f96b7805e'
}
foreach ($path in $pins.Keys) {
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $pins[$path]) {
        throw "Pinned LF packaging input differs: $path. Rebind a new build before packaging."
    }
}
if (-not (Test-Path -LiteralPath $makeAppx -PathType Leaf)) { throw 'Required Windows SDK MakeAppx is absent.' }
if (-not $Run) {
    [ordered]@{ mode = 'plan-only'; destination = $Destination; verifiedInputs = $pins; launchesApp = $false } | ConvertTo-Json
    exit 0
}

# This upstream chain operates only on new temporary extraction directories.
# Native failures (including MakePri) must terminate before a ZIP is accepted.
# Reserve this run's destination: upstream itself suppresses an existing-dir error.
New-Item -ItemType Directory -Path $Destination -ErrorAction Stop | Out-Null
Set-Location -LiteralPath $SourceRoot
[System.Environment]::CurrentDirectory = $SourceRoot
$result = @(& (Join-Path $scripts 'New-UnpackagedTerminalDistribution.ps1') -TerminalAppX $msix -XamlAppX $xaml -MakeAppxPath $makeAppx -Destination $Destination -PortableMode)
if ($result.Count -ne 1 -or $result[0] -isnot [System.IO.FileInfo] -or $result[0].Extension -ne '.zip' -or $result[0].Length -le 0) {
    throw 'Packaging did not return one nonempty ZIP. Preserve partial output; do not use it.'
}
$zip = $result[0]
$receipt = [ordered]@{
    status = 'PACKAGED_NOT_LAUNCHED'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    buildReceiptSha256 = $pins[$buildReceipt]
    inputs = $pins
    zipPath = $zip.FullName
    zipSha256 = (Get-FileHash -LiteralPath $zip.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    zipBytes = $zip.Length
}
$receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Destination 'package-receipt.json') -Encoding utf8NoBOM
$receipt | ConvertTo-Json -Depth 4
