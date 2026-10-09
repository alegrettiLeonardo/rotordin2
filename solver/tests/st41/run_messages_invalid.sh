#!/usr/bin/env bash
# Preserve a truly invalid numeric input after parser improvements.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
binary=$(realpath -- "${1:?solver binary required}")
out=$(realpath -m -- "${2:-build/st41-messages-invalid}")
variant=${3:-current}
[[ $variant == current || $variant == baseline ]]
[[ -x $binary ]]
fixture=$(realpath tests/st41/messages_invalid_sections.txt)
mkdir -p "$out"
sha256sum "$binary" "$fixture" > "$out/inputs.sha256"
longdir=$(printf 'path_%0140d' 1)
for path_kind in short long; do
    work="$out/$path_kind"
    mkdir -p "$work"
    input=./bad.txt
    if [[ $path_kind == long ]]; then
        mkdir -p "$work/$longdir"
        input="$longdir/bad.txt"
    fi
    cp -- "$fixture" "$work/$input"
    printf '%q ' "$binary" -m "$input" > "$work/command.txt"
    printf '\n' >> "$work/command.txt"
    rc=0
    (cd "$work"; ulimit -c 0; timeout 30 "$binary" -m "$input" \
        > stdout.out 2> stderr.out) || rc=$?
    printf '%s\n' "$rc" > "$work/returncode.txt"
    [[ $rc == 1 || $rc == 2 ]]
    if [[ $variant == baseline && $path_kind == long ]]; then
        rg -q 'End of record' "$work/stderr.out"
        printf 'PASS invalid input %s %s: old End of record reproduced; rc=%s\n' "$variant" "$path_kind" "$rc"
    else
        [[ $rc == 1 ]]
        rg -q 'entrada->error reading\(section\)' "$work/stderr.out"
        if rg -q 'End of record|Fortran runtime error|SIGSEGV|SIGFPE' "$work/stderr.out"; then
            cat "$work/stderr.out" >&2
            exit 1
        fi
        printf 'PASS invalid input %s %s: same section-reading error, controlled STOP 1\n' "$variant" "$path_kind"
    fi
done
