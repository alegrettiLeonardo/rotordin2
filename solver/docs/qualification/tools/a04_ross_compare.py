"""Evaluate the exact pinned ROSS C method and compare native torsion blocks.

This isolates the unmodified numerical method using AST, not a reimplementation
of its formula. It does not instantiate the complete ROSS Rotor runtime.
"""
import ast
import hashlib
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import numpy as np

refdir, results, output = map(Path, sys.argv[1:4])
coupling = refdir / "coupling_element.py"
shaft = refdir / "shaft_element.py"
expected = "c321ef3b45b8b34478af57092cf7f3f8640bb350de0486ef1a3ccaf97c3be49d"
report = {
    "id": "A04_ROSS_MATRIX",
    "ross_commit": "3a258dc84113425534e8ca0be5336b2ba4baa83a",
    "scope": "exact pinned CouplingElement.C method; torsional submatrix and coordinate congruence",
    "full_ross_rotor_execution": "NOT_QUALIFIED",
    "status": "BLOCKED",
}
if not coupling.is_file() or not shaft.is_file():
    report["reason"] = "Pinned ROSS coupling and shaft source files required"
    output.write_text(json.dumps(report, indent=2) + "\n")
    sys.exit(2)
assert hashlib.sha256(coupling.read_bytes()).hexdigest() == expected, "pinned source hash mismatch"


def exact_method(path, class_name, method_name):
    tree = ast.parse(path.read_text())
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == class_name)
    method = next(n for n in cls.body if isinstance(n, ast.FunctionDef) and n.name == method_name)
    assert not method.decorator_list
    module = ast.Module(body=[method], type_ignores=[])
    namespace = {"np": np}
    exec(compile(module, str(path), "exec"), namespace)
    return namespace[method_name]


mapping = exact_method(shaft, "ShaftElement", "dof_mapping")(object())
assert mapping["theta_0"] == 5 and mapping["theta_1"] == 11
parameters = SimpleNamespace(ct_x=0.0, ct_y=0.0, ct_z=0.0, cr_x=0.0, cr_y=0.0, cr_z=4.0)
physical = exact_method(coupling, "CouplingElement", "C")(parameters)[np.ix_([5, 11], [5, 11])]
cases = []
for line in results.read_text().splitlines():
    if not line.startswith("A04_ROSS_C "):
        continue
    ratio, *values = map(float, line.split()[1:])
    native = np.array(values).reshape(2, 2)
    # Both endpoints use the same signed physical-to-referred mapping.
    transform = ratio * np.eye(2)
    transformed = transform.T @ physical @ transform
    error = float(np.max(np.abs(native - transformed)))
    cases.append({"signed_ratio": ratio, "max_absolute_error": error, "status": "PASS" if error <= 1e-12 else "FAIL"})
assert len(cases) == 3, "missing native signed-ratio matrix records"
report.update(
    status="PASS" if all(c["status"] == "PASS" for c in cases) else "FAIL",
    cases=cases,
    torsional_dofs_zero_based=[5, 11],
    mapping="theta_ROSS = r * q_RotorDin for each element endpoint",
    coupling_sha256=expected,
    shaft_sha256=hashlib.sha256(shaft.read_bytes()).hexdigest(),
    native_results_sha256=hashlib.sha256(results.read_bytes()).hexdigest(),
)
output.write_text(json.dumps(report, indent=2) + "\n")
print("A04 pinned ROSS torsional C comparison:", report["status"], cases)
sys.exit(0 if report["status"] == "PASS" else 1)
