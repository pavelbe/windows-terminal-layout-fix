# Windows Terminal Layout Fix — recovery repository

Private backup of the owner's tested Windows Terminal portable build and settings.
Read README.md before changing this repository. This is not the upstream source
checkout and not the Atreno application.
Read UPDATING.md before porting, building, packaging or changing recovery steps.

- Preserve private visibility. Do not enable GitHub Actions.
- Keep executable archives in private GitHub Releases, not Git history.
- Runtime is based on upstream v1.25.1912.0. Read README.md for the ordered
  layout/clipboard patch chain and the distinction between release and candidates.
  Source identity and original file hashes are in build/original-build-receipt.json.
  That receipt is historical: do not overwrite it to certify newer settings.
- build/recovery-manifest.json belongs to the immutable layout-fix.1 archive.
  Keep both historical receipts and published assets unchanged. A new archive
  needs its own versioned manifest measured from the exact packaged bytes;
  hash equality never proves a fresh Windows smoke.
- settings/settings.json is the reviewed daily configuration. Never copy the
  live settings directory wholesale: state.json, buffer_*.txt, elevated_*.txt,
  dumps, traces and backups contain session data and must stay outside Git/releases.
- A settings-only change needs a reviewed JSON diff and byte comparison, not a
  rebuilt EXE or restamped archive receipt. If the live JSON already matches,
  do not create a copy or commit merely to record another check.
- Preserve profile GUIDs, command lines and native input bindings unless requested.
- Do not close Terminal/WSL or restart agents to test restoration without permission.
- Run packaging/build/validation through the owner's machine-global heavy lock.
  Use literal path-scoped Git writes and keep unrelated work untouched.
- Changes to source or dependencies need new build and manual acceptance evidence.
  A private recovery release does not mean Microsoft accepted or shipped the patch.

## Agent documentation language

Reply to the owner in Russian; write agent-facing docs, rules, skills, plans,
lessons and code comments in English. Translate the project-owned Russian
sections used in the current task as part of that bounded change, gradually.
Preserve safety requirements, executable examples, paths, Russian UI/help text,
literal evidence and existing Markdown anchors. Do not sweep unrelated files,
private history or global instructions. `CLAUDE.md` imports this same rule.
