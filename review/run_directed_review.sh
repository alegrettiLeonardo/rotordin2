#!/usr/bin/env bash
# Reproduce the independent time-grid findings WITHOUT patching production files.
# Returns 1 for a mathematical failure, even when the native solver returns zero.
set -euo pipefail
export LC_ALL=C
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
: "${1:?Usage: bash run_directed_review.sh REPO NEW_OUTPUT_DIRECTORY}"
: "${2:?Use a new output directory}"
ROOT=$(cd -- "$1" && pwd)
EXPECTED=644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd
BASE=4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47
HEAD=$(git -C "$ROOT" rev-parse HEAD)
if [[ "$HEAD" != "$EXPECTED" && ${ALLOW_OTHER_HEAD:-0} != 1 ]]; then
  echo "Unexpected HEAD: $HEAD (set ALLOW_OTHER_HEAD=1 only for a deliberate post-fix check)" >&2; exit 2
fi
if [[ -e "$2" ]]; then echo "Output directory already exists: $2" >&2; exit 2; fi
mkdir -p -- "$2"
OUT=$(cd -- "$2" && pwd)
FC=${FC:-gfortran}; PYTHON=${PYTHON:-python3}
command -v "$FC" >/dev/null
command -v "$PYTHON" >/dev/null
printf 'HEAD=%s\nBASE_ROUTINE=%s\n' "$HEAD" "$BASE" > "$OUT/environment.txt"
"$FC" --version >> "$OUT/environment.txt"
git -C "$ROOT" status --porcelain > "$OUT/git_status.before.txt"
git -C "$ROOT" show "$BASE:src/source/torsion/tnuinteg.f90" > "$OUT/tnuinteg_baseline.f90"
for MODE in release debug; do
  MOUT="$OUT/$MODE"; mkdir -p "$MOUT"
  make -C "$ROOT" FC="$FC" MODE="$MODE" -j"${JOBS:-4}" all > "$MOUT/build.log" 2>&1
  mapfile -t OBJECTS < "$ROOT/build/$MODE/link.objects"
  ALL=(); NO_MAIN=(); OLD_NO_MAIN=(); OLD_ALL=()
  OLD="$MOUT/tnuinteg_baseline.o"
  for OBJ in "${OBJECTS[@]}"; do
    [[ "$OBJ" = /* ]] || OBJ="$ROOT/$OBJ"
    ALL+=("$OBJ")
    if [[ "$OBJ" == */tnuinteg.o ]]; then OLD_ALL+=("$OLD"); else OLD_ALL+=("$OBJ"); fi
    if [[ "$OBJ" != */rotordin.o ]]; then
      NO_MAIN+=("$OBJ")
      if [[ "$OBJ" == */tnuinteg.o ]]; then OLD_NO_MAIN+=("$OLD"); else OLD_NO_MAIN+=("$OBJ"); fi
    fi
  done
  FLAGS=(-cpp -D_LINUX -std=f2018 -I"$ROOT/build/$MODE/mod/solver")
  if [[ "$MODE" == debug ]]; then
    FLAGS+=(-O0 -g -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
  else FLAGS+=(-O3); fi
  "$FC" "${FLAGS[@]}" -c "$OUT/tnuinteg_baseline.f90" -o "$OLD" > "$MOUT/baseline_compile.log" 2>&1
  "$FC" "${FLAGS[@]}" "$HERE/probes/review_time_grid.f90" "${NO_MAIN[@]}" -o "$MOUT/grid_current" > "$MOUT/grid_compile.log" 2>&1
  "$FC" "${FLAGS[@]}" "$HERE/probes/review_time_grid.f90" "${OLD_NO_MAIN[@]}" -o "$MOUT/grid_baseline_routine" >> "$MOUT/grid_compile.log" 2>&1
  "$FC" "${FLAGS[@]}" "${OLD_ALL[@]}" -o "$MOUT/solver_baseline_routine" > "$MOUT/baseline_link.log" 2>&1
  "$MOUT/grid_current" > "$MOUT/grid_current.log" 2> "$MOUT/grid_current.stderr"
  "$MOUT/grid_baseline_routine" > "$MOUT/grid_baseline_routine.log" 2> "$MOUT/grid_baseline_routine.stderr"
  BINARY="$ROOT/bin/rotordin2"; [[ "$MODE" != debug ]] || BINARY="$ROOT/bin/rotordin2-debug"
  sha256sum "$BINARY" "$MOUT/solver_baseline_routine" > "$MOUT/binaries.sha256"
  for CASE in default_output explicit_output roundoff_end; do
    CDIR="$MOUT/$CASE"; mkdir -p "$CDIR"; cp "$HERE/cases/$CASE.txt" "$CDIR/input.txt"
    RC=0
    (cd "$CDIR" && timeout 60 "$BINARY" -std -n < input.txt > stdout.txt 2> stderr.txt) || RC=$?
    printf '%s\n' "$RC" > "$CDIR/rc.txt"
  done
  CDIR="$MOUT/roundoff_end_baseline_routine";mkdir -p "$CDIR";cp "$HERE/cases/roundoff_end.txt" "$CDIR/input.txt"
  RC=0
  (cd "$CDIR" && timeout 60 "$MOUT/solver_baseline_routine" -std -n < input.txt > stdout.txt 2> stderr.txt) || RC=$?
  printf '%s\n' "$RC" > "$CDIR/rc.txt"
done
git -C "$ROOT" status --porcelain > "$OUT/git_status.after.txt"
set +e
"$PYTHON" "$HERE/verify_directed_results.py" "$OUT" | tee "$OUT/verification.log"
RC=${PIPESTATUS[0]}
set -e
printf '%s\n' "$RC" > "$OUT/review_returncode.txt"
exit "$RC"
