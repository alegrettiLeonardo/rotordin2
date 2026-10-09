#!/usr/bin/env bash
# Named-file native fixtures for effective input; all are synthetic controls.
set -euo pipefail
export LC_ALL=C
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
out=${1:?output directory required}
kind=${2:-table}
mkdir -p "$out"
bash "$root/tests/st41/make_harmonic_fixture.sh" "$out/base.txt"
awk -v kind="$kind" '
function bearing(pos, k, c) {
  printf "%-10s%-10s%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",pos,k,0,k,0,c,0,c,0
}
/^BEARING$/ {
  print; getline
  if(kind=="free") printf "%-10s\n",0; else print
  inbearing=1; next
}
inbearing && /^POSITION  KXX/ {
  print
  for(j=1;j<=2;j++) {
    getline; pos=substr($0,1,10)
    if(kind=="constant") bearing(pos,"1.0E9",200)
    else if(kind!="free") bearing(pos,0,0)
  }
  inbearing=0; next
}
/^OPTIONS$/ {
  print; getline
  if(kind=="table" || kind=="missing" || kind=="override") print "case.op"
  else print ""
  next
}
/^SUPPORT/ {if(kind=="free") exit}
{print}
' "$out/base.txt" > "$out/input.txt"
if [[ $kind == table || $kind == missing || $kind == override ]]; then
  modal=0
  [[ $kind != override ]] || modal=1600
  {
    printf 'KIND\n2         \n\nPARAMETERS\n'
    printf '%-10s%-10s%-10s\n' 2 0 "$modal"
    printf '\nBEARING   FILE\n'
    printf '%-10s%s\n' 1 b1.tbl 2 b2.tbl
    printf '\nOPTIONS\n\n'
  } > "$out/case.op"
  for j in 1 2; do
    [[ $kind != missing || $j != 2 ]] || continue
    cat > "$out/b$j.tbl" <<'BEARING_DATA'
TABLE
2 2
500 500000000 0 0 500000000 100 0 0 100
4000 500000000 0 0 500000000 100 0 0 100
EOF
BEARING_DATA
  done
fi
