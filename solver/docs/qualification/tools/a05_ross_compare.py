"""Compare native initial equilibrium with the exact pinned ROSS residual body.

The Numba/fastmath decorator is omitted deliberately; the original function
body is evaluated unchanged with NumPy. This is not a full ROSS transient run.
"""
import ast
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

reference, results, output = map(Path, sys.argv[1:4])
source = reference / "utils.py"
expected = "08708dc134682b40dcb8259527cdd9586e9f3eac26c0b510eda29355e05eb8d9"
report = {
    "id": "A05_ROSS_RESIDUAL",
    "ross_commit": "3a258dc84113425534e8ca0be5336b2ba4baa83a",
    "scope": "exact _residual_newmark function body, without Numba decorator",
    "full_ross_transient_execution": "NOT_QUALIFIED",
    "coordinate_map": "identical scalar torsional coordinates, q_ROSS = q_RotorDin (r=1)",
    "status": "BLOCKED",
}
if not source.is_file():
    report["reason"] = "Pinned ROSS utils.py required"
    output.write_text(json.dumps(report, indent=2) + "\n")
    sys.exit(2)
assert hashlib.sha256(source.read_bytes()).hexdigest() == expected, "pinned ROSS source hash mismatch"
tree = ast.parse(source.read_text())
node = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "_residual_newmark")
node.decorator_list = []
namespace = {}
exec(compile(ast.Module(body=[node], type_ignores=[]), str(source), "exec"), namespace)
residual = namespace["_residual_newmark"]
cases = []
for line in results.read_text().splitlines():
    if line.startswith("A05_SCALAR_INITIAL "):
        velocity, acceleration = map(float, line.split()[1:])
        value = residual(np.zeros(1), np.ones((1, 1)), 2 * np.ones((1, 1)), np.zeros((1, 1)),
                         np.zeros(1), np.array([velocity]), np.array([acceleration]))
        err = float(np.max(np.abs(value)))
        cases.append({"case": "scalar", "initial_velocity": velocity, "native_acceleration": acceleration,
                      "physical_residual": err, "status": "PASS" if err <= 1e-12 else "FAIL"})
    elif line.startswith("A05_COUPLED_ACCELERATION "):
        acceleration = np.array(list(map(float, line.split()[1:])))
        value = residual(np.array([1., 2.]), np.array([[2., .3], [.3, 1.]]),
                         np.array([[.7, -.2], [-.2, .4]]), np.array([[5., -2.], [-2., 3.]]),
                         np.array([.4, -.1]), np.array([.2, -.6]), acceleration)
        err = float(np.max(np.abs(value)))
        cases.append({"case": "coupled", "physical_residual": err, "status": "PASS" if err <= 1e-12 else "FAIL"})
assert len(cases) == 3, "native acceleration records missing"
report.update(status="PASS" if all(c["status"] == "PASS" for c in cases) else "FAIL",
              cases=cases, utils_sha256=expected, native_results_sha256=hashlib.sha256(results.read_bytes()).hexdigest())
output.write_text(json.dumps(report, indent=2) + "\n")
print("A05 pinned ROSS initial-equilibrium residual comparison:", report["status"], cases)
sys.exit(0 if report["status"] == "PASS" else 1)
