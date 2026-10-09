# A07 evidence

Production variable-spin physics: **NOT_QUALIFIED**. Matrix derivation, isolated
kinematic numerical controls, constant-speed preservation and fail-closed behavior
are **PASS**, with scope in `../../A07_ANGULAR_ACCELERATION.md`.

Evidence was captured before the A07 commit, so `source_commit.txt` records the
imported base and `source_status.txt` its worktree delta. Exact scientific file
hashes are recorded in `status.json` and `inputs.sha256`; the postcommit campaign
reruns the same runners at its final source commit. No evidence is attributed to
unexecuted historical ST41 experimental fixtures.

The baseline control uses unmodified `transient_matrix.f90` from the baseline;
its expected failure applies only to the declared zero generalized tilt-work
Euler model. A physical inertial-axis drive can legitimately yield alpha G.

The actual-CLI comparison relinks the four original A07 algorithm files with all
other current objects to isolate A07 from A01/A02/A04/A05. Three old ramps complete;
the revised application rejects them before any matrix/state output. All three
constant-profile cases preserve the printed matrices/states exactly.

ROSS methods are the exact pinned source subset supplied in the common
`../../ross_reference` area of the qualification deliverable, with file hashes.
No full ROSS package execution or experimental machine qualification is claimed.

The two generated-executable permission failures and recovery are retained in
`infrastructure/`; neither was classified as a successful scientific execution.
