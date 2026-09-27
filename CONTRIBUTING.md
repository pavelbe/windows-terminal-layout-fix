# Contributing

This repository maintains downstream patches, packaging and recovery guidance.
Microsoft owns upstream design, review and release decisions. Start with a
small reproducible issue here; include the exact EXE version/path, Windows
version, reproduction and whether the official unpatched build behaves the same.
Redact private paths and never attach terminal buffers, session state or credentials.

For a source change, read [UPDATING.md](UPDATING.md), apply the ordered patches
against the exact upstream SHA and run the relevant upstream tests. Report
build results and actual manual UI coverage separately. Keep existing releases,
receipts and the working installation unchanged. For packaging changes, run
`pwsh -NoProfile -File build/Test-PackageClipboardCandidate.ps1`.

## Working with Microsoft upstream

Read Microsoft's current [contributor guide](https://github.com/microsoft/terminal/blob/main/CONTRIBUTING.md)
and [AI Usage Policy](https://github.com/microsoft/terminal/blob/main/AGENTS.md)
before submitting an issue, comment or PR. A maintainer specifically
[requested this on our thread](https://github.com/microsoft/terminal/issues/11522#issuecomment-5747036212).

As checked on 2026-09-27, that policy requires disclosure of AI use and personal
verification of findings/evidence for AI-assisted bug reports and code reviews.
Other public AI-authored interactions must fit its explicit permitted categories;
merely approving generated output does not count as major human input. Before
submitting code, the contributor must read and understand the complete change
and inspect relevant tests/application behavior. Recheck the current policy;
this summary does not replace it or grant submission permission.

The existing layout and clipboard comments contain proposed patches and local
evidence. Neither a comment, a downstream release nor a closed issue proves
Microsoft accepted, merged or shipped our code. Link an actual upstream PR or
commit before making that claim. Keep Microsoft's copyright and license notices.
