#!/usr/bin/env bash
# Índice (não git status) representa o próximo commit. Deleções não contam como arquivos.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
git rev-parse --is-inside-work-tree >/dev/null
TMP=$(mktemp)
trap 'rm -f -- "$TMP"' EXIT
git ls-files --cached -z > "$TMP"
bad=0; count=0
while IFS= read -r -d '' path; do
    count=$((count+1))
    lower=${path,,}
    case "$lower" in
        *.o|*.obj|*.mod|*.smod|*.a|*.exe|*.dll|*.so|*.so.*|*.py|*.pyc|*.pyo|*.log|build/*|bin/*|release/*|*/__pycache__/*)
            printf 'FAIL: artefato/infraestrutura removida no índice: %s\n' "$path" >&2; bad=1;;
    esac
    if [[ $path != */* && $path != .gitignore && $path != Makefile && $path != README.md ]]; then
        printf 'FAIL: arquivo extra na raiz do índice: %s\n' "$path" >&2; bad=1
    fi
done < "$TMP"
[[ $bad == 0 ]] || exit 1
printf 'GIT_INDEX: PASS; %s arquivos; sem produtos compilados/Python/Release\n' "$count"
