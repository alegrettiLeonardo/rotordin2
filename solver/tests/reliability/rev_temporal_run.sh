#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
MODE=${1:-release}
[[ $MODE == release || $MODE == debug ]] || { echo 'mode must be release/debug' >&2; exit 2; }
if [[ $# -ge 2 ]]; then OUT=$2; [[ ! -e $OUT ]] || { echo 'output must be new' >&2; exit 2; }; mkdir -p "$OUT";
else mkdir -p "$ROOT/build/reliability/rev-temporal"; OUT=$(mktemp -d "$ROOT/build/reliability/rev-temporal/$MODE.XXXXXX"); fi
OUT=$(cd "$OUT" && pwd)
BUILD_DIR=${RELIABILITY_BUILD_DIR:-$ROOT/build/$MODE}
FC=${FC:-gfortran}
PYTHON=${PYTHON:-python3}
HEAD=$(git -C "$ROOT" rev-parse HEAD)
printf '%s\n' "$HEAD" > "$OUT/source_commit.txt"
printf '{"id":"REV_TEMPORAL","mode":"%s","source_commit":"%s","status":"BLOCKED","reason":"execution not completed"}\n' "$MODE" "$HEAD" > "$OUT/status.json"
finish_failure() {
  local rc=$?
  if [[ ! -f $OUT/returncode ]]; then
    (( rc != 0 )) || rc=1
    printf '%s\n' "$rc" > "$OUT/returncode"
    printf '{"id":"REV_TEMPORAL","mode":"%s","source_commit":"%s","status":"FAIL","reason":"runner aborted or summary missing"}\n' "$MODE" "$HEAD" > "$OUT/status.json"
  fi
}
trap finish_failure EXIT
if [[ ${REV_TEMPORAL_SKIP_BUILD:-0} != 1 && -z ${RELIABILITY_BUILD_DIR:-} ]]; then
  make -C "$ROOT" MODE="$MODE" FC="$FC" -j"${RELIABILITY_JOBS:-2}" all > "$OUT/build.log" 2>&1
fi
mapfile -t objects < "$BUILD_DIR/link.objects"
link=()
for object in "${objects[@]}"; do
  [[ $object == */rotordin.o ]] || link+=("$BUILD_DIR/${object#build/$MODE/}")
done
flags=(-O0 -g -cpp -std=f2018 -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
baseline=()
if [[ ${REV_TEMPORAL_BASELINE:-0} == 1 ]]; then flags+=(-DREV_TEMPORAL_BASELINE); baseline+=(--baseline); fi
BIN=${REV_TEMPORAL_BIN:-$ROOT/bin/rotordin2}
if [[ $MODE == debug && -z ${REV_TEMPORAL_BIN:-} ]]; then BIN=$ROOT/bin/rotordin2-debug; fi
{
  printf 'mode=%s\nsource_commit=%s\nbaseline=%s\nbuild_dir=%s\n' "$MODE" "$HEAD" "${REV_TEMPORAL_BASELINE:-0}" "$BUILD_DIR"
  "$FC" --version
  "$PYTHON" -c 'import sys,numpy,scipy; print(sys.version); print("numpy="+numpy.__version__+" scipy="+scipy.__version__)'
  sha256sum "$ROOT/tests/reliability/rev_temporal_native.f90" "$ROOT/tests/reliability/rev_temporal_run.sh" \
    "$ROOT/docs/qualification/tools/rev_temporal_oracle.py" "$ROOT/docs/qualification/tools/rev_temporal_cli.py" "$BIN" "${link[@]}"
} > "$OUT/provenance.txt"
"$FC" "${flags[@]}" -I"$BUILD_DIR/mod/solver" -o "$OUT/rev_temporal_native" \
  "$ROOT/tests/reliability/rev_temporal_native.f90" "${link[@]}" > "$OUT/compile.log" 2>&1
native_rc=0
"$PYTHON" "$ROOT/docs/qualification/tools/rev_temporal_oracle.py" "$OUT/rev_temporal_native" "$OUT/native" \
  --mode "$MODE" "${baseline[@]}" > "$OUT/native.log" 2>&1 || native_rc=$?
cli_rc=0
"$PYTHON" "$ROOT/docs/qualification/tools/rev_temporal_cli.py" "$BIN" "$ROOT/tests/reliability/rev_temporal_cases" \
  "$OUT/cli" > "$OUT/cli.log" 2>&1 || cli_rc=$?
"$PYTHON" - "$OUT" "$MODE" "$HEAD" "$native_rc" "$cli_rc" <<'PY'
import json,sys
from pathlib import Path
out=Path(sys.argv[1]);mode,head=sys.argv[2:4];nr,cr=map(int,sys.argv[4:6])
gates={name:'FAIL' for name in ('REV01','REV02','completeness','no_false_success','physics','refinement','cli')}
errors=[];native={};cli={}
try:
    native=json.loads((out/'native/native_summary.json').read_text())
    cli=json.loads((out/'cli/cli_summary.json').read_text())
    if nr==0 and native.get('status')=='PASS':
        for key in gates:
            if key!='cli' and native.get('gates',{}).get(key)=='PASS':gates[key]='PASS'
    else:
        for key in gates:
            if key!='cli' and native.get('gates',{}).get(key) in ('PASS','FAIL'):gates[key]=native['gates'][key]
    if cr==0 and cli.get('status')=='PASS':gates['cli']='PASS'
except Exception as exc:errors.append(str(exc))
status='PASS' if nr==cr==0 and all(v=='PASS' for v in gates.values()) and not errors else 'FAIL'
report=dict(id='REV_TEMPORAL',mode=mode,source_commit=head,status=status,gates=gates,native_returncode=nr,
            cli_returncode=cr,errors=errors,native=native,cli=cli)
(out/'summary.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
status_document={k:report[k] for k in ('id','mode','source_commit','status','gates')}
status_document['summary']='summary.json'
(out/'status.json').write_text(json.dumps(status_document,indent=2)+'\n')
(out/'returncode').write_text('0\n' if status=='PASS' else '1\n')
print(json.dumps({k:report[k] for k in ('mode','status','gates')}))
sys.exit(0 if status=='PASS' else 1)
PY
