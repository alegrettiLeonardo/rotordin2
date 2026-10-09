#!/usr/bin/env bash
# Actual native pencils/Schur factors, independent oscillator oracles and old controls.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
out=$(realpath -m -- "${1:-build/st41-p1/poles}")
base=${ST41_BASE_REF:-d185aba585f094e7d633b013ab88fa12b9cba1b4}
compiler=${FC:-gfortran}
mkdir -p "$out/baseline-source"
sources=(rd_kinds rd_commons rd_sys rd_textfun rd_modal_metrics rd_modal_tracking rd_spectral_families matfun messages init espmod)
for source in "${sources[@]}"; do
    git show "$base:src/source/$source.f90" > "$out/baseline-source/$source.f90"
done
git rev-parse HEAD > "$out/current-head.txt"
git diff -- src/source/rd_modal_metrics.f90 src/source/espmod.f90 > "$out/current-source.diff"
printf '%s\n' "$base" > "$out/baseline-ref.txt"
"$compiler" --version > "$out/compiler.txt"
sha256sum tests/st41/p1_poles.f90 src/source/rd_modal_metrics.f90 src/source/espmod.f90 \
    "$out/baseline-source/rd_modal_metrics.f90" "$out/baseline-source/espmod.f90" > "$out/source.sha256"
for mode in release debug; do
    mkdir -p "$out/$mode"
    if ! make MODE="$mode" FC="$compiler" -j"${ST41_JOBS:-2}" > "$out/$mode/make.log" 2>&1; then
        tail -30 "$out/$mode/make.log" >&2; exit 1
    fi
    cp "build/$mode/config.stamp" "$out/$mode/build-config.txt"
    mapfile -t linalg < <(awk '/\/obj\/lapack\//' "build/$mode/link.objects")
    flags=(-cpp -D_LINUX -std=f2018 -ffunction-sections -fdata-sections)
    if [[ $mode == debug ]]; then
        flags+=(-O0 -g -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
    else
        flags+=(-O3 -ffpe-summary=none)
    fi
    for variant in baseline current; do
        work="$out/$mode/$variant"
        mkdir -p "$work/mod"
        src=src/source
        define=(-DST41_P1)
        if [[ $variant == baseline ]]; then src="$out/baseline-source"; define=(); fi
        objects=()
        (
            set -x
            for source in "${sources[@]}"; do
                "$compiler" "${flags[@]}" -I"$work/mod" -J"$work/mod" \
                    -c "$src/$source.f90" -o "$work/$source.o"
                objects+=("$work/$source.o")
            done
            "$compiler" "${flags[@]}" "${define[@]}" -I"$work/mod" -J"$work/mod" \
                -Wl,--gc-sections tests/st41/p1_poles.f90 "${objects[@]}" "${linalg[@]}" -o "$work/p1_poles"
        ) > "$work/compile.log" 2>&1
        sha256sum "$work/p1_poles" > "$work/binary.sha256"
        for driver in pencil schur; do
            for case in free stable unstable weak_unstable soft_unstable; do
                "$work/p1_poles" "$case" "$driver" > "$work/$case-$driver.stdout" 2> "$work/$case-$driver.stderr"
                printf '0\n' > "$work/$case-$driver.returncode"
                rg -q "P1_POLES_NATIVE PASS $case $driver" "$work/$case-$driver.stdout"
                if [[ $variant == current ]]; then
                    case "$case" in
                        stable) status=ASYMPTOTICALLY_STABLE;;
                        unstable|soft_unstable) status=UNSTABLE;;
                        free) status=MARGINAL_UNRESOLVED;;
                        weak_unstable) status='MARGINAL_UNRESOLVED|UNSTABLE';;
                    esac
                    rg -q "SPECTRUM $case .* ($status) " "$work/$case-$driver.stdout"
                fi
            done
        done
        printf 'PASS P1 poles %s %s: 10 native matrix controls\n' "$mode" "$variant"
    done
    # A physical real root of +1e-12 is resolved by its own component scale;
    # the old blanket 1e-10 floor hid it. Keep that old failure as evidence.
    rg -q 'SPECTRUM soft_unstable .* MARGINAL_UNRESOLVED ' "$out/$mode/baseline/soft_unstable-pencil.stdout"
    rg -q 'SPECTRUM soft_unstable .* UNSTABLE ' "$out/$mode/current/soft_unstable-pencil.stdout"
    for driver in pencil schur; do
        for case in free stable unstable weak_unstable soft_unstable; do
            rg '^RAW_POLE ' "$out/$mode/baseline/$case-$driver.stdout" > "$out/$mode/baseline/raw.txt"
            rg '^RAW_POLE ' "$out/$mode/current/$case-$driver.stdout" > "$out/$mode/current/raw.txt"
            cmp "$out/$mode/baseline/raw.txt" "$out/$mode/current/raw.txt"
        done
    done
done
printf 'P1_POLES: PASS; raw poles/decrements byte-identical; resolved positive roots retained\n'
