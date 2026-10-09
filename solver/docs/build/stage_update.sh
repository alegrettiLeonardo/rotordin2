#!/usr/bin/env bash
# Helper explícito de staging da migração; nunca chamado pelo Makefile.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
ACTION=${1:---dry-run}
[[ $ACTION == --dry-run || $ACTION == --apply ]] || { echo 'Use --dry-run ou --apply' >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null
[[ -z $(git ls-files --unmerged) ]] || { echo 'Resolva os conflitos Git primeiro.' >&2; exit 1; }
TMP=$(mktemp)
trap 'rm -f -- "$TMP"' EXIT
count=0
while IFS= read -r path; do
    [[ -n $path && $path != /* && $path != *..* ]] || continue
    if [[ -e $path ]] || git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
        printf '%s\0' "$path" >> "$TMP"; count=$((count+1))
    fi
done < docs/build/migration-stage-paths.lst
# Renomes de layout: inclui a origem antiga para que deleções/renomes sejam staged.
for path in README.md docs/README.md lapack third_party; do
    if [[ -e $path ]] || git ls-files -- "$path" | grep -q .; then
        printf '%s\0' "$path" >> "$TMP"; count=$((count+1))
    fi
done
printf 'Escopo da migração: %s caminhos existentes/rastreados.\n' "$count"
if [[ $ACTION == --apply ]]; then
    git add -A --pathspec-from-file="$TMP" --pathspec-file-nul
    bash tests/check_index.sh
    git diff --cached --shortstat
else
    echo 'DRY_RUN: índice preservado. Use --apply após revisar git status e git diff.'
fi
