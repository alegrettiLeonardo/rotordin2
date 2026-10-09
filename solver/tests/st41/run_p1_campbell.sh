#!/usr/bin/env bash
# Generic real-family and manufactured vector routes, actual native binaries.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
out=$(realpath -m -- "${1:-build/st41-p1/campbell}")
baseline_release=$(realpath -- "${2:-evidence/baseline/rotordin2-baseline}")
baseline_debug=$(realpath -- "${3:-evidence/baseline/rotordin2-debug-baseline}")
compiler=${FC:-gfortran}
[[ -x $baseline_release && -x $baseline_debug ]]
mkdir -p "$out"
git rev-parse HEAD > "$out/current-head.txt"
git diff -- src/source/rd_campbell_engine.f90 src/source/rd_campbell_families.f90 > "$out/current-source.diff"
"$compiler" --version > "$out/compiler.txt"
sha256sum "$baseline_release" "$baseline_debug" tests/fixtures/simple2b-sp.txt \
    src/source/rd_campbell_engine.f90 src/source/rd_campbell_families.f90 \
    tests/st41/p1_compare_campbell.f90 tests/st41/p1_vectors.f90 > "$out/source-binaries.sha256"
compile_recorded() {
    local log=$1
    shift
    printf '%q ' "$@" > "$log.command.txt"
    printf '\n' >> "$log.command.txt"
    "$@" > "$log" 2>&1
}
compile_recorded "$out/compare-campbell-compile.log" "$compiler" -O0 -g -std=f2018 -fcheck=all -fbacktrace \
    tests/st41/p1_compare_campbell.f90 -o "$out/p1_compare_campbell"
compile_recorded "$out/compare-frozen-compile.log" "$compiler" -O0 -g -std=f2018 -fcheck=all -fbacktrace \
    tests/compare_results.f90 -o "$out/compare_frozen_critical_speeds"
sha256sum "$out/p1_compare_campbell" "$out/compare_frozen_critical_speeds" > "$out/comparison-binaries.sha256"
fixture=$(realpath tests/fixtures/simple2b-sp.txt)

run_native() {
    local binary=$1 work=$2
    shift 2
    local rc=0
    sha256sum "$binary" "$work/input.txt" > "$work/inputs.sha256"
    printf '%q ' "$binary" "$@" > "$work/command.txt"
    printf '< input.txt\n' >> "$work/command.txt"
    (cd "$work"; ulimit -c 0; timeout 90 "$binary" "$@" < input.txt > stdout.out 2> stderr.log) || rc=$?
    printf '%s\n' "$rc" > "$work/returncode.txt"
    if [[ $rc != 0 ]]; then
        tail -30 "$work/stderr.log" >&2
        echo "FAIL native Campbell: rc=$rc evidence=$work" >&2; exit 1
    fi
}

extract_plot() {
    awk '
      /Natural frequencies \(rpm\) x \(Hz\)/ {found=1; next}
      found && /^ *rpm / {rows=1; next}
      rows && NF==0 {exit}
      rows {print; count++}
      END {if(count!=50)exit 1}
    ' "$1"
}

for mode in release debug; do
    mkdir -p "$out/$mode"
    if ! make MODE="$mode" FC="$compiler" -j"${ST41_JOBS:-2}" > "$out/$mode/make.log" 2>&1; then
        tail -25 "$out/$mode/make.log" >&2; exit 1
    fi
    binary=$(realpath bin/rotordin2)
    old=$baseline_release
    flags=(-O3 -cpp -std=f2018 -ffpe-summary=none)
    if [[ $mode == debug ]]; then
        binary=$(realpath bin/rotordin2-debug);old=$baseline_debug
        flags=(-O0 -g -cpp -std=f2018 -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
    fi
    cp "build/$mode/config.stamp" "$out/$mode/build-config.txt"
    sha256sum "$binary" > "$out/$mode/current-binary.sha256"
    for variant in baseline current; do
        active=$binary
        if [[ $variant == baseline ]]; then active=$old; fi
        for count in 5 25; do
            work="$out/$mode/$variant/cpb$count"
            mkdir -p "$work"
            # CPBSPD alone changes; geometry, bearings and display grid are identical.
            awk -v count="$count" '
              after {print substr($0,1,20) sprintf("%-10d",count) substr($0,31); after=0; next}
              /^CPBIS/ {after=1}
              {print}
            ' "$fixture" > "$work/input.txt"
            run_native "$active" "$work" -std -c -b
            rg -q '#PROGRESS ANALYSIS=CAMPBELL EVENT=END STATUS=OK' "$work/stderr.log"
            if rg -q '#BEGIN MODEL_ERROR|Fortran runtime error' "$work/stdout.out" "$work/stderr.log"; then
                echo "FAIL model/runtime diagnostic: $work" >&2; exit 1
            fi
        done
        "$out/p1_compare_campbell" "$out/$mode/$variant/cpb5/stdout.out" \
            "$out/$mode/$variant/cpb25/stdout.out" "$variant" > "$out/$mode/$variant/comparison.txt"
        cat "$out/$mode/$variant/comparison.txt"
    done
    # Keep the pre-existing independent frozen regression and its tolerances.
    "$out/compare_frozen_critical_speeds" tests/fixtures/critical_speeds.reference \
        "$out/$mode/current/cpb25/stdout.out" > "$out/$mode/frozen-comparison.txt"
    cat "$out/$mode/frozen-comparison.txt"

    # Full production objects, including real PRPKC/ADJEIG and bundled LAPACK;
    # replace only the main program with the manufactured physical control.
    mapfile -t objects < <(awk '!/\/obj\/solver\/rotordin.o$/' "build/$mode/link.objects")
    compile_recorded "$out/$mode/vectors-compile.log" "$compiler" "${flags[@]}" \
        -I"build/$mode/mod/solver" tests/st41/p1_vectors.f90 "${objects[@]}" -o "$out/$mode/p1_vectors"
    sha256sum "$out/$mode/p1_vectors" > "$out/$mode/vector-binary.sha256"
    for count in 5 25 500; do
        display=50
        if [[ $count == 500 ]]; then display=500; fi
        work="$out/$mode/vectors/cpb$count"
        mkdir -p "$work"
        : > "$work/input.txt"
        run_native "$out/$mode/p1_vectors" "$work" "$count" "$display"
        rg -q 'P1_VECTORS_NATIVE PASS' "$work/stdout.out"
        [[ $(rg -c '^RD_AUDIT_V1 DISPLAY_POINT .* RESOLVED ' "$work/stdout.out") == "$display" ]]
        rg -q 'PRESENTATION_IDENTITY_CONTINUED_MODAL_VECTORS' "$work/stdout.out"
        rg -q "CROSSING_COVERAGE FINITE_ADAPTIVE_GRID $display$" "$work/stdout.out"
        "$out/p1_compare_campbell" --vectors "$work/stdout.out" > "$work/polynomial-oracle.txt"
        cat "$work/polynomial-oracle.txt"
    done
    extract_plot "$out/$mode/vectors/cpb5/stdout.out" > "$out/$mode/vectors/cpb5/plot.txt"
    extract_plot "$out/$mode/vectors/cpb25/stdout.out" > "$out/$mode/vectors/cpb25/plot.txt"
    cmp "$out/$mode/vectors/cpb5/plot.txt" "$out/$mode/vectors/cpb25/plot.txt"
    printf 'P1_VECTORS: PASS %s; CPB5/25 plots identical; 500/500 capacity boundary passed\n' "$mode"
done
printf 'P1_CAMPBELL: PASS; old interpolation failure retained; corrected native spectra/plots/intersections agree\n'
