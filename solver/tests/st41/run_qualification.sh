#!/usr/bin/env bash
# Execute the qualified ST41-priority scope using native solver objects.
# Historical ST41 targets still require their archived decks/evidence.
# Usage: run_qualification.sh [fresh-output-dir] [baseline-release] [baseline-debug]
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
ROOT=$PWD
OUT=$(realpath -m -- "${1:-build/st41-qualification}")
BASE_RELEASE=$(realpath -m -- "${2:-evidence/baseline/rotordin2-baseline}")
BASE_DEBUG=$(realpath -m -- "${3:-evidence/baseline/rotordin2-debug-baseline}")
export FC=${FC:-gfortran}
export ST41_JOBS=${ST41_JOBS:-4}
command -v "$FC" >/dev/null
[[ ! -e $OUT/status.tsv ]] || { printf 'Use a fresh output directory: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/logs"
printf 'check\treturncode\tresult\tlog\n' > "$OUT/status.tsv"
git rev-parse HEAD > "$OUT/source_commit.txt"
git status --porcelain=v1 > "$OUT/source_status.txt"
git diff --stat > "$OUT/source_changes.txt"
git log --format='%H %s' -20 > "$OUT/local_commits.txt"
"$FC" --version > "$OUT/compiler.txt"
sha256sum docs/manifests/SOLVER.sha256 docs/manifests/LAPACK.sha256 \
  docs/manifests/TESTS.sha256 docs/manifests/BUILD.sha256 \
  docs/manifests/SOURCE_MANIFEST.baseline.sha256 > "$OUT/source_manifests.sha256"
OVERALL=0
LAST_RC=0
run() {
  local name=$1
  shift
  local rc=0 result=PASS
  printf '%q ' "$@" > "$OUT/logs/$name.command.txt"
  printf '\n' >> "$OUT/logs/$name.command.txt"
  "$@" > "$OUT/logs/$name.log" 2>&1 || rc=$?
  LAST_RC=$rc
  if [[ $rc != 0 ]]; then result=FAIL; OVERALL=1; fi
  printf '%s\t%s\t%s\tlogs/%s.log\n' "$name" "$rc" "$result" "$name" >> "$OUT/status.tsv"
  printf '%s %s (rc=%s)\n' "$result" "$name" "$rc"
  if [[ $rc != 0 ]]; then tail -20 "$OUT/logs/$name.log" >&2; fi
}

run source-integrity bash tests/check_sources.sh
run layout bash tests/check_sources.sh --layout
for MODE in release debug; do
  BIN=bin/rotordin2
  [[ $MODE != debug ]] || BIN=bin/rotordin2-debug
  run "build-$MODE" make MODE="$MODE" FC="$FC" -j"$ST41_JOBS"
  if [[ $LAST_RC != 0 ]]; then continue; fi
  mkdir -p "$OUT/$MODE"
  cp "build/$MODE/config.stamp" "$OUT/$MODE/build_config.txt"
  cp "build/$MODE/link.objects" "$OUT/$MODE/link.objects"
  sha256sum "$BIN" > "$OUT/$MODE/binary.sha256"
  run "legacy-$MODE" make MODE="$MODE" FC="$FC" test
  run "messages-invalid-$MODE" bash tests/st41/run_messages_invalid.sh "$BIN" "$OUT/$MODE/messages-invalid"
  run "input-support-$MODE" bash tests/st41/run_input_support.sh "$BIN" "$OUT/$MODE/input-support"
  run "input-effective-$MODE" bash tests/st41/run_input_effective.sh "$BIN" "$OUT/$MODE/input-effective"
  run "input-routes-$MODE" bash tests/st41/run_input_routes.sh "$BIN" "$OUT/$MODE/input-routes"
  run "harmonic-tools-$MODE" make MODE="$MODE" FC="$FC" \
    "build/$MODE/tests/st41/harmonic_oracle" "build/$MODE/tests/st41/compare_harmonic"
  if [[ $LAST_RC == 0 ]]; then
    run "harmonic-$MODE" bash tests/st41/run_harmonic.sh "$BIN" \
      "build/$MODE/tests/st41/harmonic_oracle" "build/$MODE/tests/st41/compare_harmonic" "$OUT/$MODE/harmonic"
  fi
  REFERENCE=${ST41_GEOMETRY_REFERENCE_LOG:-}
  if [[ $MODE == debug && -f $OUT/release/geometry/cone.log ]]; then
    REFERENCE="$OUT/release/geometry/cone.log"
  fi
  run "geometry-$MODE" env ST41_REFERENCE_LOG="$REFERENCE" \
    bash tests/st41/run_geometry.sh "$MODE" "$OUT/$MODE/geometry"
done

# These runners deliberately compile both profile variants and the untouched
# source routine as an executable before-fix control.
run messages-native bash tests/st41/run_messages.sh "$OUT/messages"
run af-native bash tests/st41/run_af.sh "$OUT/af"
run p1-poles bash tests/st41/run_p1_poles.sh "$OUT/p1-poles"
if [[ -x $BASE_RELEASE && -x $BASE_DEBUG ]]; then
  run p1-campbell bash tests/st41/run_p1_campbell.sh "$OUT/p1-campbell" "$BASE_RELEASE" "$BASE_DEBUG"
else
  printf 'p1-campbell\t2\tBLOCKED_BASELINE_BINARY\t%s ; %s\n' "$BASE_RELEASE" "$BASE_DEBUG" >> "$OUT/status.tsv"
  printf 'BLOCKED p1-campbell: build the imported baseline and supply both executable paths.\n' >&2
  OVERALL=1
fi
run final-source-integrity bash tests/check_sources.sh
cat > "$OUT/historical_st41.txt" <<'HISTORICAL_STATUS'
BLOCKED_MISSING_FIXTURES
The provided source archive and generic controls do not include:
- rotordin2_evidencias_ST41.zip
- rotordin2_evidencias_input_nativo_ST41.zip
- the exact archived ST41 input and corresponding original executable.
The archived amplitudes, geometry targets, 39-point AF crop, and seven 1X / 23
Campbell intersections remain unverified. See docs/ST41_FIX_STATUS.md.
The executor return code covers the available native qualification only.
HISTORICAL_STATUS
printf 'historical-st41\tNA\tBLOCKED_MISSING_FIXTURES\thistorical_st41.txt\n' >> "$OUT/status.tsv"
printf '\nHistorical ST41 targets: BLOCKED_MISSING_FIXTURES (see docs/ST41_FIX_STATUS.md).\n'
printf 'Qualification return code: %s; results: %s/status.tsv\n' "$OVERALL" "$OUT"
printf '%s\n' "$OVERALL" > "$OUT/returncode.txt"
exit "$OVERALL"
