#!/usr/bin/env python3
"""Execute the pinned ROSS M/K methods and compare its torsion DOFs [5,11].

AST isolates the unchanged official methods from optional GUI/unit dependencies;
the complete ROSS package is not imported or qualified. Source SHA-256 is locked.
"""
import ast
import cmath
import hashlib
import math
import os
from pathlib import Path
import sys
from types import SimpleNamespace
import numpy as np

source = Path(os.environ.get("A02_ROSS_REF", "docs/qualification/ross_reference/shaft_element.py"))
expected_sha = "46d6bdf328dad4958a3b3398c28c8424c6057775ff461a646627339104cb89f6"
data = source.read_bytes()
assert hashlib.sha256(data).hexdigest() == expected_sha, "Pinned ROSS source differs"
assert hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest() == \
    "df74525956dc3b27d1cb675e0997146b4a835af3", "Pinned Git blob differs"
module = ast.parse(source.read_text())
cls = next(x for x in module.body if isinstance(x, ast.ClassDef) and x.name == "ShaftElement")
methods = [x for x in cls.body if isinstance(x, ast.FunctionDef) and x.name in {"M", "K", "dof_mapping"}]
assert {x.name for x in methods} == {"M", "K", "dof_mapping"}
namespace = {"np": np}
exec(compile(ast.Module(body=methods, type_ignores=[]), str(source), "exec"), namespace)
jp=1e-6;radius=(2*jp/math.pi)**.25;area=math.pi*radius**2
obj=SimpleNamespace(L=1.,Ie=jp/2,Ie_l=jp/2,Ie_r=jp/2,A=area,A_l=area,A_r=area,
    material=SimpleNamespace(rho=.1/jp,G_s=1e11,E=2.6e11),phi=0.,a1=0.,a2=0.,b1=0.,b2=0.,
    delta=0.,gama=0.,rotary_inertia=True,axial_force=0.,torque=0.)
mapping=namespace["dof_mapping"](obj)
assert [mapping["theta_0"],mapping["theta_1"]] == [5,11]
# Proper rotation of frames: x_R=x_N, y_R=-z_N, z_R=y_N; det(R)=+1.
# Thus ROSS theta_z equals native theta_y; the 2 scalar torsion DOFs have no sign flip.
idx=np.array([5,11]);mross=namespace["M"](obj)[np.ix_(idx,idx)];kross=namespace["K"](obj)[np.ix_(idx,idx)]
np.testing.assert_allclose(mross,.1/6*np.array([[2,1],[1,2]]),rtol=2e-15,atol=0)
np.testing.assert_allclose(kross,1e5*np.array([[1,-1],[-1,1]]),rtol=2e-15,atol=0)
checks=2;max_torque_error=0.
for path in sorted((Path(sys.argv[1])/"current").glob("frequency-r*-p*.log")):
    lines=path.read_text().splitlines()
    ratio=float(next(x.split("=",1)[1] for x in lines if x.startswith("NATIVE_RATIO=")))
    phase_deg=float(path.stem.rsplit("-p",1)[1]);phase=.371
    matrix=lambda name: np.array([float(x) for x in next(l for l in lines if l.startswith(name+" ")).split()[1:]]).reshape(2,2)
    np.testing.assert_allclose(matrix("NATIVE_J"),ratio**2*mross,rtol=2e-14,atol=1e-15)
    np.testing.assert_allclose(matrix("NATIVE_K"),ratio**2*kross,rtol=2e-14,atol=1e-10)
    force=100*np.exp(1j*np.array([phase,phase+math.radians(phase_deg)]))
    for line in lines:
        if not line.startswith("NATIVE_PHASOR "): continue
        raw=[float(x) for x in line.split()[1:]];omega=raw[0]
        phi=np.linalg.solve(kross-omega**2*mross,force)
        torque=(kross@phi)[1]
        native_torque=complex(raw[5],raw[6])
        # Free rigid mode makes D ill-conditioned; this bound is below 1e-9 relative
        # to the 100 Nm excitation, and agrees with a binary64 condition estimate.
        assert abs(native_torque-torque)<1e-7, (path,omega,native_torque,torque)
        np.testing.assert_allclose(complex(raw[1],raw[2]),phi[1],rtol=2e-10,atol=1e-12)
        max_torque_error=max(max_torque_error,abs(native_torque-torque));checks+=2
    checks+=2
print("ROSS_PIN 3a258dc84113425534e8ca0be5336b2ba4baa83a")
print("ROSS_SOURCE_SHA256 "+expected_sha)
print("ROSS_SCOPE actual AST-isolated ShaftElement.M/K, torsion DOFs 5/11; full package NOT_QUALIFIED")
print("ROSS_FRAME_MAP x_R=x_N,y_R=-z_N,z_R=y_N; axial torsion sign preserved")
print(f"A02_ROSS_TORSION_ASSERTIONS PASS {checks}")
print(f"A02_ROSS_NATIVE_MAX_COMPLEX_TORQUE_ERROR_NM {max_torque_error:.12g}")
