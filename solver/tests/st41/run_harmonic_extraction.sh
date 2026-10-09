#!/usr/bin/env bash
# Compare extraction against an explicitly supplied pristine executable.
# No archived hash or historical replay is altered by this runner.
set -euo pipefail
export LC_ALL=C
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
BASE=$(realpath -- "${1:?pristine binary required}")
TEST=$(realpath -- "${2:?candidate binary required}")
OUT=$(realpath -m -- "${3:?evidence directory required}")
[[ -x $BASE && -x $TEST ]]
mkdir -p "$OUT"
bash "$ROOT/tests/st41/make_harmonic_fixture.sh" "$OUT/input.txt"
sha256sum "$BASE" "$TEST" "$OUT/input.txt" > "$OUT/hashes.sha256"
for variant in baseline candidate; do
    bin=$BASE
    [[ $variant == baseline ]] || bin=$TEST
    mkdir -p "$OUT/$variant"
    printf '%q -std -f -b < ../input.txt\n' "$bin" > "$OUT/$variant/command.txt"
    rc=0
    (cd "$OUT/$variant"; timeout 90 "$bin" -std -f -b < ../input.txt > stdout.out 2> stderr.log) || rc=$?
    printf '%s\n' "$rc" > "$OUT/$variant/returncode.txt"
    [[ $rc == 0 ]] || { echo "FAIL: $variant rc=$rc" >&2; exit 1; }
    ! grep -q '#BEGIN MODEL_ERROR' "$OUT/$variant/stdout.out"
    awk '/^#BEGIN unblresp.out/{inside=1;skip=2;next}
         /^#END unblresp.out/{inside=0}
         inside&&skip>0{skip--;next}inside{print}' \
        "$OUT/$variant/stdout.out" > "$OUT/$variant/response.txt"
    awk '/^RD_AUDIT_V1 RESPONSE_H/{print}' \
        "$OUT/$variant/stdout.out" > "$OUT/$variant/audit.txt"
    [[ $(wc -l < "$OUT/$variant/audit.txt") == 16 ]]
    [[ -s $OUT/$variant/response.txt ]]
done
cmp "$OUT/baseline/response.txt" "$OUT/candidate/response.txt"
cmp "$OUT/baseline/audit.txt" "$OUT/candidate/audit.txt"
sha256sum "$OUT/baseline/response.txt" "$OUT/candidate/response.txt" > "$OUT/response-hashes.sha256"
echo 'HARMONIC_EXTRACTION: PASS; 16 speeds, 4 channels, amplitude/phase and all audit rows byte-identical'
