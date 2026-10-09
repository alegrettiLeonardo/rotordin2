#!/usr/bin/env bash
# Teste do binário local conhecido, dos objetos e da proveniência no mapa de link.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
BIN=${1:?binário requerido}; BUILD=${2:?diretório de build requerido}
[[ -x $BIN && -s $BUILD/link.map && -s $BUILD/link.objects ]]
for cmd in readelf nm ldd; do command -v "$cmd" >/dev/null; done
mkdir -p "$BUILD/tests"
readelf -d "$BIN" > "$BUILD/tests/dynamic.txt"
if grep -iE 'NEEDED.*(lapack|blas|mkl)' "$BUILD/tests/dynamic.txt"; then
    echo 'FAIL: dependência numérica externa' >&2; exit 1
fi
if grep -q 'NEEDED' "$BUILD/tests/dynamic.txt"; then
    ldd "$BIN" > "$BUILD/tests/ldd.txt" 2>&1 || { cat "$BUILD/tests/ldd.txt" >&2; exit 1; }
    if grep -iE 'not found|lapack|blas|mkl' "$BUILD/tests/ldd.txt"; then
        echo 'FAIL: dependência ausente ou backend externo' >&2; exit 1
    fi
else
    printf '%s\n' 'No dynamic NEEDED entries' > "$BUILD/tests/ldd.txt"
fi
nm -g --defined-only "$BIN" > "$BUILD/tests/symbols.txt"
for name in dgemm zggevx dgetrf zgetrf dgees dggevx dpotrf dsyev dsygv dtrsen zgesvd; do
    grep -Eq " [Tt] ${name}_$" "$BUILD/tests/symbols.txt" || {
        echo "FAIL: símbolo ${name}_ não definido no binário" >&2; exit 1;
    }
done
mapfile -t objects < "$BUILD/link.objects"
[[ ${#objects[@]} == $(( $(wc -l < docs/build/solver-sources.lst) + $(wc -l < docs/build/lapack-sources.lst) )) ]]
linalg=()
for obj in "${objects[@]}"; do
    case "$obj" in
        "$BUILD/obj/solver/"*.o) ;;
        "$BUILD/obj/lapack/"*.o) linalg+=("$obj");;
        *) echo "FAIL: objeto fora do build local: $obj" >&2; exit 1;;
    esac
    [[ -s $obj ]]
    grep -Fx "LOAD $obj" "$BUILD/link.map" >/dev/null || { echo "FAIL: LOAD não registrado: $obj" >&2; exit 1; }
done
nm -A -g --defined-only "${linalg[@]}" > "$BUILD/tests/lapack-symbol-origins.txt"
if grep -E 'LOAD .*([/]legacy[/]|Release[/]|lib(lapack|blas|openblas)[.])' "$BUILD/link.map"; then
    echo 'FAIL: mapa contém backend antigo/externo' >&2; exit 1
fi
printf 'LINK_AUDIT: PASS; %s objetos locais; LAPACK/BLAS 3.12.1; sem agregados históricos\n' "${#objects[@]}"
