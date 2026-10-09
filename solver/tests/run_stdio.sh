#!/usr/bin/env bash
# Dois casos reais do contrato de comunicação; não uma validação de toda a física.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
BIN=$(realpath -- "${1:?binário requerido}")
CMP=$(realpath -- "${2:?comparador requerido}")
OUT=$(realpath -m -- "${3:?pasta de evidências requerida}")
FIX=$(realpath tests/fixtures/simple2b-sp.txt)
REF=$(realpath tests/fixtures/critical_speeds.reference)
[[ -x $BIN && -x $CMP && -f $FIX && -f $REF ]]
command -v timeout >/dev/null
mkdir -p "$OUT"
for name in campbell modes; do
    work=$(mktemp -d "$OUT/$name.XXXXXX")
    flag=-c; analysis=CAMPBELL; result=campbell.out
    if [[ $name == modes ]]; then flag=-m; analysis=LATERAL_MODES; result=modeshp.out; fi
    rc=0
    (cd "$work"; ulimit -c 0; timeout 90 "$BIN" -std "$flag" -b < "$FIX" > stdout.out 2> stderr.log) || rc=$?
    printf '%s\n' "$rc" > "$work/returncode.txt"
    if [[ $rc != 0 ]]; then
        echo "FAIL: $name retornou $rc; evidência: $work" >&2
        tail -30 "$work/stderr.log" >&2; exit 1
    fi
    if grep -E '^[[:space:]]*#PROGRESS' "$work/stdout.out"; then
        echo 'FAIL: progresso contaminou stdout' >&2; exit 1
    fi
    if grep -F '#BEGIN MODEL_ERROR' "$work/stdout.out" "$work/stderr.log"; then
        echo 'FAIL: MODEL_ERROR emitido' >&2; exit 1
    fi
    for block in output.out MODEL_AUDIT "$result"; do
        for marker in BEGIN END; do
            awk -v marker="#$marker" -v block="$block" '$1 == marker && $2 == block && NF == 2 {ok=1} END {exit !ok}' "$work/stdout.out" || {
                echo "FAIL: bloco $marker $block ausente" >&2; exit 1;
            }
        done
    done
    grep -F "#PROGRESS ANALYSIS=$analysis EVENT=END STATUS=OK" "$work/stderr.log" >/dev/null
    "$CMP" "$REF" "$work/stdout.out" | tee "$work/comparison.txt"
    echo "PASS $name: rc=0; stdout estruturado; progresso stderr; referência preservada"
done
echo 'STDIO_SMOKE: 2 selected cases PASS; not a complete physical qualification'
