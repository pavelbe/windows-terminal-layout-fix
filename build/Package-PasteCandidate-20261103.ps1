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
$buildReceipt = Join-Path $env:LOCALAPPDATA 'TerminalLayoutFix\BuildLogs\WT-v1.25.2733.0\20261103-214046-c60031bf24074242bcc460e7522eab7f\build-receipt.json'
$makeAppx = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\MakeAppx.exe'
function Assert-CleanTerminalPackage {
    param([Parameter(Mandatory)][string]$Path)
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('\', '/').TrimStart('/')
            if ($name -ieq 'settings' -or $name.StartsWith('settings/', [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Terminal package contains a settings directory; refusing packaging before writes.'
            }
        }
    }
    finally { $archive.Dispose() }
}

$pins = [ordered]@{
    $buildReceipt = 'b9cfb69570c74c25ed055ea81a1c31c216ca1c75db3fc3a3f3e4f90cdeea530f'
    $msix = '41ddfb72f05d473167c7f67835f735535149d0dacd9add659ebd087f6bd10dc2'
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
Assert-CleanTerminalPackage -Path $msix
if (-not (Test-Path -LiteralPath $makeAppx -PathType Leaf)) { throw 'Required Windows SDK MakeAppx is absent.' }
if (-not $Run) {
    [ordered]@{ mode = 'plan-only'; destination = $Destination; verifiedInputs = $pins; launchesApp = $false } | ConvertTo-Json
    exit 0
}

# This upstream chain operates only on new temporary extraction directories.
# Native failures (including MakePri) must terminate before a runtime is accepted.
# Reserve this run's destination: upstream itself suppresses an existing-dir error.
New-Item -ItemType Directory -Path $Destination -ErrorAction Stop | Out-Null
Set-Location -LiteralPath $SourceRoot
[System.Environment]::CurrentDirectory = $SourceRoot
$extraction = Join-Path ([IO.Path]::GetTempPath()) ('lf-package-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $extraction -ErrorAction Stop | Out-Null
& $makeAppx unpack /p $msix /d $extraction /o | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'MSIX extraction failed.' }
if (Test-Path -LiteralPath (Join-Path $extraction 'settings')) {
    throw 'Extracted layout contains private settings; refusing packaging.'
}
$result = @(& (Join-Path $scripts 'New-UnpackagedTerminalDistribution.ps1') -TerminalLayout $extraction -XamlAppX $xaml -MakeAppxPath $makeAppx -Destination $Destination -PortableMode)
if ($result.Count -ne 1 -or $result[0] -isnot [System.IO.DirectoryInfo]) {
    throw 'Packaging did not return one runtime directory. Preserve partial output; do not use it.'
}
$runtime = Join-Path $Destination $result[0].Name
if (Test-Path -LiteralPath $runtime) { throw 'Runtime destination already exists.' }
Move-Item -LiteralPath $result[0].FullName -Destination $runtime -ErrorAction Stop
foreach ($name in @('WindowsTerminal.exe', 'TerminalApp.dll', 'TerminalConnection.dll', 'OpenConsole.exe', 'resources.pri', 'Microsoft.UI.Xaml.dll', '.portable')) {
    if (!(Test-Path -LiteralPath (Join-Path $runtime $name) -PathType Leaf)) { throw "Missing runtime file: $name" }
}
$inventory = @(Get-ChildItem -LiteralPath $runtime -Recurse -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = [IO.Path]::GetRelativePath($runtime, $_.FullName); bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() }
})
$receipt = [ordered]@{
    status = 'PACKAGED_NOT_LAUNCHED'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    buildReceiptSha256 = $pins[$buildReceipt]
    inputs = $pins
    runtimePath = $runtime
    files = $inventory
    archiveCreated = $false
    extractionPath = $extraction
}
$receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Destination 'package-receipt.json') -Encoding utf8NoBOM
$receipt | ConvertTo-Json -Depth 4
