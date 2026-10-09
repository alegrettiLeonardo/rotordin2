# Preserved infrastructure attempts

Two final `make MODE=debug FC=... test` attempts returned rc=2 because the
generated `build/debug/tests/linalg_smoke` had mode 0644 and failed to execute:
`Permission denied` (shell rc126). Both complete short failure logs are retained.

The source and numerical tolerances were not changed to repair this condition.
The first recovery attempted `chmod u+x`; a later attempt again observed 0644.
The final recovery used `chmod 755 build/debug/tests/linalg_smoke`; direct
execution passed all 16 linalg controls and a serial complete Debug `make test`
then passed. Observed final mode was 0755. The cause of the mode reset has not
been established. No hardlinks, symlinks, cp-al or object reuse from other agents
were used in this worktree.

Final scientific and CLI results are in the adjacent release/debug directories.
The consolidated campaign builds clean artifacts serially at the final commit.
