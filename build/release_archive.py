#!/usr/bin/env python3
"""Generate or verify a release manifest for a portable Terminal archive.

manifest: measure an archive and write build/recovery-manifest-<tag>.json.
verify:   check a downloaded archive against an existing manifest.

A release may carry the reviewed settings/settings.json only. Live session state
(state.json, buffers, elevated prompts, dumps, traces, logs, backups) must never
leave the machine inside an archive, and the settings snapshot must be byte-
identical to the reviewed repository file.
"""

import argparse
import hashlib
import json
import os
import sys
import zipfile

SESSION_STATE_PATTERNS = ("state.json", "buffer_*.txt", "elevated_*.txt")
SESSION_STATE_SUFFIXES = (".bak", ".dmp", ".etl", ".log")


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def session_state_entries(names):
    """Return archive entries that look like live session state."""
    import fnmatch

    hits = []
    for name in names:
        parts = name.replace("\\", "/").split("/")
        base = parts[-1]
        parent = parts[-2] if len(parts) > 1 else ""
        if parent == "settings" and base != "settings.json":
            hits.append(name)
            continue
        if any(fnmatch.fnmatchcase(base, pattern) for pattern in SESSION_STATE_PATTERNS):
            hits.append(name)
            continue
        if base.lower().endswith(SESSION_STATE_SUFFIXES):
            hits.append(name)
    return hits


def archive_entries(archive):
    """Return (name, size, sha256) for every file entry."""
    entries = {}
    with zipfile.ZipFile(archive) as bundle:
        for info in bundle.infolist():
            if info.is_dir():
                continue
            digest = hashlib.sha256()
            with bundle.open(info) as member:
                for chunk in iter(lambda: member.read(1 << 20), b""):
                    digest.update(chunk)
            entries[info.filename] = {"size": info.file_size, "sha256": digest.hexdigest()}
    return entries


def relative_files(entries, root):
    root_prefix = root.rstrip("/") + "/"
    files = {}
    outside = []
    for name, meta in entries.items():
        normalized = name.replace("\\", "/")
        if not normalized.startswith(root_prefix):
            outside.append(name)
            continue
        files[normalized[len(root_prefix):]] = meta
    return files, outside


def fail(message):
    print(f"FAIL  {message}")
    return 1


def cmd_manifest(args):
    entries = archive_entries(args.archive)
    state = session_state_entries(entries)
    if state:
        return fail(f"archive carries live session state under {state[0]}")
    files, outside = relative_files(entries, args.root)
    if outside:
        return fail(f"archive entry outside the expected root {args.root}: {outside[0]}")
    if not files:
        return fail(f"archive has no files under {args.root}")
    settings = files.get("settings/settings.json")
    if settings is None:
        return fail("archive has no settings/settings.json")
    reviewed = sha256_file(args.reviewed_settings)
    if settings["sha256"] != reviewed:
        return fail(
            "settings/settings.json differs from the reviewed repository snapshot "
            f"({settings['sha256'][:16]}... != {reviewed[:16]}...)"
        )
    manifest = {
        "schemaVersion": 1,
        "releaseTag": args.tag,
        "archive": {
            "name": os.path.basename(args.archive),
            "sha256": sha256_file(args.archive),
            "size": os.path.getsize(args.archive),
            "root": args.root,
        },
        "releaseReceipt": args.release_receipt,
        "upstreamTag": args.upstream_tag,
        "upstreamCommit": args.upstream_commit,
        "sourceCommit": args.source_commit,
        "proof": args.proof,
        "files": dict(sorted(files.items())),
    }
    with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print(f"PASS  wrote {args.out}: {len(files)} files, archive sha256 {manifest['archive']['sha256']}")
    return 0


def cmd_verify(args):
    with open(args.manifest, encoding="utf-8") as handle:
        manifest = json.load(handle)
    failures = 0

    def check(condition, message):
        nonlocal failures
        if condition:
            print(f"PASS  {message}")
        else:
            print(f"FAIL  {message}")
            failures += 1

    archive = manifest["archive"]
    actual_sha = sha256_file(args.archive)
    check(actual_sha == archive["sha256"], f"archive sha256 matches manifest ({actual_sha[:16]}...)")
    check(os.path.getsize(args.archive) == archive["size"], "archive size matches manifest")

    entries = archive_entries(args.archive)
    state = session_state_entries(entries)
    check(not state, "archive carries no live session state")
    files, outside = relative_files(entries, archive["root"])
    check(not outside, f"every archive entry is under {archive['root']}")

    expected = manifest["files"]
    missing = sorted(set(expected) - set(files))
    extra = sorted(set(files) - set(expected))
    check(not missing, f"manifest files present in archive ({len(missing)} missing)")
    check(not extra, f"archive has no unexpected files ({len(extra)} extra)")

    mismatched = []
    for name in sorted(set(expected) & set(files)):
        if expected[name]["sha256"] != files[name]["sha256"] or expected[name]["size"] != files[name]["size"]:
            mismatched.append(name)
    check(not mismatched, f"every file hash and size matches ({len(mismatched)} mismatched)")

    print("")
    if failures:
        print(f"RESULT: FAIL ({failures})")
        return 1
    print("RESULT: PASS")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    manifest = sub.add_parser("manifest", help="measure an archive into a manifest")
    manifest.add_argument("archive")
    manifest.add_argument("--tag", required=True)
    manifest.add_argument("--root", required=True)
    manifest.add_argument("--release-receipt", required=True)
    manifest.add_argument("--upstream-tag", required=True)
    manifest.add_argument("--upstream-commit", required=True)
    manifest.add_argument("--source-commit", required=True)
    manifest.add_argument("--proof", required=True)
    manifest.add_argument("--reviewed-settings", required=True)
    manifest.add_argument("--out", required=True)
    manifest.set_defaults(func=cmd_manifest)

    verify = sub.add_parser("verify", help="verify an archive against a manifest")
    verify.add_argument("archive")
    verify.add_argument("--manifest", required=True)
    verify.set_defaults(func=cmd_verify)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
