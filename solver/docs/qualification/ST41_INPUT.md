# ST41 input corrections - native qualification

## IN-03: SUPPORT records

State: CORRECTED / QUALIFIED on supplied source with synthetic native control.

One physical-record reader handles SUPPORT count and fixed-width coefficient rows
in both inline files and stdin. It accepts the existing stream with or without an
extra blank before SUPPORT, preserves the canonical cross-coefficient order,
reads the entire optional scale and leaves following FOUNDATION/TRANSIENT/control
records available. An optional absent SUPPORT uses a unit-scoped pending record;
no BACKSPACE is used. Requested missing or malformed data remains an error.

Executed with GNU Fortran 13.3.0, bundled LAPACK/BLAS 3.12.1 and unchanged profile
flags. Release and debug builds PASS. Fifteen Fortran assertions PASS per profile
(count, IDs, full scale, contiguous fixed-width fields, cross-term order, following
FOUNDATION marker, pending header, invalid scale and incomplete row).

Four complete solver runs per profile: stdin through a pipe and named input file,
each with/without the extra blank. Return codes all zero. MODEL_AUDIT and all
printed response amplitude/phase data are byte-identical. Following MESH_AUDIT
controls are retained, including MESH_MODES=7. Incomplete SUPPORT returns1 and
identifies missing row1 without a runtime diagnostic failure.

Fail-before evidence: pristine supplied binary with file/no-extra-blank returns1;
pristine stdin/no-extra-blank and file/extra-blank both succeed. Corrected outputs
match both successful pristine cases exactly for the printed amplitude/phase
numbers. The deliberately invalid section deck from RD2-11 remains a separate
regression after this parser change.

Existing release linalg and Campbell/modal stdio smoke suite: PASS, 27 compared
critical-speed values per run, maximum reported difference0rpm.

Commands (run from project root with GNU Fortran in PATH):

```sh
make -j4
FC=gfortran bash tests/st41/run_input_support.sh bin/rotordin2 build/st41-input-support/release
make MODE=debug -j4
FC=gfortran bash tests/st41/run_input_support.sh bin/rotordin2-debug build/st41-input-support/debug
```

An optional third argument to the script is the pristine profile-matched baseline
binary and enables executable fail-before/unchanged-output controls. Full logs for
this execution: evidence/input3/. This control is derived from simple2b-sp and is
not the absent historical ST41 deck.

## IN-01/02

State: CORRECTED / QUALIFIED on the supplied source with synthetic native controls.

`effective_input.out` records only selected analyses. It reports the preserved
origins MDRPM(input/options), TIMSPD, UNBIF/UNBFF/UNBFD, CPBIS/CPBFS/CPBSPD and
NRAT/MDRPM/Campbell-midpoint export precedence. CPBSPD remains the initial sample
count. The direct response keeps its existing repeated-addition grid; the orbit
report reflects RESP_T's existing nonpositive-start omission and integer sample
count. No report initiates a coefficient lookup. The actual PARMAN callback
records every successful resolved lookup, with the active analysis and rpm.
An unselected `-m` never requires TABLE data at zero.

Bearing records contain ID, axial position, source file/type, applied scale,
the eight effective K/C coefficients in canonical order, optional tilt terms,
TABLE domain and the existing extrapolation factors. They expose active SUPPORT
rows, effective housing coefficients and FOUNDATION interfaces. Local K, C and
harmonic K+iωC ranks are diagnostics only; crossed/nonreciprocal terms are kept.
The explicit `GLOBAL_REFERENCE_CONSTRAINT=NOT_DETERMINED` prevents a local path
or rank from being presented as global rigid-body coverage or stability proof.
An all-zero effective translational bearing produces a transmission warning even
with nonzero housing Ks. Zero header placeholders for valid TABLEs do not.
Free models remain admissible. No coefficient, support stiffness, FXSTF or
analysis speed is inserted or changed by this audit.

Missing sources, malformed count/scale fields, invalid TABLE rows and requested
speeds outside the declared domain fail with bearing/source/speed context.
Optional BEARING fields retain their historical defaults only when absent;
present invalid tokens no longer silently fall back. Signed/zero global scales
and the static RKS/FXSTF semantics are preserved. Empty TABLEs and empty KIND
records return controlled errors. The inverse-coefficient input route shares
the same header validation and now resolves relative source paths without the
previous uninitialized local-variable test.

Ordered comparisons follow finitude validation so a quiet NaN is rejected
before the debug profile can trap on comparison. Diagnostic rpm conversion
avoids the intermediate `rad*30` overflow; genuinely unrepresentable rpm is
reported explicitly. These finite-extreme tests qualify diagnostic arithmetic,
not a physically meaningful model at such extreme speeds or coefficients.

### Executed controls

Both release and debug: **34 native assertions plus 20 complete solver cases**.
The assertions cover unchanged export precedence, partial/crossed/scaled ranks,
optional header defaults, explicit malformed/nonfinite fields, NaN speed rejection
and finite-extreme diagnostic arithmetic. CLI controls cover constant/TABLE
equivalence, zero transmission despite nonzero Ks, a free model, missing files,
zero-speed TABLE rejection for selected modes, MDRPM(options)=1600, TIMSPD=1800,
combined `-m -t`, the zero-start orbit grid, empty input and malformed fields.

Measured outcomes:

- Constant coefficients and TABLE values after scale2 produce byte-identical
  amplitude and phase output at all16 direct-response speeds and four channels.
- TABLE-only `-f` records16 actual successful lookups, none at zero, no MODES
  context and no placeholder-based zero-transmission warning.
- TIMSPD=0 with UNBIF/UNBFF/UNBFD=0/300/100 reports first100, last300, count3,
  consistent with the executed orbit.
- All valid cases return0; requested missing, malformed and out-of-domain data
  return1 with no Fortran runtime, SIGFPE or segmentation diagnostic.
- The existing release smoke suite still passes, with27 compared critical speeds
  per case and maximum reported difference0rpm.

Before-fix evidence includes TABLE `2 INVALID` and malformed BEARING scale
silently accepted with scale1; TABLE `2 NaN` returns136/SIGFPE; empty TABLE and
empty KIND return2 with EOF or substring-bound errors. The independent reviewer
also reproduced NaN-speed comparison and avoidable diagnostic-conversion traps.
These controls are preserved under `evidence/input_effective/` and the collected
input-review evidence. Historical ST41 validation remains blocked by the absent
archived decks and executables.

```sh
make -j4
FC=gfortran bash tests/st41/run_input_effective.sh bin/rotordin2 build/st41-input-effective/release
make MODE=debug -j4
FC=gfortran bash tests/st41/run_input_effective.sh bin/rotordin2-debug build/st41-input-effective/debug
```

### Additional native route controls

`tests/st41/run_input_routes.sh` adds16 complete synthetic controls per profile.
Both release/debug passed on integration93b09fb. TABLE-backed Campbell actually
queries coefficients between900 and2400rpm while reporting CPBSPD=5 as the
initial count and INTSPD=11 as the presentation count. Native export calls prove
NRAT1800, MDRPM1600 and Campbell-midpoint1650 precedence at the consumer, not
only in the summary. Two-point linear tables give an independent oracle for
all eight distinct K/C coefficients, including crossed terms and scale2;
native interpolation records and effective-input records both agree.

The existing extrapolation envelope accepts375 and5000rpm and rejects374.9
and5000.1rpm contextually, without substituted data. Extrapolation flags use
the actual logged speed. The nominal4000rpm endpoint becomes
4000.0000000000005rpm after the native conversion, so the existing strict
comparison marks it extrapolated; coefficients remain correct. No boundary
tolerance was introduced.

Physical FOUNDATION after SUPPORT succeeds through pipe and named file,
with/without the optional blank. Both interfaces and a following MESH_MODES=7
control survive. The four effective-input reports, model audits, printed
amplitudes/phases and33-line foundation response CSVs are byte-identical.
This stream comparison uses constant bearings and empty OPTIONS, preserving
the established stdin OPTIONS contract.

TABLE-backed physical `-t`, TIMSPD=0, actually evaluates the16-point UNB grid
from900 to2400rpm with HARMONIC_ORBIT context and no modal preparation.
These route tests are rerun in the final integrated qualification after P1;
the total Campbell query count may change because presentation speeds become
mandatory solve targets, while source/domain/coefficients remain checked.

```sh
bash tests/st41/run_input_routes.sh bin/rotordin2 build/st41-input-routes/release
bash tests/st41/run_input_routes.sh bin/rotordin2-debug build/st41-input-routes/debug
```

Use a fresh output directory for each invocation. Logs include exact commands,
input/binary/source hashes, return codes and per-lookup coefficient assertions.
