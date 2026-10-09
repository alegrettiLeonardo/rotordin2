#!/usr/bin/env bash
# Native AF boundary tests. Link actual solver math and the bundled backend.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
out=$(realpath -m -- "${1:-build/st41-af}")
base=${ST41_BASE_REF:-d185aba585f094e7d633b013ab88fa12b9cba1b4}
compiler=${FC:-gfortran}
command -v "$compiler" >/dev/null
mkdir -p "$out/baseline-source"
git show "$base:src/source/rdfra.f90" > "$out/baseline-source/rdfra.f90"
git rev-parse HEAD > "$out/current-head.txt"
git diff -- src/source/rdfra.f90 > "$out/current-source.diff"
printf '%s\n' "$base" > "$out/baseline-ref.txt"
"$compiler" --version > "$out/compiler.txt"
sha256sum src/source/rdfra.f90 "$out/baseline-source/rdfra.f90" \
    tests/st41/af_cases.f90 tests/st41/af_checked_cases.f90 > "$out/source.sha256"

for mode in release debug; do
    mkdir -p "$out/$mode/baseline" "$out/$mode/current"
    if ! make MODE="$mode" FC="$compiler" -j"${ST41_JOBS:-2}" > "$out/$mode/make.log" 2>&1; then
        tail -30 "$out/$mode/make.log" >&2
        exit 1
    fi
    cp "build/$mode/config.stamp" "$out/$mode/build-config.txt"
    flags=(-cpp -D_LINUX -std=f2018)
    if [[ $mode == debug ]]; then
        flags+=(-O0 -g -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
    else
        flags+=(-O3 -ffpe-summary=none)
    fi
    # Exclude the program and replace only rdfra for the original-code control.
    mapfile -t objects < <(awk '!/\/rotordin.o$|\/rdfra.o$/' "build/$mode/link.objects")
    printf '%s\n' "${objects[@]}" > "$out/$mode/common-link.objects"
    for variant in baseline current; do
        work="$out/$mode/$variant"
        rdfra_object="build/$mode/obj/solver/rdfra.o"
        (
            set -x
            if [[ $variant == baseline ]]; then
                rdfra_object="$work/rdfra.o"
                "$compiler" "${flags[@]}" -I"build/$mode/mod/solver" \
                    -c "$out/baseline-source/rdfra.f90" -o "$rdfra_object"
            fi
            "$compiler" "${flags[@]}" -I"build/$mode/mod/solver" \
                tests/st41/af_cases.f90 "$rdfra_object" "${objects[@]}" -o "$work/af_cases"
            if [[ $variant == current ]]; then
                "$compiler" "${flags[@]}" -I"build/$mode/mod/solver" \
                    tests/st41/af_checked_cases.f90 "$rdfra_object" "${objects[@]}" -o "$work/af_checked_cases"
            fi
        ) > "$work/compile.log" 2>&1
        sha256sum "$work/af_cases" > "$work/binary.sha256"
        "$work/af_cases" preserved > "$work/preserved.stdout" 2> "$work/preserved.stderr"
        printf '0\n' > "$work/preserved.returncode"
        rc=0
        (ulimit -c 0; timeout 15 "$work/af_cases" edge \
            > "$work/edge.stdout" 2> "$work/edge.stderr") || rc=$?
        printf '%s\n' "$rc" > "$work/edge.returncode"
        if [[ $variant == baseline ]]; then
            [[ $rc == 1 ]]
            rg -q 'STATE=F' "$work/edge.stdout"
            rg -q 'FAIL first/last-interval crossings' "$work/edge.stdout"
        else
            [[ $rc == 0 ]]
            "$work/af_checked_cases" > "$work/checked.stdout" 2> "$work/checked.stderr"
            printf '0\n' > "$work/checked.returncode"
            sha256sum "$work/af_checked_cases" >> "$work/binary.sha256"
        fi
        rg '^PEAK_FIT ' "$work/preserved.stdout" > "$work/peak-fit.txt"
        printf 'PASS AF %s %s: %s\n' "$mode" "$variant" \
            "$(rg '^AF_CASES PASS' "$work/preserved.stdout")"
    done
    cmp "$out/$mode/baseline/peak-fit.txt" "$out/$mode/current/peak-fit.txt"
    cat "$out/$mode/current/edge.stdout" "$out/$mode/current/checked.stdout"
done
printf 'RD2-07_NATIVE: PASS; old edge failure reproduced; fitted peak output byte-identical\n'
