#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TerminalExe,
    [Parameter(Mandatory)][string]$ShortcutPath
)

$ErrorActionPreference = 'Stop'
$TerminalExe = [System.IO.Path]::GetFullPath($TerminalExe)
$ShortcutPath = [System.IO.Path]::GetFullPath($ShortcutPath)
if ([System.IO.Path]::GetExtension($ShortcutPath) -ine '.lnk') { throw 'ShortcutPath must end in .lnk.' }
if (-not (Test-Path -LiteralPath $TerminalExe -PathType Leaf)) { throw 'Terminal EXE does not exist.' }
if (-not (Test-Path -LiteralPath (Join-Path (Split-Path $TerminalExe) '.portable') -PathType Leaf)) {
    throw 'Portable marker is missing beside the EXE.'
}
if (Test-Path -LiteralPath $ShortcutPath) { throw 'Preserve the existing shortcut; use a new path.' }

# Save COM output in a private new directory, then use a no-overwrite move.
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('terminal-lf-link-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch -ErrorAction Stop | Out-Null
$stagedLink = Join-Path $scratch 'Terminal LF.lnk'
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($stagedLink)
$link.TargetPath = $TerminalExe
$link.WorkingDirectory = Split-Path $TerminalExe
$link.IconLocation = "$TerminalExe,0"
$link.Description = 'Windows Terminal Layout Fix - teal LF icon'
$link.Save()
[System.IO.File]::Move($stagedLink, $ShortcutPath, $false)
[System.IO.Directory]::Delete($scratch, $false)
$check = $shell.CreateShortcut($ShortcutPath)
if ($check.TargetPath -ine $TerminalExe -or $check.IconLocation -ine "$TerminalExe,0" -or $check.Arguments) {
    throw 'Shortcut verification failed; inspect the retained file.'
}
[ordered]@{ shortcut = $ShortcutPath; target = $check.TargetPath; icon = $check.IconLocation; launched = $false } | ConvertTo-Json
