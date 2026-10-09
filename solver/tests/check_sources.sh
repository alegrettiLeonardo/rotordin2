#!/usr/bin/env bash
# Manifestos são evidência revisada; este script nunca os regenera.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ ${1-} == --layout ]]; then
    mapfile -t files < <(find . -maxdepth 1 -type f ! -name .git -printf '%f\n' | sort)
    if [[ ${#files[@]} != 3 || ${files[0]-} != .gitignore || ${files[1]-} != Makefile || ${files[2]-} != README.md ]]; then
        printf 'FAIL: raiz deve conter somente .gitignore, Makefile e README.md; encontrados:\n%s\n' "${files[*]}" >&2
        echo 'CI deve ser configurado em docs/ci/gitlab-ci.yml antes de remover sua configuração antiga.' >&2
        exit 1
    fi
    [[ ! -e Release ]] || { echo 'FAIL: Release ainda presente' >&2; exit 1; }
    echo 'LAYOUT: PASS (README.md, Makefile e .gitignore na raiz; sem Release)'
    exit 0
fi
for cmd in sha256sum find sort comm awk cmp; do command -v "$cmd" >/dev/null; done
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
for manifest in SOLVER LAPACK TESTS BUILD; do
    sha256sum --check --strict --status "docs/manifests/$manifest.sha256" || {
        echo "FAIL: divergência em docs/manifests/$manifest.sha256" >&2
        sha256sum --check --strict "docs/manifests/$manifest.sha256" >&2 || true
        exit 1
    }
done
# Igualdade do inventário, não só verificação dos arquivos existentes.
find src/source docs/legacy/lapack -type f | sort > "$TMP/actual"
awk '{print $2}' docs/manifests/SOLVER.sha256 | sort > "$TMP/expected"
if ! cmp -s "$TMP/expected" "$TMP/actual"; then
    echo 'FAIL: arquivo científico ausente/extra' >&2
    comm -3 "$TMP/expected" "$TMP/actual" >&2; exit 1
fi
find lapack/lapack-3.12.1 -type f | sort > "$TMP/actual"
awk '{print $2}' docs/manifests/LAPACK.sha256 | sort > "$TMP/expected"
if ! cmp -s "$TMP/expected" "$TMP/actual"; then
    echo 'FAIL: arquivo upstream ausente/extra' >&2
    comm -3 "$TMP/expected" "$TMP/actual" >&2; exit 1
fi
if find src lapack tests -type l -print | grep . > "$TMP/links"; then
    echo 'FAIL: link simbólico em árvore de fontes' >&2; cat "$TMP/links" >&2; exit 1
fi
for list in solver lapack; do
    base=src/source; [[ $list == lapack ]] && base=lapack/lapack-3.12.1
    while IFS= read -r rel; do
        [[ -n $rel && $rel != /* && $rel != *..* && $rel != *' '* ]] || { echo "FAIL: caminho na lista $list" >&2; exit 1; }
        [[ -f "$base/$rel" ]] || { echo "FAIL: $base/$rel ausente" >&2; exit 1; }
    done < "docs/build/$list-sources.lst"
done
if find src lapack tests -type f \( -iname '*.py' -o -iname '*.a' -o -iname '*.o' -o -iname '*.mod' -o -iname '*.smod' \) -print | grep . > "$TMP/generated"; then
    echo 'FAIL: código Python/artefato compilado na árvore de fontes' >&2; cat "$TMP/generated" >&2; exit 1
fi
printf 'INTEGRITY: PASS; solver original=%s; fontes LAPACK selecionados=%s\n' \
    "$(wc -l < docs/manifests/SOLVER.sha256)" "$(wc -l < docs/build/lapack-sources.lst)"
