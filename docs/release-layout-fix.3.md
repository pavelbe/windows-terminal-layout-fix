# Release `layout-fix.3` — packaged, not published

Status 2026-11-03: **packaged, verified and owner-smoked on the packaged
folder; not published.** The archive was produced from the accepted `rmb3`
build with the pinned packager (no rebuild), its manifest was measured from the
exact packaged bytes, and the archive passes the repository verifier. The owner
ran the packaged runtime on 2026-11-03: the exit-notice flash is gone and the
remaining checks carry over from the `rmb3` acceptance. A fresh extraction smoke
of the ZIP itself has not been run. Creating release assets still needs
explicit owner authorization.

## Recorded artifact (2026-11-03)

| Item | Value |
| --- | --- |
| Archive | `WT-Layout-Fix-1.25.2733.0-layout-fix.3-win-x64.zip` |
| Staging directory | `%USERPROFILE%\Downloads\WT-Layout-Fix-1.25.2733.0-layout-fix.3-release` |
| Size | 11304383 bytes |
| SHA-256 | `4c2ea421b49b38035bedc5d970fb7da37658bb5ed13e779eca430e8e9d6bacb0` |
| Files | 56 (includes `.portable` and the reviewed `settings/settings.json`) |
| Manifest | `build/recovery-manifest-layout-fix.3.json` |
| Release receipt | `build/release-receipt-layout-fix.3.json` |
| Package receipt | `build/package-receipt-layout-fix.3.json` |
| Verification | `release_archive.py verify` → PASS on 2026-11-03 |

The packaged runtime also exists locally under
`%LOCALAPPDATA%\Programs\WT-Layout-Fix-1.25.2733.0-layout-fix.3\WT-Layout-Fix-1.25.2733.0-layout-fix.3`
with its `package-receipt.json`. Steps 1–5 and 7 are done for this archive;
step 6 is partial (packaged-folder smoke passed 2026-11-03, fresh extraction
smoke not run); step 8 (publication) remains.

## What the release would contain

- Upstream Stable `v1.25.2733.0`, commit `dc8ae365847d41f62d1ebca93815bb00959bc12f`.
- The seven-patch chain listed in README: layout, clipboard image, clipboard
  files, runtime tab color, connection diagnostics, exit-notice suppression,
  terminal-owned right button.
- The square LF icon overlay and the reviewed `settings/settings.json`
  (SHA-256 `20426242513f01c691e127f2f26415721260aa7dc7868a3cf9faccbb733cdeda`).
- Provenance: accepted `rmb3` build run `20261101-112434…`, Terminal Core
  56/56, owner manual acceptance passed 2026-11-03
  ([checklist](manual-acceptance-rmb3.md)).

Proposed names:

| Item | Value |
| --- | --- |
| Tag | `v1.25.2733.0-layout-fix.3` |
| Archive | `WT-Layout-Fix-1.25.2733.0-layout-fix.3-win-x64.zip` |
| Archive root folder | `WT-Layout-Fix-1.25.2733.0-layout-fix.3` |
| Manifest | `build/recovery-manifest-layout-fix.3.json` |
| Release receipt | `build/release-receipt-layout-fix.3.json` |

## Steps (run only on explicit request)

1. **Package the accepted build — no rebuild.**
   `build/Package-Rmb3Candidate-20261101.ps1` pins the `rmb3` build receipt,
   MSIX, XAML dependency and upstream helpers. Run its plan first, then `-Run`
   with a new destination. Existing destinations are refused by design.
2. **Settings and root name.** Copy the reviewed `settings/settings.json` into
   the packaged runtime and verify its SHA-256 against the repository snapshot.
   Rename the runtime folder to the archive root above; name changes are safe
   before the archive is measured.
3. **Archive.** Zip the runtime folder at the release root and write the
   `.sha256` file. Never include session state, buffers, dumps, traces or
   backups.
4. **Manifest from the exact packaged bytes.**

   ```bash
   python3 build/release_archive.py manifest \
     WT-Layout-Fix-1.25.2733.0-layout-fix.3-win-x64.zip \
     --tag v1.25.2733.0-layout-fix.3 \
     --root WT-Layout-Fix-1.25.2733.0-layout-fix.3 \
     --release-receipt build/release-receipt-layout-fix.3.json \
     --upstream-tag v1.25.2733.0 \
     --upstream-commit dc8ae365847d41f62d1ebca93815bb00959bc12f \
     --source-commit <exact source commit from the rmb3 build receipt> \
     --proof 'Exact allowlist, packaged-byte hashes, reviewed settings equality' \
     --reviewed-settings settings/settings.json \
     --out build/recovery-manifest-layout-fix.3.json
   ```

   The tool refuses live session state and any settings file other than the
   reviewed snapshot.
5. **Verify the archive against the manifest.**

   ```bash
   python3 build/release_archive.py verify \
     WT-Layout-Fix-1.25.2733.0-layout-fix.3-win-x64.zip \
     --manifest build/recovery-manifest-layout-fix.3.json
   ```

6. **Fresh Windows smoke of that exact archive.** Extract into a new folder,
   launch `WindowsTerminal.exe`, repeat the short checks from the manual
   acceptance list. Hash equality never replaces this step.
7. **Release receipt.** Record tag, runtime directory, upstream and source
   commits, candidate receipt, patch order with hashes, runtime file hashes,
   settings equality and the smoke result — mirroring
   `build/release-receipt-layout-fix.2.json`.
8. **Publication gate.** Creating or replacing release assets needs explicit
   owner authorization. GitHub Actions stay disabled. Keep `layout-fix.1` and
   `layout-fix.2` assets, manifests and receipts unchanged; a new archive gets
   its own versioned manifest.

## Known residual risks

- Taskbar pinning/grouping was accepted on the owner PC only; a clean machine
  is untested.
- These are downstream patches; Microsoft has not reviewed or shipped them.
- `layout-fix.2` remains the rollback artifact while `layout-fix.3` is
  unverified on other machines.
