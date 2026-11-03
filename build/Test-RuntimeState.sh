#!/usr/bin/env bash
# Read-only drift check for the Windows Terminal recovery runtime.
#
# Reports portable runtimes installed under %LOCALAPPDATA%\Programs, compares
# the settings file used by the HCA outside-Terminal fallback with the reviewed
# repository snapshot, and checks that the resolver, its test fixture and the
# HCA runbook name the same runtime path. It never writes, launches, registers
# or switches anything; exit 1 means drift was found.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hca_root="${HCA_ROOT:-$HOME/hca-system-v3}"
resolver="$hca_root/modules/zsh/terminal/81-wt-split-panes.zsh"
ws_config="$hca_root/config/workspaces.yaml"
repo_settings="$repo_root/settings/settings.json"

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
info() { printf 'INFO  %s\n' "$*"; }
fail() {
    printf 'FAIL  %s\n' "$*"
    failures=$((failures + 1))
}
skip() { printf 'SKIP  %s\n' "$*"; }

localappdata="${WT_TERMINAL_LOCALAPPDATA:-}"
if [[ -z "$localappdata" ]]; then
    win_path=""
    if command -v cmd.exe >/dev/null 2>&1; then
        win_path="$( (cd /mnt/c && cmd.exe /d /c 'echo %LOCALAPPDATA%') 2>/dev/null | tr -d '\r')"
    fi
    if [[ ! "$win_path" =~ ^[A-Za-z]:\\ ]] && [[ -x /init && -x /mnt/c/Windows/System32/cmd.exe ]]; then
        win_path="$( (cd /mnt/c && /init /mnt/c/Windows/System32/cmd.exe /d /c 'echo %LOCALAPPDATA%') 2>/dev/null | tr -d '\r')"
    fi
    if [[ ! "$win_path" =~ ^[A-Za-z]:\\ ]]; then
        fail "cannot determine LOCALAPPDATA; set WT_TERMINAL_LOCALAPPDATA"
        exit 2
    fi
    localappdata="$(wslpath -u "$win_path" 2>/dev/null)"
fi
if [[ ! -d "$localappdata" ]]; then
    fail "LOCALAPPDATA is not readable: ${localappdata:-<empty>}"
    exit 2
fi

repo_sha="$(sha256sum "$repo_settings" 2>/dev/null | cut -d' ' -f1)"
if [[ -z "$repo_sha" ]]; then
    fail "missing repository settings snapshot: $repo_settings"
    exit 2
fi
info "repository settings sha256: $repo_sha"

# Installed portable runtimes: any directory holding .portable under Programs.
runtimes=()
while IFS= read -r marker; do
    runtimes+=("$(dirname "$marker")")
done < <(find "$localappdata/Programs" -maxdepth 3 -name '.portable' -type f 2>/dev/null | sort)

if ((${#runtimes[@]} == 0)); then
    fail "no portable runtime with .portable under $localappdata/Programs"
else
    for dir in "${runtimes[@]}"; do
        info "installed runtime: ${dir#"$localappdata/Programs/"}"
    done
fi

# Configured channel, when the workspace file is available.
if [[ -r "$ws_config" ]] && command -v yq >/dev/null 2>&1; then
    info "windows_terminal_channel: $(yq -r '.settings.windows_terminal_channel // "stable"' "$ws_config" 2>/dev/null)"
fi

# HCA outside-Terminal fallback: the literal portable_dir in the resolver.
if [[ ! -f "$resolver" ]]; then
    skip "HCA resolver not found: $resolver"
else
    fallback_rel="$(grep -oE 'Programs/WT-Layout-Fix-[^"]+' "$resolver" | head -1)"
    if [[ -z "$fallback_rel" ]]; then
        fail "no portable fallback path in $resolver"
    else
        fallback_dir="$localappdata/$fallback_rel"
        if [[ ! -d "$fallback_dir" ]]; then
            fail "HCA fallback points at a missing directory: $fallback_rel"
        else
            pass "HCA fallback directory exists: $fallback_rel"
            missing=0
            for required in .portable WindowsTerminal.exe settings/settings.json; do
                if [[ ! -f "$fallback_dir/$required" ]]; then
                    fail "HCA fallback is missing $required"
                    missing=1
                fi
            done
            if ((missing == 0)); then
                fallback_sha="$(sha256sum "$fallback_dir/settings/settings.json" 2>/dev/null | cut -d' ' -f1)"
                if [[ "$fallback_sha" == "$repo_sha" ]]; then
                    pass "HCA fallback settings match the repository snapshot"
                else
                    fail "HCA fallback settings differ from the repository snapshot (${fallback_sha:-missing})"
                fi
                info "fallback WindowsTerminal.exe sha256: $(sha256sum "$fallback_dir/WindowsTerminal.exe" 2>/dev/null | cut -d' ' -f1) ($(stat -c %s "$fallback_dir/WindowsTerminal.exe" 2>/dev/null) bytes)"
            fi
        fi
    fi
fi

# Cross-repository consistency: the resolver, its test fixture and the HCA
# runbook must name the same runtime path. A stale copy in any of them sends
# readers to a folder that no longer exists.
runtime_tail() {
    grep -oE 'WT-Layout-Fix-[A-Za-z0-9._-]+[\\/]terminal-[A-Za-z0-9._-]+' "$1" 2>/dev/null |
        tr '\\' '/' | sort -u
}
resolver_tails="$([[ -f "$resolver" ]] && runtime_tail "$resolver")"
if [[ -z "$resolver_tails" ]]; then
    skip "no runtime path found in the resolver; skipping path comparison"
else
    for reader in "test fixture:$hca_root/tests/test-wt-commands.sh" \
        "runbook:$hca_root/docs/04-commands/windows-terminal-tabs-panels.md"; do
        label="${reader%%:*}"
        file="${reader#*:}"
        if [[ ! -f "$file" ]]; then
            skip "$label not found: $file"
            continue
        fi
        tails="$(runtime_tail "$file")"
        if [[ -z "$tails" ]]; then
            fail "$label has no runtime path"
        elif [[ "$tails" == "$resolver_tails" ]]; then
            pass "$label matches the resolver path"
        else
            fail "$label names a different runtime: $(printf '%s' "$tails" | tr '\n' ' ')"
        fi
    done
fi

echo ""
if ((failures > 0)); then
    printf 'RESULT: FAIL (%d)\n' "$failures"
    exit 1
fi
printf 'RESULT: PASS\n'
