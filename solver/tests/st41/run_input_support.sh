#!/usr/bin/env bash
# Compare actual stdin pipe and file parsing, with/without a blank before SUPPORT.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
binary=$(realpath -- "${1:?solver binary required}")
out=$(realpath -m -- "${2:-build/st41-input-support}")
baseline=${3:-}
mode=release
[[ $binary != *debug* ]] || mode=debug
compiler=${FC:-gfortran}
mkdir -p "$out"
sha256sum "$binary" > "$out/binary.sha256"
cp "build/$mode/config.stamp" "$out/build_config.txt"
mapfile -t objects < <(awk '!/\/rotordin\.o$/' "build/$mode/link.objects")
"$compiler" -O0 -g -std=f2018 -fcheck=all -fbacktrace \
  -I"build/$mode/mod/solver" tests/st41/support_records.f90 \
  "${objects[@]}" -o "$out/support_records"
"$out/support_records" | tee "$out/records.txt"

run_case() {
  local target=$1 channel=$2 name=$3 extra=$4 rc=0
  local work="$out/$name"
  mkdir -p "$work"
  bash tests/st41/make_harmonic_fixture.sh "$work/base.txt"
  awk -v extra="$extra" '/^SUPPORT/ {if(extra) print ""} {print}' \
    "$work/base.txt" > "$work/input.txt"
  printf '\nMESH_AUDIT ON\nMESH_MODES 7\n' >> "$work/input.txt"
  sha256sum "$target" "$work/input.txt" > "$work/inputs.sha256"
  printf '%q ' "$target" -f -b > "$work/command.txt"
  if [[ $channel == pipe ]]; then
    printf '%s\n' '-std < input.txt (pipe)' >> "$work/command.txt"
    (cd "$work"; ulimit -c 0; cat input.txt | timeout 60 "$target" -std -f -b \
      > stdout.out 2> stderr.out) || rc=$?
  else
    printf '%s\n' './input.txt' >> "$work/command.txt"
    (cd "$work"; ulimit -c 0; timeout 60 "$target" -f -b ./input.txt \
      > stdout.out 2> stderr.out) || rc=$?
  fi
  printf '%s\n' "$rc" > "$work/returncode.txt"
  if [[ $name == baseline_file_noextra ]]; then
    [[ $rc != 0 ]]
    printf 'PASS fail-before: unmodified file reader returned %s without the extra blank\n' "$rc"
    return
  fi
  [[ $rc == 0 ]]
  ! rg -q 'End of record|Fortran runtime error|SIGSEGV|SIGFPE' "$work/stderr.out"
  rg -q 'MESH MODES[ ]*: 7' "$work/model_audit.out"
  if [[ $channel == pipe ]]; then
    awk '/#BEGIN unblresp.out/ {on=1; next} /#END unblresp.out/ {on=0} on' \
      "$work/stdout.out" > "$work/response.txt"
  else
    cp "$work/input_ur.txt" "$work/response.txt"
  fi
  # Exact amplitudes/phases, without timestamp/path/progress text.
  awk '/Amplitude \(rpm\)/ {on=1} on {print}' "$work/response.txt" > "$work/numeric.txt"
  printf 'PASS %s: rc=0; following controls preserved\n' "$name"
}

for channel in pipe file; do
  for extra in 0 1; do
    run_case "$binary" "$channel" "${channel}_${extra}" "$extra"
    cmp "$out/pipe_0/model_audit.out" "$out/${channel}_${extra}/model_audit.out"
    cmp "$out/pipe_0/numeric.txt" "$out/${channel}_${extra}/numeric.txt"
  done
done
if [[ -n $baseline ]]; then
  run_case "$(realpath "$baseline")" file baseline_file_noextra 0
  run_case "$(realpath "$baseline")" pipe baseline_pipe_noextra 0
  run_case "$(realpath "$baseline")" file baseline_file_extra 1
  cmp "$out/pipe_0/numeric.txt" "$out/baseline_pipe_noextra/numeric.txt"
  cmp "$out/pipe_0/numeric.txt" "$out/baseline_file_extra/numeric.txt"
fi
# The requested SUPPORT remains an error when truncated.
mkdir -p "$out/incomplete"
awk '/^BEANBR/ {exit} {print}' "$out/pipe_0/input.txt" > "$out/incomplete/input.txt"
rc=0
(cd "$out/incomplete"; cat input.txt | timeout 30 "$binary" -std -f -b \
  > stdout.out 2> stderr.out) || rc=$?
printf '%s\n' "$rc" > "$out/incomplete/returncode.txt"
[[ $rc == 1 ]]
rg -q 'SUPPORT: missing data for row 1' "$out/incomplete/stderr.out"
! rg -q 'End of record|Fortran runtime error' "$out/incomplete/stderr.out"
printf '%s\n' 'PASS IN-03: four channel/blank combinations; model/amplitude/phase byte equality; controlled incomplete input'
