#!/usr/bin/env bash
# Native RD2-11 tests and controlled failures of the imported source.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
out=$(realpath -m -- "${1:-build/st41-messages}")
base=${ST41_BASE_REF:-d185aba585f094e7d633b013ab88fa12b9cba1b4}
compiler=${FC:-gfortran}
command -v "$compiler" >/dev/null
mkdir -p "$out/baseline-source"
git rev-parse HEAD > "$out/current-head.txt"
git diff -- src/source/rd_textfun.f90 > "$out/current-source.diff"
printf '%s\n' "$base" > "$out/baseline-ref.txt"
"$compiler" --version > "$out/compiler.txt"
for source in rd_kinds rd_commons rd_textfun; do
    git show "$base:src/source/$source.f90" > "$out/baseline-source/$source.f90"
done
sha256sum src/source/rd_textfun.f90 tests/st41/messages_cases.f90 \
    "$out/baseline-source/rd_textfun.f90" > "$out/source.sha256"

for mode in release debug; do
    flags=(-cpp -D_LINUX -std=f2018 -ffunction-sections -fdata-sections)
    if [[ $mode == debug ]]; then
        flags+=(-O0 -g -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
    else
        flags+=(-O3 -ffpe-summary=none)
    fi
    for variant in baseline current; do
        build="$out/$mode/$variant"
        mkdir -p "$build/mod"
        source_dir=src/source
        [[ $variant == baseline ]] && source_dir="$out/baseline-source"
        (
            set -x
            for source in rd_kinds rd_commons rd_textfun; do
                "$compiler" "${flags[@]}" -I"$build/mod" -J"$build/mod" \
                    -c "$source_dir/$source.f90" -o "$build/$source.o"
            done
            "$compiler" "${flags[@]}" -I"$build/mod" -J"$build/mod" -Wl,--gc-sections \
                tests/st41/messages_cases.f90 "$build/rd_kinds.o" "$build/rd_commons.o" \
                "$build/rd_textfun.o" -o "$build/messages_cases"
        ) > "$build/compile.log" 2>&1
        sha256sum "$build/messages_cases" > "$build/binary.sha256"
        test_mode=all
        [[ $variant == baseline ]] && test_mode=short
        "$build/messages_cases" "$test_mode" > "$build/pass.stdout" 2> "$build/pass.stderr"
        printf '0\n' > "$build/pass.returncode"
        if [[ $variant == baseline ]]; then
            for failure in long_optional long_section; do
                rc=0
                (ulimit -c 0; timeout 15 "$build/messages_cases" "$failure" \
                    > "$build/$failure.stdout" 2> "$build/$failure.stderr") || rc=$?
                printf '%s\n' "$rc" > "$build/$failure.returncode"
                [[ $rc != 0 && $rc != 124 ]]
                rg -q 'End of record' "$build/$failure.stderr"
            done
        fi
        printf 'PASS messages %s %s: %s\n' "$mode" "$variant" "$(cat "$build/pass.stdout")"
    done
done
printf 'RD2-11_NATIVE: PASS; old optional/context overruns reproduced in release and debug\n'
