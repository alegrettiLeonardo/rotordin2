#!/usr/bin/env python3
"""A01 real executable qualification; reference uses NumPy/SciPy, never RotorDin LU."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

import numpy as np
from scipy.linalg import eigvals, solve


def read_output(path):
    lines = path.read_text().splitlines()
    rows = [line.split()[1:] for line in lines if line.startswith("MATRIX ")]
    n = max(int(row[0]) for row in rows)
    m = np.zeros((n, n))
    k, c = m.copy(), m.copy()
    for row in rows:
        i, j = map(int, row[:2])
        m[i - 1, j - 1], k[i - 1, j - 1], c[i - 1, j - 1] = map(float, row[2:])
    rows = [line.split()[1:] for line in lines if line.startswith("STATE ") and len(line.split()) == 10]
    data = np.array(rows, float)
    t = np.unique(data[:, 0])
    q = data[:, 6].reshape(len(t), n)
    v = data[:, 7].reshape(len(t), n)
    a = data[:, 8].reshape(len(t), n)
    ix = np.flatnonzero((abs(data[:n, 4] - 0.5) < 1e-10) & (data[:n, 5] == 1)).item()
    assert all(np.isfinite(x).all() for x in [m, k, c, q, v, a]), "nonfinite result"
    return lines, t, q, v, a, ix, m, k, c


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("binary", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    binary = args.binary.resolve()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[3]
    template = (root / "tests/reliability/a01_native.txt").read_text()
    template = template.replace("LATERAL_RESPONSE_MODE TRANSIENT", "LATERAL_RESPONSE_MODE AUTO")
    summary = {"binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(), "cases": []}
    omega, unbalance, global_phase = 1500 * np.pi / 30, 3e-5, 0.31
    for phase in [0, 90, 180, 270]:
        errors = []
        for dt in [0.0001, 0.00005]:
            work = out / f"constant_p{phase}_dt{dt:.5f}"
            work.mkdir(exist_ok=True)
            text = template.replace("3.0E-5    37        ", f"3.0E-5    {phase:<10}")
            text = text.replace("0 1 0.0001", f"0 1 {dt}").replace("OUTPUT_STRIDE 50", f"OUTPUT_STRIDE {round(0.005 / dt)}")
            (work / "input.txt").write_text(text)
            env = dict(os.environ, ROTORDIN_TRANSIENT_MATRIX_DUMP="1")
            command = [str(binary), "-std", "-t", "--transient"]
            (work / "command.json").write_text(json.dumps(command))
            with (work / "input.txt").open() as fi, (work / "stdout.out").open("w") as fo, (work / "stderr.out").open("w") as fe:
                result = subprocess.run(command, stdin=fi, stdout=fo, stderr=fe, cwd=work, env=env, timeout=90)
            (work / "returncode.txt").write_text(str(result.returncode) + "\n")
            assert result.returncode == 0, f"CLI failed: {work}"
            lines, t, q, v, a, ix, m, k, c = read_output(work / "stdout.out")
            assert "STATUS SUCCESS" in lines
            f = np.zeros(len(m), complex)
            f[ix : ix + 2] = unbalance * omega**2 * np.exp(1j * (phase * np.pi / 180 + global_phase)) * np.array([-1j, 1])
            exact = solve(k - omega**2 * m + 1j * omega * c, f)
            selector = t >= 0.6
            basis = np.column_stack([np.cos(omega * t[selector]), np.sin(omega * t[selector])])
            coefficients = np.linalg.lstsq(basis, q[selector], rcond=None)[0]
            fitted = coefficients[0] - 1j * coefficients[1]
            error = float(np.max(abs(fitted - exact)) / np.max(abs(exact)))
            assert error < 8e-5, f"complex phasor mismatch {error}"
            errors.append(error)
            # The legacy -t path outputs 50 samples including the repeated endpoint.
            start = next(i for i, line in enumerate(lines) if "x (m)             z (m)" in line) + 1
            xy = np.array([[float(x) for x in line.split()] for line in lines[start : start + 50]])
            angle = np.linspace(0, 2 * np.pi, 50)
            h = np.linalg.lstsq(np.column_stack([np.cos(angle), np.sin(angle)]), xy, rcond=None)[0]
            harmonic = (h[0] - 1j * h[1]) * np.exp(1j * global_phase)
            harmonic_error = float(max(abs(harmonic - exact[ix : ix + 2])) / max(abs(exact[ix : ix + 2])))
            assert harmonic_error < 1e-8
            # Initial acceleration is a second, independent force witness.
            force_error = float(max(abs(m @ a[0] + c @ v[0] + k @ q[0] - f.real)) / max(abs(f)))
            assert force_error < 1e-10
            orientation_exact = -np.imag(exact[ix] * exact[ix + 1].conjugate())
            orientation_time = -np.imag(fitted[ix] * fitted[ix + 1].conjugate())
            assert orientation_exact * orientation_time > 0
            state = np.block([[np.zeros_like(m), np.eye(len(m))], [-solve(m, k), -solve(m, c)]])
            max_real_pole = float(eigvals(state).real.max())
            assert max_real_pole < -15.0  # e^(-15*0.6) or faster before fitted interval.
            row = dict(phase_deg=phase, dt=dt, dofs=len(m), complex_error=error, harmonic_error=harmonic_error,
                       initial_force_error=force_error, max_real_pole=max_real_pole, result="PASS")
            summary["cases"].append(row)
            print(json.dumps(row), flush=True)
            (work / "comparison.json").write_text(json.dumps(row, indent=2) + "\n")
        assert 3.8 < errors[0] / errors[1] < 4.2, f"time-step convergence {errors}"
    summary["result"] = "PASS"
    (out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print("A01_NATIVE_CLI: PASS; 8 native executions, 4 phases, dt/2, complex phasors and whirl")


if __name__ == "__main__":
    main()
