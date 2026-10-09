# ST41 scoped qualification: messages and AF

## Authority and environment

Source baseline: imported archive commit
`d185aba585f094e7d633b013ab88fa12b9cba1b4`; working package starts at
`a867b41`. The upload has no original Git history or supplied executable.
The separately preserved baseline binaries were built from the intact import.
GNU Fortran 13.3.0, the existing release/debug Makefile flags, and the bundled
LAPACK/BLAS 3.12.1 backend were used. The manifest gate remains enabled.

The two ST41 evidence archives and their amplitude samples were not supplied.
Historical ST41-specific numerical replay is therefore **blocked by missing
fixtures**. Tests here identify their synthetic or generic provenance explicitly.

## RD2-11 — qualified on executable controls

`fmtmsgf` now composes its fixed-capacity message with truncating CHARACTER
assignment. Optional text cannot overrun the remaining internal record.
`fopmsf` uses the same safe operation for its 65-character error/context field.
`fhmsgf` no longer slices beyond its 99-character intermediate when a larger
result is requested. Existing function signatures, capacities, normal short
messages, error ordering, and the controlled stop remain unchanged.

Native regression commands (set `FC` to the available GNU Fortran if needed):

```sh
bash tests/st41/run_messages.sh
bash tests/st41/run_messages_invalid.sh bin/rotordin2 build/st41-messages/solver-current-release
bash tests/st41/run_messages_invalid.sh bin/rotordin2-debug build/st41-messages/solver-current-debug
bash tests/st41/run_messages_invalid.sh /path/to/rotordin2-baseline build/st41-messages/solver-baseline-release baseline
bash tests/st41/run_messages_invalid.sh /path/to/rotordin2-debug-baseline build/st41-messages/solver-baseline-debug baseline
make test
make MODE=debug test
```

`run_messages.sh` extracts the original routines with `git show` using
`ST41_BASE_REF` (default is the imported baseline above), compiles both versions
in release/debug, records source/binary hashes and compiler commands, and keeps
the original overrun reproduction. The harness uses section garbage collection
to link only the tested native functions; the complete solver uses its original
Makefile and complete local backend.

| Control | Original | Corrected |
|---|---|---|
| Six ordinary short/blank messages | PASS, both modes | PASS, both modes |
| Long optional path/text | `End of record`, both modes | PASS |
| Long section context | `End of record`, both modes | PASS |
| All blank, zero/one/limited result sizes, long module/message, wrappers and extended help result | Not all safe originally | 22 assertions PASS per mode |
| Deliberately invalid section count, short `./bad.txt` path | Origin `entrada->error reading(section)`, rc=1 | Same origin, rc=1 |
| Same invalid deck, 153-character relative path | `End of record`, rc=2 | Same origin as short path, rc=1; no runtime error |
| Existing LAPACK smoke | Root preserves intact run | 16 checks PASS in each mode |
| Existing Campbell and modal STDIO controls | Root preserves intact run | 27 values per run, maximum difference 0 rpm in each mode |
| Complete local link audit | Preserved | 286 local objects, PASS in each mode |

The invalid fixture contains `INVALID` in the numeric section-count field.
It remains a negative test even after SUPPORT/parser improvements. Both short
and long runs read identical fixture bytes. Full solver logs are under
`build/st41-messages/solver-*`; compile, native test, old failures, hashes and
Makefile regression logs are under `build/st41-messages/`.

## RD2-07

**Qualified with native synthetic controls; historical ST41 replay blocked.**

The physical AF path calls `getbds_checked`, which returns the crossing and a
separate logical success flag. This routine processes the first and last
interval before deciding that a flank is unavailable, accepts equality at the
target, and stops at a reversed or flat flank above the target. A measured
crossing at zero rpm is retained. The external `getbds`, `linintx`, `fatamof`
and `maxamp` signatures remain available; the old scalar compatibility wrappers
are not used to decide success in the AF path.

The curve must have finite, representable complex magnitudes and strictly
increasing finite speeds. Interpolation checks its bracket, equal endpoints,
and denominator. Invalid input produces unavailable AF (`F`, -1) and a
contextual `maxamp->invalid data` error through the solver entry point.
One/two valid samples still yield zero detected peaks without an error.
Only slope signs were used by `maxamp`; on a validated increasing grid these
are now obtained from amplitude differences, avoiding a needless division.

Half power is evaluated as `Amax/sqrt(2)`; the old `0.70710678` literal was an
eight-digit approximation of the same definition. The AF numerator remains
the **sampled** peak speed. The separate parabola fit and all input complex
amplitudes remain unchanged. The original state codes are retained:

| Code | Meaning |
|---|---|
| `n` | Both half-power crossings measured |
| `i` | Lower/initial flank unavailable and mirrored from the upper flank |
| `f` | Upper/final flank unavailable and mirrored from the lower flank |
| `F` | AF unavailable; value -1 |

Reproduction:

```sh
bash tests/st41/run_af.sh
```

The script runs the existing Makefile in both modes and links the test drivers
against the actual production objects, including `quad`/`qcfr`/`mxqr` and the
bundled backend. The old-code control replaces only `rdfra.o` with a compilation
of the original source extracted through `git show`. No numerical stubs or
alternative math backend are used. Compiler commands, Makefile configuration,
source/binary hashes, inputs and return codes are retained under
`build/st41-af/`.

| Native control | Original | Corrected |
|---|---|---|
| Five samples, both crossings in first/last intervals | AF=-1, `F`; required measured-status assertion fails | AF=0.77777777777777779, `n`; 6 assertions PASS |
| Exact 0-rpm lower endpoint, upper crossing 3500 rpm, sampled peak 2000 rpm | Zero used as failure sentinel | AF=4/7, `n`; explicit `found=true` at zero |
| Interior lower/upper crossings 225/540 rpm, sampled peak 400 rpm | 1.2698412654443101, `n` | 1.2698412698412698, `n`; exact half-power oracle 400/315 |
| Parabolic fitted speed/amplitude for the interior case | 376.65880747881164 rpm / 1.4258841586336897 | Output byte-identical; fitted speed is not used as the AF numerator |
| Original measured / both mirrored variants / unavailable states | 13 assertions PASS | 13 assertions PASS |
| Boundary equality, explicit success, reversal, plateau, invalid target/index/count, duplicate/unordered speeds, NaN/Inf and overflowing complex magnitude | Unsafe or unavailable behavior in affected paths | 45 assertions PASS without runtime exceptions, including debug traps |
| Full matrix of executable controls | Old edge defect reproduced in both modes | 64 assertions PASS per mode; input amplitudes unchanged |

The interior AF shift of approximately 4.397e-9 comes from replacing the rounded
half-power constant by `1/sqrt(2)`, not from changing peak sampling or amplitude
data. The old-code preservation control permits that historical rounding only;
the corrected edge and checked controls use tolerances at approximately 1e-12.

The requested ST41 crop (39 points, 1192.0184–1428.9256 rpm, expected AF
approximately 5.75149854) cannot be asserted without its actual complex
amplitude samples. No synthetic curve is presented as that archived ST41 run.
