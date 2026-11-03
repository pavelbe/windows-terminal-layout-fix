# Windows Terminal Layout Fix — recovery repository

Public downstream patches and recovery kit for a tested Windows Terminal build.
Read README.md before changing this repository. This is not the upstream source
checkout and not the Atreno application.
Read UPDATING.md before porting, building, packaging or changing recovery steps.

- Repository is public by owner decision. Do not change visibility or enable Actions.
- Keep executable archives in reviewed GitHub Releases, not Git history;
  creating/replacing release assets still requires explicit owner authorization.
- Published `layout-fix.2` is based on upstream Preview `v1.25.1912.0`; current
  local candidates use Stable `v1.25.2733.0` (`rmb3`). Read README.md for the
  current runtime and ordered patch chain. Source identity and original hashes
  in build/original-build-receipt.json are historical; do not overwrite them.
- Inside a Windows Terminal session HCA follows the current portable runtime;
  outside Terminal, `wt` still resolves the absent 1.25.1912.0 clipboard-files
  folder and fails closed. Do not switch routing implicitly; update resolver,
  tests and runbook together only on owner request.
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
- Use literal path-scoped Git writes and keep unrelated work untouched.
- Changes to source or dependencies need new build and manual acceptance evidence.
  A downstream recovery release does not mean Microsoft accepted or shipped the patch.
- Before a Microsoft submission, read its current CONTRIBUTING.md and AGENTS.md
  AI policy plus our CONTRIBUTING.md. Publication needs separate authority.
- Packaging must reject a build layout containing a settings directory before
  any writes; read CONTRIBUTING.md for the offline regression. It is not build/UI proof.

## Agent documentation language

Reply to the owner in Russian; write agent-facing docs, rules, skills, plans,
lessons and code comments in English. Translate the project-owned Russian
sections used in the current task as part of that bounded change, gradually.
Preserve safety requirements, executable examples, paths, Russian UI/help text,
literal evidence and existing Markdown anchors. Do not sweep unrelated files,
private history or global instructions. `CLAUDE.md` imports this same rule.
