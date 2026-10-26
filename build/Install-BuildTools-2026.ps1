#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$BootstrapperUri = 'https://aka.ms/vs/stable/vs_buildtools.exe'
$InstallPath = 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools'
$RequiredComponents = @(
    'Microsoft.VisualStudio.Workload.VCTools'
    'Microsoft.VisualStudio.Workload.UniversalBuildTools'
    'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
    'Microsoft.VisualStudio.Component.Windows11SDK.26100'
    'Microsoft.VisualStudio.ComponentGroup.UWP.VC.BuildTools'
    'Microsoft.Net.Component.4.7.2.TargetingPack'
)
$MinimumFreeBytes = 60GB
$LogRoot = Join-Path $env:LOCALAPPDATA 'TerminalLayoutFix\InstallLogs\VS2026'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$Plan = [ordered]@{
    mode = if ($Apply) { 'apply' } else { 'plan-only' }
    product = 'Microsoft.VisualStudio.Product.BuildTools'
    bootstrapper = $BootstrapperUri
    installPath = $InstallPath
    components = $RequiredComponents
    installerArguments = @(
        '--wait'
        '--quiet'
        '--norestart'
        '--downloadThenInstall'
        '--installPath'
        $InstallPath
    ) + ($RequiredComponents | ForEach-Object { @('--add', $_) })
    publishedFootprintRange = 'Microsoft documents 2.3 GB to 60 GB for Build Tools, depending on selected features; exact selected size is not published.'
    logs = $LogRoot
    runsInstall = [bool]$Apply
}

if (-not $Apply) {
    $Plan | ConvertTo-Json -Depth 6
    Write-Output 'Plan only: no download, file creation, installer invocation, or reboot.'
    exit 0
}

if (-not (Test-IsAdministrator)) {
    throw 'Run this script from an elevated PowerShell 7 session. The script does not request elevation.'
}

if (Test-Path -LiteralPath $InstallPath) {
    throw "Refusing to reuse an existing Visual Studio install path: $InstallPath"
}

$InstallDrive = [System.IO.Path]::GetPathRoot($InstallPath)
$AvailableBytes = [System.IO.DriveInfo]::new($InstallDrive).AvailableFreeSpace
if ($AvailableBytes -lt $MinimumFreeBytes) {
    throw "Refusing installation with less than 60 GB free on $InstallDrive."
}

$RunId = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N'))
$RunDirectory = Join-Path $LogRoot $RunId
if (Test-Path -LiteralPath $RunDirectory) {
    throw "Refusing to overwrite an existing installer receipt directory: $RunDirectory"
}
New-Item -ItemType Directory -Path $RunDirectory -Force | Out-Null

$BootstrapperPath = Join-Path $RunDirectory 'vs_buildtools.exe'
$StdoutPath = Join-Path $RunDirectory 'installer.stdout.log'
$StderrPath = Join-Path $RunDirectory 'installer.stderr.log'
$ReceiptPath = Join-Path $RunDirectory 'installer-receipt.json'
$Receipt = [ordered]@{
    schemaVersion = 1
    runId = $RunId
    status = 'DOWNLOAD_PENDING'
    startedUtc = [DateTime]::UtcNow.ToString('o')
    finishedUtc = $null
    bootstrapperUri = $BootstrapperUri
    bootstrapperPath = $BootstrapperPath
    bootstrapperSha256 = $null
    signerSubject = $null
    installPath = $InstallPath
    components = $RequiredComponents
    arguments = $Plan.installerArguments
    processStartedUtc = $null
    exitCode = $null
    stdoutPath = $StdoutPath
    stderrPath = $StderrPath
    failure = $null
}

function Save-Receipt {
    $json = $Receipt | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText(
        $ReceiptPath,
        $json,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProcessStarted = $false
try {
    Save-Receipt
    Invoke-WebRequest -Uri $BootstrapperUri -OutFile $BootstrapperPath

    $Signature = Get-AuthenticodeSignature -FilePath $BootstrapperPath
    if ($Signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw "Bootstrapper signature status is $($Signature.Status), not Valid."
    }
    if ($Signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
        throw "Bootstrapper signer is not Microsoft Corporation: $($Signature.SignerCertificate.Subject)"
    }

    $Receipt.bootstrapperSha256 = (Get-FileHash -LiteralPath $BootstrapperPath -Algorithm SHA256).Hash
    $Receipt.signerSubject = $Signature.SignerCertificate.Subject
    $Receipt.status = 'READY_TO_INSTALL'
    Save-Receipt

    $Arguments = @(
        '--wait'
        '--quiet'
        '--norestart'
        '--downloadThenInstall'
        '--installPath'
        $InstallPath
    )
    foreach ($Component in $RequiredComponents) {
        $Arguments += @('--add', $Component)
    }

    $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $BootstrapperPath
    $StartInfo.WorkingDirectory = $RunDirectory
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    foreach ($Argument in $Arguments) {
        [void]$StartInfo.ArgumentList.Add($Argument)
    }

    $Process = [System.Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo
    $StdoutStream = $null
    $StderrStream = $null
    try {
        $StdoutStream = [System.IO.File]::Create($StdoutPath)
        $StderrStream = [System.IO.File]::Create($StderrPath)
        if (-not $Process.Start()) {
            throw 'Visual Studio bootstrapper did not start.'
        }
        $ProcessStarted = $true
        $Receipt.processStartedUtc = [DateTime]::UtcNow.ToString('o')
        $Receipt.status = 'INSTALLING'
        Save-Receipt

        $StdoutCopy = $Process.StandardOutput.BaseStream.CopyToAsync($StdoutStream)
        $StderrCopy = $Process.StandardError.BaseStream.CopyToAsync($StderrStream)
        $Process.WaitForExit()
        [System.Threading.Tasks.Task]::WaitAll(
            [System.Threading.Tasks.Task[]]@($StdoutCopy, $StderrCopy)
        )
        $Receipt.exitCode = $Process.ExitCode
    }
    finally {
        if ($null -ne $StdoutStream) { $StdoutStream.Dispose() }
        if ($null -ne $StderrStream) { $StderrStream.Dispose() }
        $Process.Dispose()
    }

    $Receipt.finishedUtc = [DateTime]::UtcNow.ToString('o')
    if ($Receipt.exitCode -eq 0) {
        $Receipt.status = 'SUCCEEDED'
    }
    elseif ($Receipt.exitCode -eq 3010) {
        $Receipt.status = 'REBOOT_REQUIRED'
    }
    else {
        $Receipt.status = 'INSTALL_FAILED'
    }
    Save-Receipt

    Write-Output "Installer exit code: $($Receipt.exitCode)"
    Write-Output "Receipt and installer output: $RunDirectory"
    if ($Receipt.exitCode -eq 3010) {
        Write-Warning 'Installation completed but requires a reboot. This script will not reboot.'
        exit 3010
    }
    if ($Receipt.exitCode -ne 0) {
        throw "Visual Studio Build Tools installation failed with exit code $($Receipt.exitCode). See $ReceiptPath"
    }
    exit 0
}
catch {
    $Receipt.finishedUtc = [DateTime]::UtcNow.ToString('o')
    $Receipt.status = if ($ProcessStarted) { 'INSTALL_FAILED' } else { 'NOT_INSTALLED' }
    $Receipt.failure = $_.Exception.Message
    Save-Receipt
    throw
}
