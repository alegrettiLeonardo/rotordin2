#!/usr/bin/env bash
# Reproducible native A02 qualification. No I/O or physics stubs are linked.
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
out=$(realpath -m -- "${1:-build/reliability/a02/qualification}")
compiler=${FC:-gfortran}
python=${PYTHON:-python3}
base=${A02_BASE_REF:-4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47}
mkdir -p "$out/baseline-source"
"$compiler" --version > "$out/compiler.txt"
git rev-parse HEAD > "$out/head.txt"
printf '%s\n' "$base" > "$out/baseline-ref.txt"
for f in ttrqdiv tresp_f tpefora tsaidas; do
  git show "$base:src/source/torsion/$f.f90" > "$out/baseline-source/$f.f90"
done
sha256sum src/source/torsion/{ttrqdiv,tresp_f,tpefora,tsaidas}.f90 \
  tests/reliability/a02* docs/qualification/tools/a02*.py "$out/baseline-source/"*.f90 > "$out/source.sha256"
for mode in release debug; do
  mkdir -p "$out/$mode/current" "$out/$mode/baseline"
  if ! make MODE="$mode" FC="$compiler" -j"${A02_JOBS:-4}" > "$out/$mode/make.log" 2>&1; then
    tail -30 "$out/$mode/make.log" >&2; exit 1
  fi
  flags=(-cpp -D_LINUX -std=f2018)
  if [[ $mode == debug ]]; then
    flags+=(-O0 -g -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
  else
    flags+=(-O3 -ffpe-summary=none)
  fi
  mapfile -t objects < <(awk '!/\/rotordin\.o$/' "build/$mode/link.objects")
  for variant in baseline current; do
    work="$out/$mode/$variant"
    selected=("${objects[@]}")
    define=(-DA02_CURRENT)
    if [[ $variant == baseline ]]; then
      define=()
      for f in ttrqdiv tresp_f tpefora tsaidas; do
        "$compiler" "${flags[@]}" -I"build/$mode/mod/solver" \
          -c "$out/baseline-source/$f.f90" -o "$work/$f.o" > "$work/compile-$f.log" 2>&1
        for i in "${!selected[@]}"; do
          if [[ ${selected[i]} == "build/$mode/obj/solver/torsion/$f.o" ]]; then
            selected[i]="$work/$f.o"
          fi
        done
      done
    fi
    "$compiler" "${flags[@]}" "${define[@]}" -I"build/$mode/mod/solver" \
      tests/reliability/a02_native.f90 "${selected[@]}" -o "$work/native" > "$work/compile-native.log" 2>&1
    sha256sum "$work/native" > "$work/binary.sha256"
    for route in frequency periodic periodic_firstnode; do
      for ratio in 0.5 1 2 -2; do
        for phase in 0 90 180 270; do
          "$work/native" "$route" "$ratio" "$phase" 1 > "$work/$route-r$ratio-p$phase.log" \
            2> "$work/$route-r$ratio-p$phase.stderr"
        done
      done
    done
    if [[ $variant == current ]]; then
      "$compiler" "${flags[@]}" -I"build/$mode/mod/solver" tests/reliability/a02_phasors.f90 \
        "${selected[@]}" -o "$work/phasors" > "$work/compile-phasors.log" 2>&1
      "$work/phasors" > "$work/phasors.log" 2> "$work/phasors.stderr"
      for route in frequency periodic; do
        "$work/native" "$route" 1 180 2 > "$work/$route-3node.log" 2> "$work/$route-3node.stderr"
        rg -q 'A02 NOT_QUALIFIED' "$work/$route-3node.log"
      done
      "$work/native" firstnode 1 180 1 > "$work/firstnode-r1-p180.log" 2> "$work/firstnode-r1-p180.stderr"
    else
      "$compiler" "${flags[@]}" -I"build/$mode/mod/solver" tests/reliability/a02_baseline.f90 \
        "${selected[@]}" -o "$work/baseline_counterexample" > "$work/compile-counterexample.log" 2>&1
      "$work/baseline_counterexample" > "$work/baseline-counterexample.log" 2> "$work/baseline-counterexample.stderr"
      rg -q 'FAIL_REPRODUCED' "$work/baseline-counterexample.log"
      rc=0
      "$work/native" firstnode 1 180 1 > "$work/firstnode-frequency.log" 2> "$work/firstnode-frequency.stderr" || rc=$?
      printf '%s\n' "$rc" > "$work/firstnode-frequency.returncode"
      [[ $rc -ne 0 ]]
      rg -q "tqdivf.*invalid data|Index '0'.*below lower bound" "$work/firstnode-frequency.stderr" "$work/firstnode-frequency.log"
    fi
  done
  "$python" docs/qualification/tools/a02_compare.py "$out/$mode" | tee "$out/$mode/comparison.log"
  "$python" docs/qualification/tools/a02_ross_compare.py "$out/$mode" | tee "$out/$mode/ross-comparison.log"
done
printf '%s\n' 'A02 TWO_NODE_COMPLEX_RECOVERY PASS; THREE_NODE_FULL_INTERPOLATION NOT_QUALIFIED'
