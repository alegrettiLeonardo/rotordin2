#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
MODE=${1:-release}
BUILD_DIR=${RELIABILITY_BUILD_DIR:-$ROOT/build/$MODE}
OUT=${2:-$ROOT/build/reliability/a04/$MODE}
FC=${FC:-gfortran}
mkdir -p "$OUT"
printf '{"id":"A04","mode":"%s","status":"BLOCKED","reason":"execution not completed"}\n' "$MODE" > "$OUT/status.json"
if [[ -z ${RELIABILITY_BUILD_DIR:-} ]]; then
  make -C "$ROOT" MODE="$MODE" FC="$FC" -j"${RELIABILITY_JOBS:-2}" all > "$OUT/build.log" 2>&1
fi
mapfile -t objects < "$BUILD_DIR/link.objects"
link=()
for object in "${objects[@]}"; do
  [[ $object == */rotordin.o ]] || link+=("$BUILD_DIR/${object#build/$MODE/}")
done
flags=(-O0 -g -cpp -std=f2018 -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
[[ ${A04_BASELINE:-0} != 1 ]] || flags+=(-DA04_BASELINE)
{
  printf 'mode=%s\nbaseline=%s\n' "$MODE" "${A04_BASELINE:-0}"
  git -C "$ROOT" rev-parse HEAD
  "$FC" --version
  sha256sum "$ROOT/tests/reliability/a04_damping.f90" "$ROOT/tests/reliability/a04_run.sh" \
    "$ROOT/src/source/torsion/tmatrices.f90" "$ROOT/src/source/torsion/tcouprops.f90" \
    "$ROOT/src/source/torsion/thhmat.f90" "$BUILD_DIR/obj/solver/torsion/tmatrices.o" \
    "$BUILD_DIR/obj/solver/torsion/tcouprops.o" "$BUILD_DIR/obj/solver/torsion/thhmat.o"
} > "$OUT/provenance.txt"
"$FC" "${flags[@]}" -I"$BUILD_DIR/mod/solver" -o "$OUT/a04_damping" \
  "$ROOT/tests/reliability/a04_damping.f90" "${link[@]}" > "$OUT/compile.log" 2>&1
rc=0
"$OUT/a04_damping" > "$OUT/results.log" 2> "$OUT/stderr.log" || rc=$?
ross_rc=0
"${PYTHON:-python3}" "$ROOT/docs/qualification/tools/a04_ross_compare.py" \
  "${A04_ROSS_REF:-$ROOT/docs/qualification/ross_reference}" "$OUT/results.log" "$OUT/ross-comparison.json" \
  > "$OUT/ross-comparison.log" 2>&1 || ross_rc=$?
[[ $ross_rc == 0 ]] || rc=$ross_rc
status=PASS
[[ $rc == 0 ]] || status=FAIL
checks=0; failures=1
if ! read -r checks failures < <(awk -F '[ =]+' '/^A04 checks=/{print $3,$5}' "$OUT/results.log"); then
  checks=0; failures=1; status=FAIL
  [[ $rc != 0 ]] || rc=1
fi
if [[ ! $checks =~ ^[0-9]+$ || ! $failures =~ ^[0-9]+$ ]]; then
  checks=0; failures=1; status=FAIL
  [[ $rc != 0 ]] || rc=1
fi
if (( checks == 0 || failures != 0 )); then
  status=FAIL
  [[ $rc != 0 ]] || rc=1
fi
printf '%s\n' "$rc" > "$OUT/returncode"
printf '{"id":"A04","head":"%s","mode":"%s","status":"%s","checks":%s,"failures":%s}\n' \
  "$(git -C "$ROOT" rev-parse HEAD)" "$MODE" "$status" "$checks" "$failures" > "$OUT/status.json"
tail -n 5 "$OUT/results.log"
cat "$OUT/ross-comparison.log"
exit "$rc"
