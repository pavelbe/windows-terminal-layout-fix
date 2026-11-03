#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TerminalExe,
    [Parameter(Mandatory)][string]$ExpectedIcon
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Embedded icon verification requires Windows.' }
if (-not ('LFIconResources' -as [type])) {
    Add-Type @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class LFIconResources {
    public delegate bool LanguageCallback(IntPtr module, IntPtr type, IntPtr name, ushort language, IntPtr data);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern IntPtr LoadLibraryEx(string path, IntPtr file, uint flags);
    [DllImport("kernel32.dll")] public static extern bool FreeLibrary(IntPtr module);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern bool EnumResourceLanguages(IntPtr module, IntPtr type, IntPtr name, LanguageCallback callback, IntPtr data);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr FindResourceEx(IntPtr module, IntPtr type, IntPtr name, ushort language);
    [DllImport("kernel32.dll", SetLastError=true)] private static extern IntPtr LoadResource(IntPtr module, IntPtr resource);
    [DllImport("kernel32.dll", SetLastError=true)] private static extern IntPtr LockResource(IntPtr resource);
    [DllImport("kernel32.dll", SetLastError=true)] private static extern uint SizeofResource(IntPtr module, IntPtr resource);
    public static ushort[] Languages(IntPtr module) {
        var result = new List<ushort>();
        if (!EnumResourceLanguages(module, (IntPtr)14, (IntPtr)101,
            (m,t,n,l,d) => { result.Add(l); return true; }, IntPtr.Zero))
            throw new Win32Exception(Marshal.GetLastWin32Error());
        return result.ToArray();
    }
    public static byte[] Read(IntPtr module, int type, int id, ushort language) {
        var resource = FindResourceEx(module, (IntPtr)type, (IntPtr)id, language);
        if (resource == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        var size = SizeofResource(module, resource);
        var data = LockResource(LoadResource(module, resource));
        if (size == 0 || data == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        var result = new byte[checked((int)size)];
        Marshal.Copy(data, result, 0, result.Length);
        return result;
    }
}
'@
}
$TerminalExe = [IO.Path]::GetFullPath($TerminalExe)
$icon = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($ExpectedIcon))
if ($icon.Length -lt 6 -or [BitConverter]::ToUInt16($icon, 0) -ne 0 -or
    [BitConverter]::ToUInt16($icon, 2) -ne 1) { throw 'Invalid reference ICO header.' }
$count = [BitConverter]::ToUInt16($icon, 4)
if ($count -eq 0 -or $icon.Length -lt 6 + 16 * $count) { throw 'Invalid reference ICO directory.' }
# Load only resource data. No code or entry point from the EXE is executed.
$module = [LFIconResources]::LoadLibraryEx($TerminalExe, [IntPtr]::Zero, 0x22)
if ($module -eq [IntPtr]::Zero) { throw 'Cannot open EXE resources.' }
try {
    $languages = @([LFIconResources]::Languages($module))
    if ($languages.Count -eq 0) { throw 'Missing primary icon group 101.' }
    foreach ($language in $languages) {
        $group = [LFIconResources]::Read($module, 14, 101, $language)
        if ($group.Length -ne 6 + 14 * $count -or
            [BitConverter]::ToUInt16($group, 0) -ne 0 -or
            [BitConverter]::ToUInt16($group, 2) -ne 1 -or
            [BitConverter]::ToUInt16($group, 4) -ne $count) { throw 'Embedded icon directory differs.' }
        for ($i = 0; $i -lt $count; $i++) {
            $icoEntry = 6 + 16 * $i
            $groupEntry = 6 + 14 * $i
            $length = [BitConverter]::ToUInt32($icon, $icoEntry + 8)
            $offset = [BitConverter]::ToUInt32($icon, $icoEntry + 12)
            if ($length -eq 0 -or [long]$offset + $length -gt $icon.Length) { throw 'Invalid reference ICO frame bounds.' }
            if ([Convert]::ToHexString($icon[$icoEntry..($icoEntry + 7)]) -cne
                [Convert]::ToHexString($group[$groupEntry..($groupEntry + 7)])) { throw "Embedded icon frame $i metadata differs." }
            $id = [BitConverter]::ToUInt16($group, $groupEntry + 12)
            $frame = [LFIconResources]::Read($module, 3, $id, $language)
            $expected = $icon[$offset..($offset + $length - 1)]
            if ($frame.Length -ne $length -or [BitConverter]::ToUInt32($group, $groupEntry + 8) -ne $length -or
                [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($frame)) -cne
                [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$expected))) {
                throw "Embedded icon frame $i payload differs."
            }
        }
    }
    [ordered]@{ groupId = 101; languages = $languages; matchingFramesPerLanguage = $count; executableLaunched = $false }
}
finally { $null = [LFIconResources]::FreeLibrary($module) }
