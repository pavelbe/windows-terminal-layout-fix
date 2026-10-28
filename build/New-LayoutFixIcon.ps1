#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourcePng,
    [Parameter(Mandatory)][string]$OutputIco,
    [switch]$TrimTransparentPadding
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
    $sourceBounds = [System.Drawing.Rectangle]::new(0, 0, $source.Width, $source.Height)
    if ($TrimTransparentPadding) {
        # Ignore nearly transparent edge noise; preserve aspect ratio with a square crop.
        $left = $source.Width; $top = $source.Height; $right = -1; $bottom = -1
        for ($y = 0; $y -lt $source.Height; $y++) {
            for ($x = 0; $x -lt $source.Width; $x++) {
                if ($source.GetPixel($x, $y).A -lt 128) { continue }
                $left = [Math]::Min($left, $x); $right = [Math]::Max($right, $x)
                $top = [Math]::Min($top, $y); $bottom = [Math]::Max($bottom, $y)
            }
        }
        if ($right -lt 0) { throw 'No visible artwork at alpha >= 128.' }
        $side = [Math]::Max($right - $left + 1, $bottom - $top + 1)
        $cropX = [Math]::Clamp([int][Math]::Floor(($left + $right + 1 - $side) / 2), 0, $source.Width - $side)
        $cropY = [Math]::Clamp([int][Math]::Floor(($top + $bottom + 1 - $side) / 2), 0, $source.Height - $side)
        $sourceBounds = [System.Drawing.Rectangle]::new($cropX, $cropY, $side, $side)
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
            $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, $size, $size), $sourceBounds, [System.Drawing.GraphicsUnit]::Pixel)
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
