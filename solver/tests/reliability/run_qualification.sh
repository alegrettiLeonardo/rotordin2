#!/usr/bin/env bash
# Reproduce all available mathematical-reliability and frozen ST41 controls.
# Usage: run_qualification.sh [fresh-output] [pre-ST41-release] [pre-ST41-debug]
# A successful executor does not qualify the explicitly blocked A02/A07 domains.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
ROOT=$PWD
OUT=$(realpath -m -- "${1:-build/mathematical-reliability}")
OLD_RELEASE=$(realpath -m -- "${2:-../evidence/pre-st41/rotordin2-baseline}")
OLD_DEBUG=$(realpath -m -- "${3:-../evidence/pre-st41/rotordin2-debug-baseline}")
BASE=4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47
export FC=${FC:-gfortran}
export PYTHON=${PYTHON:-python3}
command -v "$FC" >/dev/null
command -v "$PYTHON" >/dev/null
[[ ! -e $OUT && ! -L $OUT ]] || { echo "Use a new, nonexistent qualification output: $OUT" >&2; exit 2; }
[[ -z ${RELIABILITY_BUILD_DIR:-} ]] || { echo 'Final qualification rejects external build objects.' >&2; exit 2; }
[[ ${A04_BASELINE:-0} == 0 && ${A05_BASELINE:-0} == 0 ]] || { echo 'Final qualification rejects baseline-only test modes.' >&2; exit 2; }
[[ ${A02_BASE_REF:-$BASE} == "$BASE" ]] || { echo 'Final qualification requires the restored A02 baseline.' >&2; exit 2; }
[[ ${REV_TEMPORAL_BASELINE:-0} == 0 ]] || { echo 'Final qualification rejects REV temporal baseline mode.' >&2; exit 2; }
[[ -z ${REV_TEMPORAL_BIN:-} && -z ${REV_TEMPORAL_SKIP_BUILD:-} && -z ${REV_TEMPORAL_EVIDENCE_ROOT:-} ]] || {
  echo 'Final qualification owns REV temporal binaries, builds and evidence paths; remove external overrides.' >&2
  exit 2
}
[[ -x $OLD_RELEASE && -x $OLD_DEBUG ]] || { echo 'Supply both executable pre-ST41 baseline binaries for Campbell.' >&2; exit 2; }
[[ -z $(git status --porcelain=v1) ]] || { echo 'Qualification requires a clean tracked/untracked source tree.' >&2; exit 2; }
mkdir -p "$OUT/logs" "$OUT/binaries"
git rev-parse HEAD > "$OUT/source_commit.txt"
git rev-parse HEAD^{tree} > "$OUT/source_tree.txt"
git branch --show-current > "$OUT/source_branch.txt"
git status --porcelain=v1 > "$OUT/source_status.before.txt"
# A normal clone creates only its default local branch. Verify the preserved
# original branch whether it is local or still under origin after restoration.
BASE_REF=refs/heads/task/st41-priority-fixes
if ! git show-ref --verify --quiet "$BASE_REF"; then
  BASE_REF=refs/remotes/origin/task/st41-priority-fixes
fi
printf '%s\n' "$BASE_REF" > "$OUT/original_branch_ref.txt"
git rev-parse --verify "$BASE_REF" > "$OUT/original_branch.txt"
[[ $(cat "$OUT/original_branch.txt") == "$BASE" ]] || { echo 'Original baseline branch changed.' >&2; exit 2; }
git log --format='%H %s' "$BASE..HEAD" > "$OUT/implementation_commits.txt"
git diff --stat "$BASE" HEAD > "$OUT/implementation_changes.txt"
git ls-files -z | xargs -0 sha256sum > "$OUT/tracked_source.sha256"
"$FC" --version > "$OUT/compiler.txt"
uname -a > "$OUT/platform.txt"
"$PYTHON" -c 'import json,sys,numpy,scipy; print(json.dumps({"python":sys.version,"numpy":numpy.__version__,"scipy":scipy.__version__},indent=2))' > "$OUT/python.json"
sha256sum "$OLD_RELEASE" "$OLD_DEBUG" > "$OUT/baseline_binaries.sha256"
printf 'check\treturncode\tresult\tlog\n' > "$OUT/status.tsv"
OVERALL=0
run() {
  local label=$1 rc=0 result=PASS
  shift
  printf '%q ' "$@" > "$OUT/logs/$label.command.txt"
  printf '\n' >> "$OUT/logs/$label.command.txt"
  "$@" > "$OUT/logs/$label.log" 2>&1 || rc=$?
  if [[ $rc != 0 ]]; then result=FAIL; OVERALL=1; fi
  printf '%s\t%s\t%s\tlogs/%s.log\n' "$label" "$rc" "$result" "$label" >> "$OUT/status.tsv"
  printf '%s %s (rc=%s)\n' "$result" "$label" "$rc"
  if [[ $rc != 0 ]]; then tail -30 "$OUT/logs/$label.log" >&2; fi
}

run source-integrity bash tests/check_sources.sh
run source-layout bash tests/check_sources.sh --layout
run frozen-regressions git diff --exit-code "$BASE" -- tests/ ':(exclude)tests/reliability/**' \
  lapack/ docs/legacy/lapack/ docs/manifests/LAPACK.sha256 \
  src/source/resp_f.f90 src/source/resp_fv.f90 src/source/resp_t.f90 \
  src/source/rd_harmonic_response.f90 src/source/rd_campbell_engine.f90 \
  src/source/rd_campbell_families.f90 src/source/transient_speed.f90

for MODE in release debug; do
  run "A01-$MODE" bash tests/reliability/run_a01.sh "$MODE" "$OUT/A01/$MODE"
done
run A02-both bash tests/reliability/a02_run.sh "$OUT/A02"
for MODE in release debug; do
  run "A04-$MODE" bash tests/reliability/a04_run.sh "$MODE" "$OUT/A04/$MODE"
  run "A05-$MODE" bash tests/reliability/a05_run.sh "$MODE" "$OUT/A05/$MODE"
  run "A07-$MODE" bash tests/reliability/a07_run.sh "$MODE" "$OUT/A07/$MODE"
done

collect_rev_gates() {
  # Read the two make-test executions inside ST41; never run the bank again here.
  "$PYTHON" - "$OUT/REV" "$OUT/REV-gates" "$OUT/source_commit.txt" <<'PY'
import json
import pathlib
import sys

root, prefix, campaign_source = map(pathlib.Path, sys.argv[1:])
published = ("REV01", "REV02", "completeness", "no_false_success")
required = published + ("physics", "refinement", "cli")
modes = {}
for mode in ("release", "debug"):
    errors = []
    observed = {gate: "FAIL" for gate in required}
    try:
        folder = root / mode
        summary = json.loads((folder / "summary.json").read_text())
        status = json.loads((folder / "status.json").read_text())
        if not isinstance(summary, dict) or not isinstance(status, dict):
            raise ValueError("status and summary must be JSON objects")
        if (folder / "returncode").read_text().strip() != "0":
            errors.append("runner returncode is not zero")
        if (status.get("id") != "REV_TEMPORAL" or status.get("summary") != "summary.json"
                or status.get("mode") != mode or summary.get("mode") != mode):
            raise ValueError("unexpected status identity, mode or summary path")
        expected_commit = campaign_source.read_text().strip()
        if not expected_commit:
            raise ValueError("campaign source commit is missing")
        if (summary.get("source_commit") != expected_commit
                or status.get("source_commit") != expected_commit
                or (folder / "source_commit.txt").read_text().strip() != expected_commit):
            errors.append("runner source commit differs from campaign")
        for name, data in (("summary", summary), ("status", status)):
            if data.get("status") != "PASS":
                errors.append(f"{name}: status is not PASS")
            gates = data.get("gates")
            if not isinstance(gates, dict):
                errors.append(f"{name}: gates missing or invalid")
            elif any(gates.get(gate) != "PASS" for gate in required):
                errors.append(f"{name}: a required gate is absent or not PASS")
        if summary.get("gates") != status.get("gates"):
            errors.append("summary/status gates disagree")
        summary_gates, status_gates = summary.get("gates"), status.get("gates")
        if isinstance(summary_gates, dict) and isinstance(status_gates, dict):
            observed = {gate: "PASS" if summary_gates.get(gate) == status_gates.get(gate) == "PASS"
                        else "FAIL" for gate in required}
    except (OSError, ValueError, TypeError) as exc:
        errors.append(str(exc))
    modes[mode] = {"status": "FAIL" if errors else "PASS", "gates": observed, "errors": errors}

passed = all(value["status"] == "PASS" for value in modes.values())
gates = {gate: "PASS" if all(value["status"] == "PASS" and value["gates"][gate] == "PASS"
                           for value in modes.values())
         else "FAIL" for gate in published}
result = {"id": "REV_TEMPORAL_AGGREGATE", "status": "PASS" if passed else "FAIL",
          "scope": "Read Release/Debug evidence from ST41 make test; no repeated executions or case counts",
          "gates": gates, "modes": modes}
prefix.with_suffix(".json").write_text(json.dumps(result, indent=2) + "\n")
lines = [f"REV_{gate.upper()}={value}" if not gate.startswith("REV") else f"{gate}={value}"
         for gate, value in gates.items()]
prefix.with_suffix(".txt").write_text("\n".join(lines) + "\n")
print(json.dumps(result, indent=2))
sys.exit(0 if passed else 1)
PY
}

# This frozen executor runs make test once in Release and once in Debug. The new
# test-temporal prerequisite writes into REV; do not duplicate its executions.
run ST41-available env REV_TEMPORAL_EVIDENCE_ROOT="$OUT/REV" \
  bash tests/st41/run_qualification.sh "$OUT/ST41" "$OLD_RELEASE" "$OLD_DEBUG"
printf '%s\n' 'REV01=FAIL' 'REV02=FAIL' 'REV_COMPLETENESS=FAIL' 'REV_NO_FALSE_SUCCESS=FAIL' > "$OUT/REV-gates.txt"
run REV-summary-gates collect_rev_gates
run final-source-integrity bash tests/check_sources.sh
verify_source_identity() {
  git rev-parse HEAD > "$OUT/source_commit.after.txt"
  git rev-parse --verify "$BASE_REF" > "$OUT/original_branch.after.txt"
  cmp "$OUT/source_commit.txt" "$OUT/source_commit.after.txt" &&
    cmp "$OUT/original_branch.txt" "$OUT/original_branch.after.txt"
}
run final-source-identity verify_source_identity
run final-tracked-content sha256sum --check "$OUT/tracked_source.sha256"
git status --porcelain=v1 > "$OUT/source_status.after.txt"
if [[ -s $OUT/source_status.after.txt ]]; then
  OVERALL=1
  printf 'clean-final-tree\t1\tFAIL\tsource_status.after.txt\n' >> "$OUT/status.tsv"
else
  printf 'clean-final-tree\t0\tPASS\tsource_status.after.txt\n' >> "$OUT/status.tsv"
fi
collect_binaries() {
  local bin
  for bin in rotordin2 rotordin2-debug; do
    [[ -x bin/$bin ]] || { echo "Missing executable: bin/$bin" >&2; return 1; }
    cp -p "bin/$bin" "$OUT/binaries/$bin" || return 1
  done
  sha256sum "$OUT/binaries/rotordin2" "$OUT/binaries/rotordin2-debug" > "$OUT/final_binaries.sha256"
}
run final-binaries collect_binaries
printf '%s\n' "$OVERALL" > "$OUT/returncode.txt"
if [[ $OVERALL == 0 ]]; then
  printf 'AVAILABLE_EXECUTED_CONTROLS=PASS\n' > "$OUT/result.txt"
else
  printf 'AVAILABLE_EXECUTED_CONTROLS=FAIL\n' > "$OUT/result.txt"
fi
cat "$OUT/REV-gates.txt" >> "$OUT/result.txt"
cat >> "$OUT/result.txt" <<'DOMAINS'
A02_GLOBAL=NOT_QUALIFIED
A02_THREE_NODE_GLOBAL_FORMULATION=NOT_QUALIFIED
A07_GLOBAL=NOT_QUALIFIED
A07_ACTIVE_GYRO_RUNUP_RUNDOWN=NOT_QUALIFIED
HISTORICAL_ST41=BLOCKED
HISTORICAL_ST41_REASON=BLOCKED_MISSING_FIXTURES
Passing the available controls does not override these physical/data limits.
DOMAINS
cat "$OUT/result.txt"
exit "$OVERALL"
