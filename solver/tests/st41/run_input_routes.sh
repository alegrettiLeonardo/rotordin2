#!/usr/bin/env bash
# Native synthetic IN-01/02/03 route controls; no archived ST41 deck is implied.
# Usage: run_input_routes.sh BINARY OUT [all|input|orbit]
# A draft outside tests/ can use ST41_ROUTES_ROOT=/path/to/checkout.
set -euo pipefail
export LC_ALL=C
ROOT=${ST41_ROUTES_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}
ROOT=$(realpath -- "$ROOT")
BIN=$(realpath -- "${1:?solver binary required}")
OUT=$(realpath -m -- "${2:?evidence directory required}")
GROUP=${3:-all}
[[ $GROUP == all || $GROUP == input || $GROUP == orbit ]]
[[ -x $BIN ]]
mkdir -p "$OUT"
MODE=release
[[ $BIN != *debug* ]] || MODE=debug
FOUNDATION=${ST41_FOUNDATION_INCLUDE:-$ROOT/tests/st41/harmonic_foundation_physical.inc}
sha256sum "$BIN" "${BASH_SOURCE[0]}" "$ROOT/tests/st41/make_effective_fixture.sh" \
  "$ROOT/tests/st41/make_harmonic_fixture.sh" > "$OUT/provenance.sha256"
cp "$ROOT/build/$MODE/config.stamp" "$OUT/build_config.txt"
git -C "$ROOT" rev-parse HEAD > "$OUT/source_revision.txt"
git -C "$ROOT" diff --stat > "$OUT/source_changes.txt"
printf 'group=%s\nmode=%s\nsynthetic_fixture=simple2b-derived\n' "$GROUP" "$MODE" > "$OUT/scope.txt"
CASES=0
fail() { printf 'FAIL input routes: %s\n' "$*" >&2; exit 1; }

prepare() {
  local name=$1 rated=${2:-0} modal=${3:-0} cfirst=${4:-900} cfinal=${5:-2400} orbit=${6:-1800}
  local kind=${7:-table} work="$OUT/$name"
  [[ ! -e $work ]] || fail "use a fresh evidence directory; $work already exists"
  bash "$ROOT/tests/st41/make_effective_fixture.sh" "$work" "$kind"
  # Preserve fixed-width native rows and alter only the named controls.
  awk -v rated="$rated" -v first="$cfirst" -v last="$cfinal" -v orbit="$orbit" '
    /^DISC$/ {print; getline; printf "%-10s%-10s%s\n",substr($0,1,10),rated,substr($0,21); next}
    /^CPBIS/ {print; getline; printf "%-10s%-10s%-10s%-10s%-10s%s\n",first,last,5,substr($0,31,10),11,substr($0,51); next}
    /^FRESPPOS/ {print; getline; printf "%s%-10s%s\n",substr($0,1,30),orbit,substr($0,41); next}
    {print}
  ' "$work/input.txt" > "$work/input.revised"
  mv "$work/input.revised" "$work/input.txt"
  if [[ $kind == table ]]; then
    awk -v modal="$modal" '
    /^PARAMETERS$/ {print; getline; printf "%s%-10s\n",substr($0,1,20),modal; next}
    {print}
    ' "$work/case.op" > "$work/options.revised"
    mv "$work/options.revised" "$work/case.op"
  # Two-point linear data gives an independent expected value at every lookup,
  # including all eight distinct coefficients, scaling, and extrapolation.
  for bearing in 1 2; do
    cat > "$work/b$bearing.tbl" <<'END_BEARING_DATA'
TABLE
2 2
500 500000000 1000 -2000 600000000 100 2 -3 120
4000 850000000 4500 -5500 950000000 170 9 -10 190
EOF
END_BEARING_DATA
  done
  fi
}

run_case() {
  local name=$1 channel=$2 expected=$3
  shift 3
  local work="$OUT/$name" rc=0
  sha256sum "$BIN" "$work/input.txt" > "$work/inputs.sha256"
  if [[ -f $work/case.op ]]; then
    sha256sum "$work/case.op" "$work/b1.tbl" "$work/b2.tbl" >> "$work/inputs.sha256"
  fi
  printf '%q ' "$BIN" "$@" > "$work/command.txt"
  if [[ $channel == pipe ]]; then
    printf '%s\n' '-std < input.txt (pipe)' >> "$work/command.txt"
    (cd "$work"; ulimit -c 0; cat input.txt | timeout 90 "$BIN" "$@" -std > stdout.out 2> stderr.out) || rc=$?
  else
    printf '%s\n' './input.txt' >> "$work/command.txt"
    (cd "$work"; ulimit -c 0; timeout 90 "$BIN" "$@" ./input.txt > stdout.out 2> stderr.out) || rc=$?
  fi
  printf '%s\n' "$rc" > "$work/returncode.txt"
  [[ $rc == "$expected" ]] || fail "$name returned $rc, expected $expected; see $work/stderr.out"
  ! rg -q 'End of record|Fortran runtime error|SIGSEGV|SIGFPE' "$work/stderr.out" || fail "$name runtime failure"
  CASES=$((CASES+1))
  printf 'PASS route %-24s rc=%s\n' "$name" "$rc"
}

summary_speed() {
  local name=$1 source=$2 rpm=$3
  awk -v source="$source" -v rpm="$rpm" '
    /^ANALYSIS=EXPORT / {n++; if(index($0,"SOURCE=" source " RPM=")==0 || ($NF-rpm)^2>1e-16) bad=1}
    END {exit n!=1 || bad}
  ' "$OUT/$name/effective_input.out" || fail "$name export selection/source"
}

check_lookup() {
  local name=$1 analysis=$2 low=$3 high=$4 minimum=${5:-1}
  # Check both the consumer-level record and the native TABLE interpolation
  # record; a correct summary cannot conceal a different actual lookup speed.
  awk -v analysis="$analysis" -v low="$low" -v high="$high" -v minimum="$minimum" '
    function magnitude(x) {return x<0 ? -x : x}
    function inrange(r) {return r>=low-1e-8 && r<=high+1e-8}
    function coefficients(offset, r, i,want,got,t) {
      t=(r-500)/3500
      for(i=1;i<=8;i++) {
        want=2*(base[i]+delta[i]*t); got=$(offset+i)
        if(magnitude(got-want)>1e-10*(1+magnitude(want))) bad=1
      }
    }
    BEGIN {
      base[1]=5e8; base[2]=1000; base[3]=-2000; base[4]=6e8
      base[5]=100; base[6]=2; base[7]=-3; base[8]=120
      delta[1]=3.5e8; delta[2]=3500; delta[3]=-3500; delta[4]=3.5e8
      delta[5]=70; delta[6]=7; delta[7]=-7; delta[8]=70
      minrpm=1e100; maxrpm=-1e100
    }
    FNR==NR && /^ANALYSIS=/ {
      selected++; if($1!="ANALYSIS=" analysis) bad=1
    }
    FNR==NR && /^#BEGIN EFFECTIVE_BEARINGS / {
      blocks++; r=$NF+0
      if(index($0," ANALYSIS=" analysis " ")==0 || !inrange(r)) bad=1
      if(r<minrpm) minrpm=r; if(r>maxrpm) maxrpm=r
    }
    FNR==NR && /^BEARING_ID=/ {bearings++; if($NF!="SOURCE=TABLE") bad=1}
    FNR==NR && /^EFFECTIVE_KC=/ {rows++; coefficients(1,r)}
    FNR==NR && /^EXTRAPOLATED=/ {
      flags++; expected=(r<500 || r>4000) ? "EXTRAPOLATED=T" : "EXTRAPOLATED=F"
      if($0!=expected) bad=1
    }
    FNR!=NR && /^RD_AUDIT_V1 BEARING_COEFFICIENTS / {
      native++; if(!inrange($5+0)) bad=1; coefficients(5,$5+0)
    }
    END {
      if(selected!=1 || blocks<minimum || rows!=2*blocks || bearings!=rows || flags!=rows || native<rows) bad=1
      printf "LOOKUP %s: blocks=%d coefficients=%d native_rows=%d min=%.16g max=%.16g\n",analysis,blocks,rows,native,minrpm,maxrpm
      exit bad
    }
  ' "$OUT/$name/effective_input.out" "$OUT/$name/stdout.out" > "$OUT/$name/lookup_assertions.txt" || fail "$name actual TABLE lookup/coefficient/context"
}

check_domain_error() {
  local name=$1 rpm=$2
  rg -q 'IN_BEARING_DATA' "$OUT/$name/stdout.out" "$OUT/$name/stderr.out" || fail "$name missing domain context"
  rg -q 'BEARING 1; source=.*b1.tbl' "$OUT/$name/stdout.out" "$OUT/$name/stderr.out" || fail "$name missing bearing/file"
  awk -v rpm="$rpm" '
    /requested rpm=/ {s=$0; sub(/^.*requested rpm=/,"",s); if((s+0-rpm)^2<1e-12) found=1}
    END {exit !found}
  ' "$OUT/$name/stdout.out" "$OUT/$name/stderr.out" || fail "$name missing requested rpm=$rpm"
  ! rg -q '^#BEGIN EFFECTIVE_BEARINGS' "$OUT/$name/effective_input.out" || fail "$name fabricated coefficients after rejected lookup"
}

check_constant_foundation_lookup() {
  local name=$1
  awk '
    /^ANALYSIS=/ {selected++; if($1!="ANALYSIS=FREQUENCY_RESPONSE") bad=1}
    /^#BEGIN EFFECTIVE_BEARINGS / {
      blocks++; expected=900+100*(blocks-1)
      if(index($0," ANALYSIS=FREQUENCY_RESPONSE ")==0 || ($NF-expected)^2>1e-16) bad=1
    }
    /^BEARING_ID=/ {bearings++; if($NF!="SOURCE=CONSTANT") bad=1}
    /^EFFECTIVE_KC=/ {
      rows++
      if($2!=1e9 || $3!=0 || $4!=0 || $5!=1e9 || $6!=200 || $7!=0 || $8!=0 || $9!=200) bad=1
    }
    END {
      printf "LOOKUP FREQUENCY_RESPONSE: blocks=%d coefficients=%d source=CONSTANT\n",blocks,rows
      exit selected!=1 || blocks!=16 || rows!=32 || bearings!=rows || bad
    }
  ' "$OUT/$name/effective_input.out" > "$OUT/$name/lookup_assertions.txt" || fail "$name constant coefficients/context/grid"
}

if [[ $GROUP != orbit ]]; then
  prepare campbell_table
  run_case campbell_table file 0 -c -b
  check_lookup campbell_table CAMPBELL 900 2400 5
  awk '
    /^ANALYSIS=CAMPBELL / {
      n++; s=$0; sub(/^.*FIRST,LAST,INITIAL_COUNT=/,"",s); split(s,a)
      if(a[1]+0!=900 || a[2]+0!=2400 || a[3]+0!=5 || index($0,"PRESENTATION_COUNT(INTSPD)=11")==0) bad=1
    }
    END {exit n!=1 || bad}
  ' "$OUT/campbell_table/effective_input.out" || fail 'Campbell initial count/presentation controls'
  prepare campbell_outside 0 0 374 2400
  run_case campbell_outside file 1 -c -b
  check_domain_error campbell_outside 374

  prepare export_nrat 1800 1600
  prepare export_mdrpm 0 1600
  prepare export_fallback 0 0
  for specification in 'export_nrat NRAT 1800' 'export_mdrpm MDRPM 1600' 'export_fallback CAMPBELL_MIDPOINT 1650'; do
    read -r name source rpm <<< "$specification"
    run_case "$name" file 0 -x -b
    summary_speed "$name" "$source" "$rpm"
    check_lookup "$name" EXPORT "$rpm" "$rpm"
  done

  for rpm in 375 500 4000 5000; do
    name="table_boundary_$rpm"
    prepare "$name" "$rpm"
    run_case "$name" file 0 -x -b
    summary_speed "$name" NRAT "$rpm"
    check_lookup "$name" EXPORT "$rpm" "$rpm"
    rg -q 'EXTRAP_FACTORS= 7.5000000000000000E-001  1.2500000000000000E\+000' "$OUT/$name/effective_input.out" || fail "$name extrapolation policy"
    if [[ $rpm == 375 || $rpm == 5000 ]]; then
      rg -q '^EXTRAPOLATED=T$' "$OUT/$name/effective_input.out" || fail "$name missing explicit extrapolation"
      rg -q '^RD_AUDIT_V1 BEARING_EXTRAP ' "$OUT/$name/stdout.out" || fail "$name missing native extrapolation record"
    fi
  done
  for rpm in 374.9 5000.1; do
    name="table_outside_$rpm"
    prepare "$name" "$rpm"
    run_case "$name" file 1 -x -b
    check_domain_error "$name" "$rpm"
  done

  [[ -f $FOUNDATION ]] || fail "physical foundation include is unavailable: $FOUNDATION"
  sha256sum "$FOUNDATION" >> "$OUT/provenance.sha256"
  for channel in pipe file; do
    for extra in 0 1; do
      name="foundation_${channel}_$extra"
      prepare "$name" 0 0 900 2400 1800 constant
      awk -v extra="$extra" '/^SUPPORT/ {if(extra) print ""} {print}' "$OUT/$name/input.txt" > "$OUT/$name/input.revised"
      mv "$OUT/$name/input.revised" "$OUT/$name/input.txt"
      cat "$FOUNDATION" >> "$OUT/$name/input.txt"
      printf '\nMESH_AUDIT ON\nMESH_MODES 7\n' >> "$OUT/$name/input.txt"
      run_case "$name" "$channel" 0 -f -b
      check_constant_foundation_lookup "$name"
      for interface in 1 2; do
        rg -q "LOCAL_REFERENCE_PATH=VIA_FOUNDATION_REFERENCE_UNRESOLVED FOUNDATION_INTERFACE=$interface" "$OUT/$name/effective_input.out" || fail "$name missing foundation interface $interface"
      done
      rg -q 'MESH MODES[ ]*: 7' "$OUT/$name/model_audit.out" || fail "$name following control lost"
      [[ $(wc -l < "$OUT/$name/foundation_response.csv") == 33 ]] || fail "$name foundation response missing"
      if [[ $channel == pipe ]]; then
        awk '/#BEGIN unblresp.out/ {on=1; next} /#END unblresp.out/ {on=0} on' "$OUT/$name/stdout.out" > "$OUT/$name/response.txt"
      else
        cp "$OUT/$name/input_ur.txt" "$OUT/$name/response.txt"
      fi
      awk '/Amplitude \(rpm\)/ {on=1} on {print}' "$OUT/$name/response.txt" > "$OUT/$name/numeric.txt"
      for artifact in effective_input.out model_audit.out foundation_response.csv numeric.txt; do
        cmp "$OUT/foundation_pipe_0/$artifact" "$OUT/$name/$artifact" || fail "$name $artifact channel/blank mismatch"
      done
    done
  done
fi

if [[ $GROUP != input ]]; then
  prepare orbit_table_sweep 0 0 900 2400 0
  run_case orbit_table_sweep file 0 -t -b
  check_lookup orbit_table_sweep HARMONIC_ORBIT 900 2400 16
  [[ $(rg -c '^#BEGIN EFFECTIVE_BEARINGS' "$OUT/orbit_table_sweep/effective_input.out") == 16 ]] || fail 'orbit sweep performed extra lookups'
  rg -q '^ANALYSIS=HARMONIC_ORBIT SOURCE=UNBIF,UNBFF,UNBFD.*COUNT=16$' "$OUT/orbit_table_sweep/effective_input.out" || fail 'orbit sweep effective grid'
  rg -q 'NBRMOD ignored; no modal truncation' "$OUT/orbit_table_sweep/input_tr.txt" || fail 'orbit physical kernel not integrated'
  ! rg -q 'ANALYSIS=MODAL_SPACE' "$OUT/orbit_table_sweep/stderr.out" || fail 'orbit still prepared an eigensolution'
fi

printf 'PASS IN routes: group=%s; %d native cases; actual TABLE values/context/domain; selected export precedence; FOUNDATION stream equivalence\n' "$GROUP" "$CASES" | tee "$OUT/summary.txt"
