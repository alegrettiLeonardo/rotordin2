#!/usr/bin/env bash
# Native synthetic controls only; archived ST41 acceptance is a separate gate.
set -euo pipefail
export LC_ALL=C
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
BIN=$(realpath -- "${1:?binary required}")
ORACLE=$(realpath -- "${2:?oracle required}")
CMP=$(realpath -- "${3:?phasor comparator required}")
OUT=$(realpath -m -- "${4:?evidence directory required}")
mkdir -p "$OUT/oracle"
sha256sum "$BIN" "$ORACLE" "$CMP" > "$OUT/binary-hashes.sha256"
(cd "$OUT/oracle"; "$ORACLE" > stdout.out 2> stderr.log)
tail -5 "$OUT/oracle/stdout.out"

run_case() {
    local name=$1 phase=$2 modes=$3 angle=$4 speed=$5 position=$6 foundation=$7
    shift 7
    mkdir -p "$OUT/$name"
    bash "$ROOT/tests/st41/make_harmonic_fixture.sh" "$OUT/$name/input.txt" \
        "$phase" "$modes" "$angle" "$speed" "$position"
    if [[ $foundation != none ]]; then
        cat "$ROOT/tests/st41/harmonic_foundation_$foundation.inc" >> "$OUT/$name/input.txt"
    fi
    sha256sum "$OUT/$name/input.txt" > "$OUT/$name/input.sha256"
    printf '%q ' "$BIN" -std -b "$@" > "$OUT/$name/command.txt"
    printf '< input.txt\n' >> "$OUT/$name/command.txt"
    local rc=0
    (cd "$OUT/$name"; timeout 90 "$BIN" -std -b "$@" < input.txt > stdout.out 2> stderr.log) || rc=$?
    printf '%s\n' "$rc" > "$OUT/$name/returncode.txt"
    if [[ $name == dynamic-t ]]; then
        [[ $rc != 0 ]]
        grep -q 'DYNAMIC_STIFFNESS_TABLE supports -f only' "$OUT/$name/stdout.out" "$OUT/$name/stderr.log"
        ! grep -q '#BEGIN timeresp.out' "$OUT/$name/stdout.out"
        return
    fi
    [[ $rc == 0 ]] || { echo "FAIL: $name rc=$rc" >&2; tail -20 "$OUT/$name/stderr.log" >&2; exit 1; }
    ! grep -q '#BEGIN MODEL_ERROR' "$OUT/$name/stdout.out"
    # Physical equilibrium must be accurate even when the dimensioned H has
    # a small RCOND; preserve and report its separate kinematic diagnostic.
    awk '/^RD_AUDIT_V1 RESPONSE_H/{n++;if($8+0>1e-10)bad=1}
         END{exit n==0||bad}' "$OUT/$name/stdout.out"
}

for phase in 0 90 180 270; do
    run_case "ft-$phase" "$phase" 10 0 1800 0.4125 none -f -t
    "$CMP" direct "$OUT/ft-$phase/stdout.out" > "$OUT/ft-$phase/comparison.txt"
    "$CMP" orbits "$OUT/ft-0/stdout.out" "$OUT/ft-$phase/stdout.out" "$phase" \
        > "$OUT/ft-$phase/phase-comparison.txt"
done
run_case t 0 10 0 1800 0.4125 none -t
run_case mt 0 10 0 1800 0.4125 none -m -t
run_case nbrmod19 0 19 0 1800 0.4125 none -t
run_case tangle90 0 10 90 1800 0.4125 none -t
for name in t mt nbrmod19 tangle90; do
    "$CMP" orbits "$OUT/ft-0/stdout.out" "$OUT/$name/stdout.out" \
        > "$OUT/$name/comparison.txt"
done
for name in t nbrmod19 tangle90; do
    ! grep -q 'ANALYSIS=MODAL_SPACE' "$OUT/$name/stderr.log"
    grep -q 'NBRMOD ignored; no modal truncation' "$OUT/$name/stdout.out"
done
run_case support 0 10 0 1800 -1 none -f -t
run_case sweep 0 10 0 0 0.4125 none -f -t
run_case shape 0 10 0 1800 0 none -f -t
for name in support sweep shape; do
    "$CMP" direct "$OUT/$name/stdout.out" > "$OUT/$name/comparison.txt"
done
run_case plot 0 10 0 1800 0.4125 none -t -p
run_case plot-shape 0 10 0 1800 0 none -t -p
run_case plot-sweep 0 10 0 0 0.4125 none -t -p
for name in plot plot-shape plot-sweep; do
    grep -qi 'full physical response' "$OUT/$name/stdout.out"
done

run_case physical-f 0 10 0 1800 0.4125 physical -f
run_case physical-ft 0 10 0 1800 0.4125 physical -f -t
run_case physical-t 0 10 0 1800 0.4125 physical -t
cmp "$OUT/physical-f/foundation_response.csv" "$OUT/physical-ft/foundation_response.csv"
[[ $(wc -l < "$OUT/physical-ft/foundation_response.csv") == 33 ]]
[[ ! -e $OUT/physical-t/foundation_response.csv ]]
[[ ! -e $OUT/physical-t/foundation_participation.out ]]
"$CMP" direct "$OUT/physical-ft/stdout.out" > "$OUT/physical-ft/comparison.txt"
"$CMP" orbits "$OUT/physical-ft/stdout.out" "$OUT/physical-t/stdout.out" \
    > "$OUT/physical-t/comparison.txt"
run_case dynamic-f 0 10 0 1800 0.4125 dynamic -f
run_case dynamic-t 0 10 0 1800 0.4125 dynamic -t
echo 'HARMONIC_CLI: PASS; 19 runs; phase, -t/-f-t/-m-t, NBRMOD, TANGLE, support, sweep, shape, plots, foundation lifecycle/restriction'
