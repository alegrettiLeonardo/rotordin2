#!/usr/bin/env bash
# Link native regression to the existing build's exact source backend objects.
set -euo pipefail
export LC_ALL=C
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
MODE=${1:-release}
BUILD_ROOT=$(realpath -- "${ST41_BUILD_ROOT:-$ROOT}")
BUILD_DIR=$(realpath -- "${ST41_BUILD_DIR:-$BUILD_ROOT/build/$MODE}")
OUT=$(realpath -m -- "${2:-$ROOT/evidence/geometry/$MODE}")
FC=${FC:-gfortran}
[[ $MODE == release || $MODE == debug ]]
mkdir -p "$OUT"
FLAGS=(-O0 -g -cpp -std=f2018 -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
[[ ${ST41_BASELINE:-0} != 1 ]] || FLAGS+=(-DST41_BASELINE)
mapfile -t objects < "$BUILD_DIR/link.objects"
link=()
for object in "${objects[@]}"; do
    [[ $object == */rotordin.o ]] || link+=("$BUILD_DIR/${object#build/$MODE/}")
done
{
    printf 'mode=%s\nbuild_root=%s\nbuild_dir=%s\nbaseline=%s\n' "$MODE" "$BUILD_ROOT" "$BUILD_DIR" "${ST41_BASELINE:-0}"
    "$FC" --version
    printf 'harness_flags=%s\n' "${FLAGS[*]}"
    cat "$BUILD_DIR/config.stamp"
    sha256sum "$ROOT/docs/manifests/SOLVER.sha256" "$ROOT/docs/manifests/LAPACK.sha256" \
        "$ROOT/docs/manifests/BUILD.sha256"
    sha256sum "$ROOT/tests/st41/geometry_regression.f90" "$ROOT/tests/st41/run_geometry.sh" "${link[@]}"
} > "$OUT/provenance.txt"
"$FC" "${FLAGS[@]}" -I"$BUILD_DIR/mod/solver" -o "$OUT/geometry_regression" \
    "$ROOT/tests/st41/geometry_regression.f90" "${link[@]}" > "$OUT/compile.log" 2>&1
sha256sum "$OUT/geometry_regression" >> "$OUT/provenance.txt"
overall=0
for scenario in boundary cone torsion fillet_mass close_nodes physical_count near_end; do
    rc=0
    timeout 90 "$OUT/geometry_regression" "$scenario" > "$OUT/$scenario.log" 2> "$OUT/$scenario.stderr" || rc=$?
    printf '%s\n' "$rc" > "$OUT/$scenario.returncode"
    if [[ $rc != 0 ]]; then overall=1; fi
    printf 'geometry %-16s rc=%s log=%s\n' "$scenario" "$rc" "$OUT/$scenario.log"
    tail -n 1 "$OUT/$scenario.log"
done
if [[ -n ${ST41_REFERENCE_LOG:-} ]]; then
    rc=0
    "$OUT/geometry_regression" compare_responses "$OUT/cone.log" "$ST41_REFERENCE_LOG" \
        > "$OUT/common-mesh-comparison.log" 2> "$OUT/common-mesh-comparison.stderr" || rc=$?
    printf '%s\n' "$rc" > "$OUT/common-mesh-comparison.returncode"
    sha256sum "$OUT/cone.log" "$ST41_REFERENCE_LOG" >> "$OUT/provenance.txt"
    cat "$OUT/common-mesh-comparison.log"
    if [[ $rc != 0 ]]; then overall=1; fi
fi
exit "$overall"
