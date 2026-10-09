#!/usr/bin/env bash
# Effective K/C and speed queries are verified on actual native solver runs.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
binary=$(realpath -- "${1:?solver binary required}")
out=$(realpath -m -- "${2:-build/st41-input-effective}")
mode=release
[[ $binary != *debug* ]] || mode=debug
compiler=${FC:-gfortran}
mkdir -p "$out"
sha256sum "$binary" > "$out/binary.sha256"
cp "build/$mode/config.stamp" "$out/build_config.txt"
mapfile -t objects < <(awk '!/\/rotordin\.o$/' "build/$mode/link.objects")
"$compiler" -O0 -g -std=f2018 -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow \
  -I"build/$mode/mod/solver" tests/st41/effective_input_cases.f90 \
  "${objects[@]}" -o "$out/effective_input_cases"
"$out/effective_input_cases" | tee "$out/oracles.txt"
run() {
  local name=$1 kind=$2 expected=$3
  shift 3
  local work="$out/$name" rc=0
  bash tests/st41/make_effective_fixture.sh "$work" "$kind"
  case "$name" in
    empty_table) : > "$work/b2.tbl" ;;
    empty_kind) sed -i '2s/./ /g' "$work/case.op" ;;
    table_bad_scale) sed -i '2c2 INVALID' "$work/b2.tbl" ;;
    table_nan_scale) sed -i '2c2 NaN' "$work/b2.tbl" ;;
    table_inf_scale) sed -i '2c2 Infinity' "$work/b2.tbl" ;;
    table_bad_row) sed -i '3c500 1 2 INVALID' "$work/b2.tbl" ;;
    bearing_bad_scale|bearing_bad_rks|bearing_bad_fxstf|bearing_nan_scale)
      header='2 INVALID'
      [[ $name != bearing_bad_rks ]] || header='2 1 INVALID'
      [[ $name != bearing_bad_fxstf ]] || header='2 1 0 INVALID'
      [[ $name != bearing_nan_scale ]] || header='2 NaN'
      awk -v header="$header" '/^BEARING$/ {print; getline; print header; next} {print}' \
        "$work/input.txt" > "$work/edited.txt"
      mv "$work/edited.txt" "$work/input.txt" ;;
    orbit_zero_grid)
      awk '/^UNBL[ ]/ {print; getline; printf "%-10s%-10s%-10s%-10s%-10s\n",2,0,300,100,10; next}
      /^FRESPPOS/ {print; getline; printf "%-10s%-10s%-10s%-10s%-10s%-10s\n",4,10,0.4125,0,0,"D         D"; next}
      {print}' "$work/input.txt" > "$work/edited.txt"
      mv "$work/edited.txt" "$work/input.txt" ;;
  esac
  sha256sum "$binary" "$work/input.txt" > "$work/inputs.sha256"
  if [[ -f $work/case.op ]]; then sha256sum "$work/case.op" "$work"/*.tbl >> "$work/inputs.sha256"; fi
  printf '%q ' "$binary" "$@" ./input.txt > "$work/command.txt"
  printf '\n' >> "$work/command.txt"
  (cd "$work"; ulimit -c 0; timeout 90 "$binary" "$@" ./input.txt > stdout.out 2> stderr.out) || rc=$?
  printf '%s\n' "$rc" > "$work/returncode.txt"
  [[ $rc == "$expected" ]]
  ! rg -q 'End of record|Fortran runtime error|SIGSEGV|SIGFPE' "$work/stderr.out"
  printf 'PASS %s: expected rc=%s\n' "$name" "$rc"
}
run constant constant 0 -f -b
run table table 0 -f -b
run zero_literal zero 0 -f -b
run free free 0 -f
run missing missing 1 -f -b
run modal_zero table 1 -m -b
run modal_override override 0 -m -b
run orbit_speed table 0 -t -b
run modes_and_orbit constant 0 -m -t -b
run orbit_zero_grid constant 0 -t -b
run empty_table table 1 -f -b
run empty_kind table 1 -f -b
run table_bad_scale table 1 -f -b
run table_nan_scale table 1 -f -b
run table_inf_scale table 1 -f -b
run table_bad_row table 1 -f -b
run bearing_bad_scale constant 1 -f -b
run bearing_bad_rks constant 1 -f -b
run bearing_bad_fxstf constant 1 -f -b
run bearing_nan_scale constant 1 -f -b

# Table placeholders must resolve to the same coefficients/response as constants.
awk '/Amplitude \(rpm\)/ {on=1} on {print}' "$out/constant/input_ur.txt" > "$out/constant/numeric.txt"
awk '/Amplitude \(rpm\)/ {on=1} on {print}' "$out/table/input_ur.txt" > "$out/table/numeric.txt"
cmp "$out/constant/numeric.txt" "$out/table/numeric.txt"
rg -q 'SOURCE=TABLE' "$out/table/effective_input.out"
rg -q 'SCALE= 2.0000000000000000E\+000' "$out/table/effective_input.out"
! rg -q 'NO_TRANSLATIONAL_TRANSMISSION|ANALYSIS=MODES' "$out/table/effective_input.out"
[[ $(rg -c '^#BEGIN EFFECTIVE_BEARINGS' "$out/table/effective_input.out") == 16 ]]
! rg -q 'COEFFICIENT_LOOKUP_RPM= 0.0000000000000000E' "$out/table/effective_input.out"
rg -q 'SOURCE=UNBIF,UNBFF,UNBFD.*COUNT=16' "$out/table/effective_input.out"
rg -q 'NO_TRANSLATIONAL_TRANSMISSION' "$out/zero_literal/effective_input.out"
rg -q 'SUPPORT_KC= 1.0000000000000000E\+008' "$out/zero_literal/effective_input.out"
rg -q 'GLOBAL_REFERENCE_CONSTRAINT=NOT_DETERMINED' "$out/zero_literal/effective_input.out"
rg -q 'FREE_MODEL_ALLOWED=YES' "$out/free/effective_input.out"
rg -q 'BEARING 2; source=.*b2.tbl' "$out/missing/stdout.out" "$out/missing/stderr.out"
rg -q 'IN_BEARING_DATA' "$out/modal_zero/stdout.out" "$out/modal_zero/stderr.out"
rg -q 'requested rpm=0.0000000000000000E\+000' "$out/modal_zero/stdout.out" "$out/modal_zero/stderr.out"
rg -q 'ANALYSIS=MODES SOURCE=MDRPM\(options\) RPM= 1.6000000000000000E\+003' \
  "$out/modal_override/effective_input.out"
rg -q 'ANALYSIS=HARMONIC_ORBIT SOURCE=TIMSPD RPM= 1.8000000000000000E\+003' \
  "$out/orbit_speed/effective_input.out"
rg -q 'ANALYSIS=MODES SOURCE=MDRPM\(input\) RPM= 0.0000000000000000E\+000' \
  "$out/modes_and_orbit/effective_input.out"
rg -q 'ANALYSIS=HARMONIC_ORBIT SOURCE=TIMSPD RPM= 1.8000000000000000E\+003' \
  "$out/modes_and_orbit/effective_input.out"
rg -q 'ANALYSIS=HARMONIC_ORBIT SOURCE=UNBIF,UNBFF,UNBFD FIRST,ACTUAL_LAST,STEP= 1.0000000000000000E\+002.*COUNT=3' \
  "$out/orbit_zero_grid/effective_input.out"
! rg -q 'ANALYSIS=SETUP|ANALYSIS=MODES' "$out/orbit_zero_grid/effective_input.out"
for name in empty_table table_bad_scale table_nan_scale table_inf_scale table_bad_row; do
  rg -q 'BEARING 2; source=.*b2.tbl' "$out/$name/stdout.out" "$out/$name/stderr.out"
  rg -q 'IN_BEARING_DATA' "$out/$name/stdout.out" "$out/$name/stderr.out"
done
printf '%s\n' 'PASS IN-01/02: 20 native cases; table/constant amplitude+phase byte equality; no unselected zero lookup; controlled missing/domain/malformed errors'
