#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourcePng,
    [Parameter(Mandatory)][string]$OutputIco
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $IsWindows) { throw 'Run with PowerShell 7 on Windows (System.Drawing).' }
$SourcePng = [System.IO.Path]::GetFullPath($SourcePng)
$OutputIco = [System.IO.Path]::GetFullPath($OutputIco)
if (Test-Path -LiteralPath $OutputIco) { throw 'Use a new output file; existing icons are preserved.' }

Add-Type -AssemblyName System.Drawing
$source = [System.Drawing.Bitmap]::FromFile($SourcePng)
$frames = [System.Collections.Generic.List[byte[]]]::new()
$sizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
try {
    if ($source.Width -ne $source.Height -or $source.Width -lt 256) {
        throw 'Use a square PNG of at least 256 pixels.'
    }
    foreach ($size in $sizes) {
        $bitmap = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $stream = [System.IO.MemoryStream]::new()
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, $size, $size))
            $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
            $frames.Add($stream.ToArray())
        }
        finally {
            $stream.Dispose()
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }
}
finally { $source.Dispose() }

# PNG-backed ICO frames preserve alpha and cover Windows 11 taskbar/DPI sizes.
$output = [System.IO.File]::Open($OutputIco, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
$writer = [System.IO.BinaryWriter]::new($output)
try {
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $dimension = if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] }
        $writer.Write([byte]$dimension)
        $writer.Write([byte]$dimension)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$frames[$i].Length)
        $writer.Write([uint32]$offset)
        $offset += $frames[$i].Length
    }
    foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
}
finally { $writer.Dispose() }

Get-FileHash -LiteralPath $OutputIco -Algorithm SHA256
