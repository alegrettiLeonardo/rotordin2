#!/usr/bin/env bash
# Native before/after controls, complex responses, actual CLI and pinned ROSS.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
MODE=${1:-release}
OUT=$(realpath -m -- "${2:-build/reliability-a01-$MODE}")
FC=${FC:-gfortran}
PYTHON=${PYTHON:-python3}
BASE=4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47
mkdir -p "$OUT"
make MODE="$MODE" FC="$FC" -j"${RELIABILITY_JOBS:-4}" > "$OUT/build.log" 2>&1
BIN=bin/rotordin2
[[ $MODE != debug ]] || BIN=bin/rotordin2-debug
git rev-parse HEAD > "$OUT/source_commit.txt"
git status --porcelain=v1 > "$OUT/source_status.txt"
cp "build/$MODE/config.stamp" "$OUT/config.stamp"
sha256sum "$BIN" src/source/transient_forcing.f90 tests/reliability/a01* > "$OUT/inputs.sha256"
mapfile -t OBJECTS < <(awk '!/\/rotordin\.o$/' "build/$MODE/link.objects")
FLAGS=(-O0 -g -std=f2018 -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -I"build/$MODE/mod/solver")
for TEST in force_cases response_cases force_samples; do
  "$FC" "${FLAGS[@]}" "tests/reliability/a01_$TEST.f90" "${OBJECTS[@]}" -o "$OUT/a01_$TEST" > "$OUT/$TEST.compile.log" 2>&1
done
git show "$BASE:src/source/transient_forcing.f90" > "$OUT/baseline_forcing.f90"
"$FC" "${FLAGS[@]}" -c "$OUT/baseline_forcing.f90" -o "$OUT/baseline_forcing.o"
mapfile -t BEFORE_OBJECTS < <(awk '!/\/rotordin\.o$|\/transient_forcing\.o$/' "build/$MODE/link.objects")
"$FC" "${FLAGS[@]}" tests/reliability/a01_force_cases.f90 "$OUT/baseline_forcing.o" "${BEFORE_OBJECTS[@]}" -o "$OUT/a01_before"
RC=0
"$OUT/a01_before" > "$OUT/before.log" 2>&1 || RC=$?
printf '%s\n' "$RC" > "$OUT/before.returncode.txt"
[[ $RC != 0 ]]
grep -q 'A01 force/phase contract FAIL' "$OUT/before.log"
"$OUT/a01_force_cases" > "$OUT/force.log" 2>&1
"$OUT/a01_response_cases" > "$OUT/response.log" 2>&1
"$PYTHON" docs/qualification/tools/a01_cli.py "$BIN" "$OUT/cli" > "$OUT/cli.log" 2>&1
"$PYTHON" docs/qualification/tools/a01_ross.py "$OUT/a01_force_samples" "$OUT/ross.json" > "$OUT/ross.log" 2>&1
printf 'PASS A01 %s: physical force, phase, FW/BW, complex FRF, CLI, ROSS\n' "$MODE" | tee "$OUT/result.txt"
