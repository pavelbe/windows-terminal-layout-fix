param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$VsInstallPath = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools',
    [switch]$ReadClipboard
)
$ErrorActionPreference = 'Stop'
$vs = [System.IO.Path]::GetFullPath($VsInstallPath).TrimEnd('\')
$devShellModule = Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
if (!(Test-Path -LiteralPath $devShellModule -PathType Leaf)) { throw "Visual Studio developer shell not found: $devShellModule" }
$headerDirectory = Join-Path $SourceRoot 'src\cascadia\TerminalApp'
$wil = Join-Path $SourceRoot 'packages\Microsoft.Windows.ImplementationLibrary.1.0.250325.1\include'
if (!(Test-Path "$headerDirectory\ClipboardImage.h") -or !(Test-Path "$wil\wil\com.h")) { throw 'Missing pinned source/dependency' }
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path $OutputDirectory) { throw 'Use a new output directory' }
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
Set-Location $OutputDirectory
# Enter-VsDevShell starts cmd.exe; set its inherited process cwd to local NTFS too.
[System.Environment]::CurrentDirectory = $OutputDirectory
Import-Module $devShellModule
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
$exe = Join-Path $OutputDirectory 'clipboard-image-smoke.exe'
& cl.exe /nologo /std:c++20 /EHsc /W4 /WX /utf-8 "/I$headerDirectory" "/I$wil" (Join-Path $PSScriptRoot 'clipboard-image-smoke.cpp') "/Fe:$exe" /link ole32.lib windowscodecs.lib user32.lib gdi32.lib shell32.lib
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($ReadClipboard) { & $exe --clipboard } else { & $exe }
exit $LASTEXITCODE
