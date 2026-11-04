# Quick start — portable layout fix

Five-minute recovery with a portable build: no installer, no administrator
rights, no change to an existing Windows Terminal installation.

This guide uses the published `layout-fix.3` archive. The maintainer's accepted
daily `lf-menu2` and delivered `paste1`/`paste2`/`paste3` candidates are separate
local builds;
see [current runtime status](../README.md)
and [paste candidate evidence and acceptance](paste-candidate-20261103.md).
`paste3` has automated runtime smoke evidence; its owner acceptance remains
pending. These candidates are not release downloads.

## 1. Get the archive

Download from [Releases](https://github.com/pavelbe/windows-terminal-layout-fix/releases):

- `WT-Layout-Fix-1.25.2733.0-layout-fix.3-win-x64.zip` — latest published
  recovery build (Stable 1.25.2733.0);
- its `.zip.sha256` checksum.

`layout-fix.2` (Preview 1.25.1912.0) remains available as the previous archive.
Windows 10/11 x64 only.

## 2. Verify the download

```powershell
Get-FileHash .\WT-Layout-Fix-1.25.2733.0-layout-fix.3-win-x64.zip -Algorithm SHA256
```

Compare with the `.zip.sha256` value
(`4c2ea421b49b38035bedc5d970fb7da37658bb5ed13e779eca430e8e9d6bacb0`). For a
full check, including every file in the archive and the reviewed settings
snapshot:

```bash
python3 build/release_archive.py verify \
  WT-Layout-Fix-1.25.2733.0-layout-fix.3-win-x64.zip \
  --manifest build/recovery-manifest-layout-fix.3.json
```

## 3. Run

Extract the ZIP anywhere and start `WindowsTerminal.exe` from the extracted
`WT-Layout-Fix-1.25.2733.0-layout-fix.3` folder. A shortcut can target that
exact EXE. Nothing is installed or registered; deleting the folder removes the
build.

## 4. Settings

The archive carries the reviewed `settings/settings.json` (SHA-256
`20426242513f01c691e127f2f26415721260aa7dc7868a3cf9faccbb733cdeda`). Review it
before use: it contains machine-specific paths and an `Ubuntu` profile. Paths,
profiles and keybindings are safe to adjust. Session state, buffers and
authentication are never part of an archive.

## Boundaries

- This is a downstream patch set, not an upstream release. Microsoft has not
  accepted or shipped these patches; link an upstream PR or commit before
  claiming otherwise.
- A portable build does not replace a live installation. Keep the previous
  build until the new one passes your own checks.
- No Windows Terminal restart is needed and no settings are migrated
  automatically.
