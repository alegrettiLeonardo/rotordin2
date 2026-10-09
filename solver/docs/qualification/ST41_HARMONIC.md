# RD2-03 / RD2-04 harmonic response qualification

## Authority and scope

Source import `d185aba585f094e7d633b013ab88fa12b9cba1b4` from the supplied
archive. No historical ST41 deck, evidence archive or original executable
was supplied. Every deck described below is a **native synthetic control**
derived from `tests/fixtures/simple2b-sp.txt`; it is not the archived ST41.

## Extraction gate: passed before changing `-t`

`rd_harmonic_response: harmonic_response_point` owns one augmented solve
with the original 1000 leading dimension and unchanged sequence:

`mntmth -> response_capture -> ZGETRF -> response_condition -> ZGETRS -> response_report`.

The force accumulation preserves KIND=0, degree/radian conversion and
native `Fx=-i U omega^2 exp(i phase)`, `Fz=U omega^2 exp(i phase)`.
The full augmented solution is returned. Foundation files remain in the
frequency-response caller. Neither inverse nor physical-order reduction
was added to the production solve.

The extraction-only source was compiled with the original release and debug
flags using GNU Fortran 13.3.0 and the bundled LAPACK/BLAS 3.12.1. Against
the separately built pristine binaries, both profiles passed:

| Check | Measured result |
|---|---|
| Speeds / response channels | 16 / 4 |
| Amplitude and phase report | byte-identical after removing two identity lines |
| Complete RESPONSE_H diagnostic rows | byte-identical |
| Release response text SHA-256 | `ebd2eaaf11662eb0c32bde1522bd7910afcf48f2949bdf22ac23ac92443bf507` |
| Maximum full augmented scaled residual, release | `6.4670839551137211e-20` |
| Maximum physical scaled residual, release | `1.4724524347487651e-17` |
| Maximum kinematic scaled defect, release | `3.3075894979664740e-10`, unchanged from baseline |

This intentionally retains the original fixture's highly scaled augmented
operator (`RCOND` about `1.08e-17`). Its kinematic defect is recorded rather
than silently treated as a stronger precision claim. The well-scaled oracle
and physical orbit qualification are separate gates below.

Reproduction (with explicit pristine binary paths):

```sh
make -j4
make MODE=debug -j4
bash tests/st41/run_harmonic_extraction.sh /path/to/pristine-release bin/rotordin2 evidence/harmonic/extraction-release
bash tests/st41/run_harmonic_extraction.sh /path/to/pristine-debug bin/rotordin2-debug evidence/harmonic/extraction-debug
```

The runner records binary/input SHA-256, commands, exit codes, stdout,
stderr and compared response/diagnostic data. It never changes historical
replay hashes. Source manifest and root-layout guards passed after review.

## Physical orbit gate

Passed in release and debug, after the extraction-only commit `70c2e33`.
The old synchronous modal projection, its second normalization, eigenvalue
transfer formula, and `-t`-only driver eigensolve have been removed. The
assembled physical dimension is authoritative. Other callers of modal
functions, including `espmod_sync`, were not changed.

The complete physical phasor is reconstructed with
`q(theta)=Re(qhat*exp(+i theta))`. In the native axes, the positive-frequency
force gives `Fx(theta)=U*omega^2*sin(theta+phase)` and
`Fz(theta)=U*omega^2*cos(theta+phase)`. The native FW check is positive for
`x=sin(theta), z=cos(theta)`. Tests check the signed orbit orientation
against the fitted phasor and the independently specified force convention.

`NBRMOD` remains a valid input field but is ignored by the physical orbit;
text and HPGL metadata now state this explicitly. `TANGLE` continues to
choose a geometric direction on the orbit and does not enter force phase.
The true transient integrator and the existing dynamic-foundation `-f`-only
restriction remain unchanged. `-t` does not open foundation response or
modal-participation files.

### Reproduced defect and measured correction

The same native synthetic deck at 1800 rpm was run through both the pristine
and corrected binaries. Fitting the 49 unique samples of its 50-point orbit
to a harmonic phasor gives:

| Comparison | Maximum absolute phasor mismatch |
|---|---:|
| Pristine `-t` against pristine `-f` | `4.2553667329316761e-6 m` (FAIL) |
| Corrected `-t` against corrected `-f`, same point | `2.2265497460415263e-16 m` (PASS) |
| All directed CLI comparisons, including 16-speed sweep | `1.3302451398114354e-15 m` (PASS) |
| `-t`, `-f -t`, `-m -t` equivalence at 1800 rpm | `0 m` between fitted output phasors |
| NBRMOD 10 / 19 and TANGLE 0 / 90 orbit equivalence | `0 m` between fitted output phasors |

The failed pristine comparison is preserved in
`evidence/harmonic/legacy-single/`; this is a formulation defect on the
synthetic control, not a claimed reproduction of the absent ST41 archive.

### Independent numerical oracle

`tests/st41/harmonic_oracle.f90` manually constructs physical `M`, `K`,
`C`, `G` and `Z=K-omega^2*M+i*omega*(C+omega*G)` from the specified test
coefficients. Its reference solve uses a separate pivoted Gaussian
elimination, not `mntmth`, `prpkc`, or LAPACK. This physical-order solve
exists **only in the test**. The production solver continues to factor the
original augmented matrix.

The 60 solves cover constant coefficients, actual TABLE row metadata and
interpolation, nonreciprocal crossed K/C, support masses, a physical
foundation, rotational DOFs, superposed unbalance, ignored KIND=1, common
phase 0/90/180/270 degrees, and a radian-input repeat. Both build profiles
produced:

| Metric | Maximum |
|---|---:|
| Relative phasor error against independent solver | `4.8646164126889649e-14` |
| Independently computed physical scaled residual | `1.6803238324986125e-16` |
| Kinematic scaled defect | `3.2517760535851563e-15` |

The oracle checks each physical DOF against `1e-12 + 1e-6*abs(q_ref)` and
requires both independent physical and kinematic residuals at most `1e-10`.
The meter/radian absolute floors are applied to their corresponding DOFs.
Common phase equivariance is also checked at `1e-11` relative in these
well-scaled controls.

### Executable CLI regression

`make test-st41-harmonic` and `make MODE=debug test-st41-harmonic` each pass
the independent oracle plus **19 native CLI runs**: four common phases,
standalone/combined analysis flags, NBRMOD, TANGLE, support response,
TIMSPD=0 sweep, complete shape, all three HPGL presentation paths, physical
foundation with `-f`, `-f -t`, and `-t`, and dynamic-foundation acceptance
with `-f` / expected rejection with `-t`.

Phasor comparison excludes the repeated last orbit point; it does not use
discrete maxima. The complete-shape check compares the two available shaft
probe pairs, while the sweep compares all 16 speed points. Raw RCOND, full
residual, physical residual and kinematic residual diagnostics are retained
for every solve. The deliberately highly scaled native beam control retains
its inherited small RCOND and kinematic defect documented above; the
physical-residual gate is satisfied independently.

The physical-foundation `foundation_response.csv` is byte-identical for
`-f` and `-f -t` in both profiles, with 33 lines (header plus 16 speeds and
2 interfaces), SHA-256
`5a06a34f58b5cbbd3211bbe2dc2e447d90ca9dad3e10fb2d22d9a5d2f086a186`.
Standalone `-t` creates neither that file nor `foundation_participation.out`.
The dynamic-foundation `-t` control exits 1 with the original contextual
`DYNAMIC_STIFFNESS_TABLE supports -f only` error and no timeresp block.

Reproduction and evidence locations:

```sh
make -j4 test-st41-harmonic
make MODE=debug -j4 test-st41-harmonic
```

Per-case input/binary hashes, exact command, return code, stdout, stderr,
and fitted-phasor comparisons are in
`build/{release,debug}/tests/st41/harmonic/`. Complete build logs are retained
under `evidence/harmonic/physical-{release,debug}-gate.log`.

The native cases establish this package's numerical behavior. The absent
archived ST41 decks/binary still block the named 1800-rpm ST41 amplitudes
and historical mesh-specific comparison. Geometry changes in later packages
must be qualified separately; do not rerun the extraction byte comparison
against a different mesh and interpret a legitimate assembly change as an
extraction failure.

## Final integrated measurement

The integrated source/test HEAD `3f3129f` passed the independent oracle and
19 CLI cases in each profile. The maximum displacement-phasor mismatch remains
`1.3302451398114354e-15 m`; the independent oracle maxima above remain unchanged.
Across the complete final CLI campaign, the largest kinematic scaled defect is
`3.9932303150253080e-10`, with minimum RCOND
`1.0811842476274138e-17`. All 206 CLI RESPONSE_H rows per profile retain
`ILL_CONDITIONED_H`. The extraction-only value `3.3075894979664740e-10` reported
earlier belongs to that narrower before/after gate, not to the maximum over all
final CLI variants. Neither value is presented as satisfying a universal
kinematic limit of 1e-10. No conditioning threshold was relaxed.

The largest production physical scaled residual over CLI plus oracle is
`1.9807584249625845e-16` in release and `1.9997506089776692e-16` in debug;
independent phasor and physical-residual gates pass. A small residual alone is
not a forward-accuracy certificate for the ill-conditioned beam cases.
See `docs/ST41_FIX_STATUS.md` for the integrated status, missing historical
fixtures, and the isolated legacy stderr anomaly with successful directed
rechecks. No further numerical campaign was run for this documentation update.
