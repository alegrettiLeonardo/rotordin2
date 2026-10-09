#!/usr/bin/env python3
"""Execute unmodified pinned ROSS function ASTs and compare actual Fortran output.

Only method extraction is used, to avoid the unrelated GUI/plotting dependency
tree. This is a matrix/force-method comparison, not a full installed ROSS run.
"""
import argparse
import ast
from collections.abc import Iterable
import hashlib
import json
from pathlib import Path
import subprocess
from types import SimpleNamespace

import numpy as np
from scipy.integrate import cumulative_trapezoid


def extract(path, names, namespace):
    tree = ast.parse(path.read_text())
    found = [node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef) and node.name in names]
    assert {node.name for node in found} == set(names)
    for node in found:
        assert not node.decorator_list, "Pinned force methods must remain undecorated"
        exec(compile(ast.Module(body=[node], type_ignores=[]), str(path), "exec"), namespace)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("fortran", type=Path)
    p.add_argument("output", type=Path)
    args = p.parse_args()
    root = Path(__file__).resolve().parents[3]
    refs = root / "docs/qualification/ross_reference"
    metadata = json.loads((refs / "provenance.json").read_text())
    assert metadata["commit"] == "3a258dc84113425534e8ca0be5336b2ba4baa83a"
    for name in ["rotor_assembly.py", "utils.py"]:
        assert hashlib.sha256((refs / name).read_bytes()).hexdigest() == metadata["files"][name]["sha256"]
    ns = dict(np=np, Iterable=Iterable, integrate=cumulative_trapezoid)
    extract(refs / "utils.py", ["make_speed_array"], ns)
    extract(refs / "rotor_assembly.py", ["_unbalance_force", "unbalance_force_over_time"], ns)
    rotor = SimpleNamespace(ndof=6, number_dof=6)
    # ROSS X_R=Z_native, Y_R=X_native. Virtual work gives the same swap for forces.
    permutation = np.array([[0.0, 1.0], [1.0, 0.0]])
    output = dict(commit=metadata["commit"], comparison="unmodified ROSS methods via AST", cases=[])
    for alpha in [-23.0, 0.0, 23.0]:
        for omega0 in [0.0, 73.0]:
            for delta in [0.0, np.pi / 2, np.pi, 3 * np.pi / 2, 0.371]:
                t = np.linspace(0, 0.1, 101)
                omega = omega0 + alpha * t
                phase = omega0 * t + 0.5 * alpha * t**2
                rows = "".join(f"{ti:.17g} {oi:.17g} {alpha:.17g} {pi:.17g} {delta:.17g}\n" for ti, oi, pi in zip(t, omega, phase))
                result = subprocess.run([str(args.fortran.resolve())], input=rows, text=True, capture_output=True, check=True)
                native = np.array([[float(v) for v in line.split()] for line in result.stdout.splitlines()]).T
                ross = ns["unbalance_force_over_time"](rotor, [0], [0.003], [delta], omega, t)
                expected = permutation @ ross[:2]
                scale = max(np.max(abs(expected)), 1e-12)
                error = float(np.max(abs(native - expected)) / scale)
                assert error < 2e-11, (alpha, omega0, delta, error)
                if alpha == 0 and omega0 != 0:
                    harmonic = ns["_unbalance_force"](rotor, 0, 0.003, delta, [omega0])[:2, 0]
                    temporal = np.real((permutation @ harmonic)[:, None] * np.exp(1j * omega0 * t))
                    assert np.max(abs(native - temporal)) / scale < 1e-12
                output["cases"].append(dict(alpha=alpha, omega0=omega0, delta=delta, error=error, result="PASS"))
    output["max_relative_error"] = max(row["error"] for row in output["cases"])
    output["result"] = "PASS"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2) + "\n")
    print(f"A01_ROSS_METHODS: PASS; {len(output['cases'])} profiles; max error={output['max_relative_error']:.8e}")


if __name__ == "__main__":
    main()
