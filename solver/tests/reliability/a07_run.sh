#!/usr/bin/env bash
# Native numerical proof under declared kinematics plus fail-closed actual CLI.
# A successful runner does NOT release production nonconstant-spin analyses.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
MODE=${1:-release}
OUT=$(realpath -m -- "${2:-build/a07-$MODE}")
FC=${FC:-gfortran}
PYTHON=${PYTHON:-python3}
BASE=4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47
[[ $MODE == release || $MODE == debug ]]
mkdir -p "$OUT/control-mod"
make MODE="$MODE" FC="$FC" -j"${RELIABILITY_JOBS:-4}" > "$OUT/build.txt" 2>&1
git rev-parse HEAD > "$OUT/source_commit.txt"
git status --porcelain=v1 > "$OUT/source_status.txt"
cp "build/$MODE/config.stamp" "$OUT/config.stamp"
BIN=bin/rotordin2
[[ $MODE != debug ]] || BIN=bin/rotordin2-debug
mapfile -t OBJECTS < <(awk '!/\/rotordin\.o$/' "build/$MODE/link.objects")
FLAGS=(-O0 -g -std=f2018 -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -I"build/$MODE/mod/solver")
"$FC" "${FLAGS[@]}" tests/reliability/a07_native.f90 "${OBJECTS[@]}" -o "$OUT/a07_native" > "$OUT/native-compile.txt" 2>&1
git show "$BASE:src/source/transient_matrix.f90" > "$OUT/baseline_matrix.f90"
"$FC" "${FLAGS[@]}" tests/reliability/a07_baseline.f90 "$OUT/baseline_matrix.f90" \
    "build/$MODE/obj/solver/rd_kinds.o" "build/$MODE/obj/solver/rd_commons.o" \
    -o "$OUT/a07_baseline" > "$OUT/baseline-compile.txt" 2>&1
"$OUT/a07_baseline" > "$OUT/baseline-control.txt" 2>&1

# Isolate A07 from other corrections: rebuild the four old A07 algorithm files
# with the current build flags, preserving all other current objects. The
# added, unused mka storage in rd_commons does not affect the before control.
SOLVER_FLAG_TEXT=$(sed -n 's/^SOLVER=//p' "build/$MODE/config.stamp")
read -r -a CONTROL_FLAGS <<< "$SOLVER_FLAG_TEXT"
CONTROL_OBJECTS=()
for source in matrizes shaft_timoshenko_cowper transient_matrix transient_solver; do
    git show "$BASE:src/source/$source.f90" > "$OUT/old_$source.f90"
    "$FC" "${CONTROL_FLAGS[@]}" -D_LINUX -I"build/$MODE/mod/solver" -J"$OUT/control-mod" \
        -c "$OUT/old_$source.f90" -o "$OUT/old_$source.o" >> "$OUT/old-algorithm-compile.txt" 2>&1
    CONTROL_OBJECTS+=("$OUT/old_$source.o")
done
mapfile -t OTHER_OBJECTS < <(awk '!/\/(matrizes|shaft_timoshenko_cowper|transient_matrix|transient_solver)\.o$/' \
    "build/$MODE/link.objects")
"$FC" "${OTHER_OBJECTS[@]}" "${CONTROL_OBJECTS[@]}" -o "$OUT/before-a07" >> "$OUT/old-algorithm-compile.txt" 2>&1
"$PYTHON" docs/qualification/tools/a07_oracles.py "$OUT/a07_native" "$OUT" > "$OUT/oracles.txt" 2>&1
"$PYTHON" docs/qualification/tools/a07_cli.py "$BIN" "$OUT/before-a07" "$OUT/cli" > "$OUT/cli.txt" 2>&1
cp "$OUT/cli/real-cli.json" "$OUT/real-cli.json"
sha256sum "$BIN" "$OUT/a07_native" "$OUT/before-a07" src/source/rd_commons.f90 \
    src/source/matrizes.f90 src/source/shaft_timoshenko_cowper.f90 src/source/transient_matrix.f90 \
    src/source/transient_solver.f90 tests/reliability/a07* docs/qualification/tools/a07* \
    > "$OUT/inputs.sha256"
printf 'A07 canonical matrix/kernel and safe production gate: PASS; production variable-spin physics: NOT_QUALIFIED\n' \
    | tee "$OUT/result.txt"
