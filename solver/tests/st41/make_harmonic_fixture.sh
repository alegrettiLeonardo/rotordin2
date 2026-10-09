#!/usr/bin/env bash
# Native synthetic control derived from simple2b-sp; it is NOT an ST41 deck.
# Usage: make_harmonic_fixture.sh OUT [common_phase_deg [NBRMOD [TANGLE [TIMSPD [TIMOEP]]]]]
set -euo pipefail
export LC_ALL=C
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=${1:?output input required}
PHASE=${2:-0}
MODES=${3:-10}
ANGLE=${4:-0}
SPEED=${5:-1800}
POSITION=${6:-0.4125}
awk -v phase="$PHASE" -v modes="$MODES" -v angle="$ANGLE" \
    -v speed="$SPEED" -v position="$POSITION" '
function fields(a,b,c,d,e,f) {
    printf "%-10s%-10s%-10s%-10s%-10s%-10s\n",a,b,c,d,e,f
}
{ sub(/\r$/, "") }
/^UNBL[ ]/ { print; getline; fields(2,900,2400,100,10,""); next }
/^POSITION  VALUE/ {
    print
    fields(0.4075,"3.0E-5",phase,0,"","")
    fields(0.4125,"1.2E-5",phase+37,0,"","")
    next
}
/^FRESPPOS/ {
    print "FRESPPOS  NBRMOD    TIMOEP    TIMSPD    TANGLE    FRUNIT    TRUNIT"
    getline
    fields(4,modes,position,speed,angle,"D         D")
    next
}
/^POSITION  DISPL/ {
    print
    fields(position<0?position:0.4125,1,0,"","","")
    fields(position<0?position:0.4125,2,0,"","","")
    fields(0.8000,1,0,"","","")
    fields(0.8000,2,0,"","","")
    next
}
/^OPTIONS/ { print; getline; print ""; next }
{ print }
' "$ROOT/tests/fixtures/simple2b-sp.txt" > "$OUT"
