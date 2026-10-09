#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
MODE=${1:-release}; OUT=${2:-"$ROOT/build/reliability-rev02/$MODE"}
FC=${FC:-gfortran}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
printf '{"status":"INCOMPLETE"}\n' > "$OUT/status.json"
make -C "$ROOT" FC="$FC" MODE="$MODE" -j"${JOBS:-4}" all > "$OUT/build.log" 2>&1
mapfile -t OBJECTS < "$ROOT/build/$MODE/link.objects"
LINK=()
for OBJ in "${OBJECTS[@]}"; do
  [[ "$OBJ" == */rotordin.o ]] && continue
  [[ "$OBJ" = /* ]] || OBJ="$ROOT/$OBJ"
  LINK+=("$OBJ")
done
FLAGS=(-cpp -D_LINUX -std=f2018 -I"$ROOT/build/$MODE/mod/solver")
if [[ "$MODE" == debug ]]; then
  FLAGS+=(-O0 -g -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
else FLAGS+=(-O3); fi
"$FC" "${FLAGS[@]}" "$ROOT/tests/reliability/rev02_time_grid.f90" "${LINK[@]}" -o "$OUT/probe" > "$OUT/compile.log" 2>&1
"$OUT/probe" > "$OUT/results.log" 2> "$OUT/stderr.log"
if [[ $(grep -c '^CONTROL_PASS' "$OUT/results.log") == 8 ]] && grep -q '^INDEPENDENT_GRID_FAILURES=0$' "$OUT/results.log"; then
  printf '{"status":"PASS","controls":8,"dense_publication":"PASS"}\n' > "$OUT/status.json"
else
  printf '{"status":"FAIL"}\n' > "$OUT/status.json"; exit 1
fi
cat "$OUT/status.json"
