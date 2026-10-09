#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
MODE=${1:-release}
BUILD_DIR=${RELIABILITY_BUILD_DIR:-$ROOT/build/$MODE}
OUT=${2:-$ROOT/build/reliability/a05/$MODE}
FC=${FC:-gfortran}
mkdir -p "$OUT"
printf '{"id":"A05","status":"BLOCKED","reason":"run not completed"}\n' > "$OUT/status.json"
if [[ -z ${RELIABILITY_BUILD_DIR:-} ]]; then
  make -C "$ROOT" MODE="$MODE" FC="$FC" -j"${RELIABILITY_JOBS:-2}" all > "$OUT/build.log" 2>&1
fi
mapfile -t objects < "$BUILD_DIR/link.objects"
link=()
for object in "${objects[@]}"; do
  [[ $object == */rotordin.o ]] || link+=("$BUILD_DIR/${object#build/$MODE/}")
done
flags=(-O0 -g -cpp -std=f2018 -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
[[ ${A05_BASELINE:-0} != 1 ]] || flags+=(-DA05_BASELINE)
{
  printf 'mode=%s\nbaseline=%s\n' "$MODE" "${A05_BASELINE:-0}"
  git -C "$ROOT" rev-parse HEAD
  "$FC" --version
  sha256sum "$ROOT/tests/reliability/a05_acceleration.f90" "$ROOT/tests/reliability/a05_run.sh" \
    "$ROOT/src/source/torsion/tnuinteg.f90" "$BUILD_DIR/obj/solver/torsion/tnuinteg.o"
} > "$OUT/provenance.txt"
"$FC" "${flags[@]}" -I"$BUILD_DIR/mod/solver" -o "$OUT/a05_acceleration" \
  "$ROOT/tests/reliability/a05_acceleration.f90" "${link[@]}" > "$OUT/compile.log" 2>&1
rc=0
"$OUT/a05_acceleration" > "$OUT/results.log" 2> "$OUT/stderr.log" || rc=$?
ross_rc=0
"${PYTHON:-python3}" "$ROOT/docs/qualification/tools/a05_ross_compare.py" \
  "${A05_ROSS_REF:-$ROOT/docs/qualification/ross_reference}" "$OUT/results.log" "$OUT/ross-comparison.json" \
  > "$OUT/ross-comparison.log" 2>&1 || ross_rc=$?
[[ $ross_rc == 0 ]] || rc=$ross_rc
printf '%s\n' "$rc" > "$OUT/returncode"
status=PASS
[[ $rc == 0 ]] || status=FAIL
summary=$(awk -F '[ =]+' '/^A05 checks=/{print $3,$5}' "$OUT/results.log")
summary_found=true
if [[ -n $summary ]]; then
  read -r checks failures <<< "$summary"
else
  checks=0;failures=1;summary_found=false;status=FAIL
  [[ $rc != 0 ]] || rc=1
  printf '%s\n' "$rc" > "$OUT/returncode"
fi
printf '{"id":"A05","head":"%s","mode":"%s","status":"%s","checks":%s,"failures":%s,"summary_found":%s}\n' \
  "$(git -C "$ROOT" rev-parse HEAD)" "$MODE" "$status" "$checks" "$failures" "$summary_found" > "$OUT/status.json"
tail -n 5 "$OUT/results.log"
cat "$OUT/ross-comparison.log"
exit "$rc"
