# Windows Terminal Layout Fix — recovery repository

Private backup of the owner's tested Windows Terminal portable build and settings.
Read README.md before changing this repository. This is not the upstream source
checkout and not the Atreno application.

- Preserve private visibility. Do not enable GitHub Actions.
- Keep executable archives in private GitHub Releases, not Git history.
- Runtime is based on upstream v1.25.1912.0 plus patches/layout-fix.patch.
  Source identity and original file hashes are in build/original-build-receipt.json.
  That receipt is historical: do not overwrite it to certify newer settings.
- build/recovery-manifest.json describes the actual recovery archive. Update it
  only by measuring the exact packaged bytes; never claim a fresh Windows smoke
  from hash equality or the owner's existing-machine test.
- settings/settings.json is the reviewed daily configuration. Never copy the
  live settings directory wholesale: state.json, buffer_*.txt, elevated_*.txt,
  dumps, traces and backups contain session data and must stay outside Git/releases.
- Preserve profile GUIDs, command lines and native input bindings unless requested.
- Do not close Terminal/WSL or restart agents to test restoration without permission.
- Run packaging/build/validation through the owner's machine-global heavy lock.
  Use literal path-scoped Git writes and keep unrelated work untouched.
- Changes to source or dependencies need new build and manual acceptance evidence.
  A private recovery release does not mean Microsoft accepted or shipped the patch.
