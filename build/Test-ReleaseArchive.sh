#!/usr/bin/env bash
# Self-test for build/release_archive.py using synthetic archives.
# Every case asserts the exit code and the expected diagnostic, so a broken
# guard fails loudly instead of passing silently.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tool="$repo_root/build/release_archive.py"
reviewed_settings="$repo_root/settings/settings.json"
work="$(mktemp -d /tmp/lf-release-selftest.XXXXXX)"
trap 'rm -rf "$work"' EXIT INT TERM

passed=0
failed=0
pass() {
    printf 'PASS  %s\n' "$*"
    passed=$((passed + 1))
}
fail() {
    printf 'FAIL  %s\n' "$*"
    failed=$((failed + 1))
}

python3 -I - "$work" "$reviewed_settings" <<'PY'
import os, shutil, sys, zipfile
work, reviewed = sys.argv[1], sys.argv[2]
root = 'WT-Layout-Fix-1.25.2733.0-layout-fix.3'
settings = open(reviewed, 'rb').read()

def make(name, extra=None, settings_bytes=None):
    path = os.path.join(work, name)
    with zipfile.ZipFile(path, 'w') as bundle:
        bundle.writestr(root + '/.portable', b'')
        bundle.writestr(root + '/WindowsTerminal.exe', b'EXE')
        bundle.writestr(root + '/settings/settings.json', settings if settings_bytes is None else settings_bytes)
        for key, value in (extra or {}).items():
            bundle.writestr(root + '/' + key, value)
    return path

make('good.zip')
make('tampered.zip', extra={'docs/x.txt': b'good'})
make('tampered2.zip', extra={'docs/x.txt': b'bad'})
make('bad-settings.zip', settings_bytes=b'{"other":1}')
make('state.zip', extra={'settings/state.json': b'{}'})
PY

run_manifest() {
    python3 -I "$tool" manifest "$1" --tag selftest --root "WT-Layout-Fix-1.25.2733.0-layout-fix.3" \
        --release-receipt x --upstream-tag u --upstream-commit c --source-commit s \
        --proof p --reviewed-settings "$reviewed_settings" --out "$2" >"$3" 2>&1
}
run_verify() {
    python3 -I "$tool" verify "$1" --manifest "$2" >"$3" 2>&1
}

expect() {
    local label=$1 expected=$2 actual=$3 log=$4 pattern=$5
    if [[ "$actual" != "$expected" ]]; then
        fail "$label: exit $actual, expected $expected"
        sed 's/^/      /' "$log"
        return
    fi
    if ! grep -q "$pattern" "$log"; then
        fail "$label: missing '$pattern'"
        sed 's/^/      /' "$log"
        return
    fi
    pass "$label"
}

run_manifest "$work/good.zip" "$work/good.json" "$work/gen-good.log"
expect "manifest accepts a reviewed archive" 0 "$?" "$work/gen-good.log" 'PASS  wrote'

run_verify "$work/good.zip" "$work/good.json" "$work/verify-good.log"
expect "verify accepts an intact archive" 0 "$?" "$work/verify-good.log" 'RESULT: PASS'

run_verify "$work/tampered2.zip" "$work/good.json" "$work/verify-tampered.log"
expect "verify rejects tampered bytes" 1 "$?" "$work/verify-tampered.log" 'mismatched'

run_manifest "$work/bad-settings.zip" "$work/bad.json" "$work/gen-badsettings.log"
expect "manifest rejects a settings snapshot that differs from the repository" 1 "$?" \
    "$work/gen-badsettings.log" 'differs from the reviewed repository snapshot'

run_manifest "$work/state.zip" "$work/state.json" "$work/gen-state.log"
expect "manifest rejects live session state" 1 "$?" "$work/gen-state.log" 'carries live session state'

echo ""
printf 'RESULT: %s (%d passed, %d failed)\n' \
    "$([[ $failed -eq 0 ]] && echo PASS || echo FAIL)" "$passed" "$failed"
[[ $failed -eq 0 ]]
