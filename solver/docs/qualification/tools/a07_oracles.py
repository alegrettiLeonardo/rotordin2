"""Independent A07 energy/shape-function/ODE and pinned-ROSS comparisons.

The full ROSS package is not imported. Exactly the unmodified pinned methods
specified below are executed with explicit element attributes; their file hashes
are verified first. A detected non-equivalence is recorded, never forced to PASS.
"""
import argparse
import ast
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
from types import SimpleNamespace

import numpy as np
from numpy.polynomial.polynomial import polymul
from scipy.integrate import solve_ivp, cumulative_trapezoid
from scipy.optimize import linear_sum_assignment

PIN = "3a258dc84113425534e8ca0be5336b2ba4baa83a"


def methods(path, cls, names):
    tree = ast.parse(path.read_text())
    node = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == cls)
    ns = {"np": np}
    for name in names:
        fun = next(n for n in node.body if isinstance(n, ast.FunctionDef) and n.name == name)
        assert not fun.decorator_list
        exec(compile(ast.Module(body=[fun], type_ignores=[]), str(path), "exec"), ns)
    return ns


def analytical_b(length, phi, density, inertia, gf):
    """Solve independent cubic displacement/static-shear boundary equations.

    u=a0+a1*xi+a2*xi^2+a3*xi^3; rotation=(du/dxi+Phi*a3/2)/L.
    Integrate resulting polynomials algebraically, without Gauss points or G.
    """
    bc = np.array([[1., 0, 0, 0], [1., 1, 1, 1],
                   [0., 1, 0, phi / 2], [0., 1, 2, 3 + phi / 2]])
    rhs = np.array([[1., 0, 0, 0], [0., 0, 1, 0],
                    [0., length, 0, 0], [0., 0, 0, length]])
    a = np.linalg.solve(bc, rhs)
    rot = np.array([a[1] + phi*a[3]/2, 2*a[2], 3*a[3]])/length
    nx = np.zeros((3, 8)); nz = np.zeros((3, 8))
    nx[:, [1, 2, 5, 6]] = rot
    nz[:, [0, 3, 4, 7]] = rot * [-1, 1, -1, 1]
    b = np.empty((8, 8))
    for i in range(8):
        for j in range(8):
            poly = polymul(nz[:, i], nx[:, j])
            b[i, j] = 2*density*inertia*gf*length*sum(poly/(np.arange(len(poly))+1))
    return b


def derive_drive_models():
    # Exact axisymmetric disk energy before the small-tilt approximation,
    # Lalanne Eq.(1.3): the spin component is Omega+psi_dot*sin(theta).
    ident, ip = .7, 1.3
    th0, ps0, vt0, vp0, at0, ap0 = .3, -.4, .2, -.1, -.7, .8
    cases = []
    for om in [-2., 0., 3.]:
        for al in [-1.5, 0., 1.7]:
            expected = np.array([ident*at0-ip*om*vp0, ident*ap0+ip*om*vt0+ip*al*th0])
            linear_follower = expected-[0, ip*al*th0]
            linear_fixed = expected-[ip*al*ps0, 0]
            errors = []
            for eps in [1e-2, 1e-3, 1e-4]:
                th, ps, vt, vp, at, ap = eps*np.array([th0, ps0, vt0, vp0, at0, ap0])
                st, ct = np.sin(th), np.cos(th)
                # Exact Euler-Lagrange derivatives of the displayed 3-D
                # energy; no element G or B is used in these expressions.
                exact = np.array([
                    ident*at+ident*vp**2*ct*st-ip*(om+vp*st)*vp*ct,
                    ident*ap*ct**2-2*ident*vp*st*ct*vt
                    + ip*(al+ap*st+vp*ct*vt)*st+ip*(om+vp*st)*ct*vt])
                theta_axis = np.array([np.cos(ps), np.sin(ps), 0.])
                psi_axis = np.array([0., 0., 1.])
                spin_axis = np.array([-np.sin(ps)*ct, np.cos(ps)*ct, st])
                follower = ip*al*spin_axis
                fixed = np.array([0., ip*al, 0.])
                q_follower = np.array([follower @ theta_axis, follower @ psi_axis])
                q_fixed = np.array([fixed @ theta_axis, fixed @ psi_axis])
                error = float(max(np.max(abs(exact/eps-expected)),
                                  np.max(abs((exact-q_follower)/eps-linear_follower)),
                                  np.max(abs((exact-q_fixed)/eps-linear_fixed))))
                errors.append(error)
            assert errors[-1] < 2e-8
            assert errors[0]/errors[1] > 95 and errors[1]/errors[2] > 95
            cases.append(dict(omega=om, alpha=al, linearization_errors=errors, result="PASS"))
    return {
        "exact_disk_energy_small_angle_convergence": "PASS",
        "virtual_work_follower_and_inertial_torque": "PASS",
        "cases": cases,
        "zero_generalized_tilt_drive_Kalpha_over_Ip": [[0, 0], [1, 0]],
        "follower_drive_Kalpha_over_Ip": [[0, 0], [0, 0]],
        "inertial_axis_drive_Kalpha_over_Ip": [[0, -1], [1, 0]],
        "production_drive_identification": "NOT_QUALIFIED",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("native", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.native = args.native.resolve(); args.output.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[3]
    ref = Path(os.environ.get("A07_ROSS_REF", root/"docs/qualification/ross_reference"))
    metadata = json.loads((ref/"provenance.json").read_text())
    assert metadata["commit"] == PIN
    for filename in ["disk_element.py", "shaft_element.py", "rotor_assembly.py"]:
        assert hashlib.sha256((ref/filename).read_bytes()).hexdigest() == metadata["files"][filename]["sha256"]
    disk = methods(ref/"disk_element.py", "DiskElement", ["G", "Kdt"])
    shaft = methods(ref/"shaft_element.py", "ShaftElement", ["G", "Kst"])
    rotor = methods(ref/"rotor_assembly.py", "Rotor", ["Ksdt"])
    result = {"ross_commit": PIN, "comparison_scope": "unmodified pinned methods via AST; no full ROSS installation",
              "drive_derivation": derive_drive_models(), "shaft_cases": [], "poles": [], "ramps": []}
    raw = subprocess.check_output([str(args.native)], text=True)
    (args.output/"native-matrices.txt").write_text(raw)
    lines = raw.splitlines(); cursor = 0
    # Proper cyclic 3-D mapping: (X_R,Y_R,Z_R)=(Z_N,X_N,Y_N).
    # ROSS node [x,y,z,alpha,beta,theta]; native [x,z,theta_x,theta_z].
    p = np.zeros((6, 4)); p[0, 1] = p[1, 0] = p[3, 3] = p[4, 2] = 1
    pe = np.zeros((12, 8)); pe[:6, :4] = p; pe[6:, 4:] = p
    for cursor, line in enumerate(lines):
        if line.startswith("SHAFT "):
            fields = line.split(); ic = int(fields[1])
            length, outer, inner, young, shear, density, gf, phi = map(float, fields[2:])
            b = np.array([[float(x) for x in lines[cursor+j].split()] for j in range(2, 10)])
            g = np.array([[float(x) for x in lines[cursor+j].split()] for j in range(11, 19)])
            inertia = np.pi*(outer**4-inner**4)/64
            analytic = analytical_b(length, phi, density, inertia, gf)
            b_error = float(np.max(abs(b-analytic))/max(1, np.max(abs(b))))
            assert b_error < 2e-13
            element = SimpleNamespace(L=length, phi=phi, a2=0., b2=0., gama=0., delta=0.,
                                      gyroscopic=True, material=SimpleNamespace(rho=density),
                                      Ie_l=inertia, Ie_r=inertia)
            gr = pe.T @ shaft["G"](element) @ pe * gf
            kr = pe.T @ shaft["Kst"](element) @ pe * gf
            gr_error = float(np.max(abs(gr-g))/max(1, np.max(abs(g))))
            assert gr_error < 2e-13
            eb = analytical_b(length, 0., density, inertia, gf)
            eb_transpose_error = float(np.max(abs(kr-eb.T))/max(1, np.max(abs(eb))))
            assert eb_transpose_error < 2e-13
            shear_gap = float(np.max(abs(b-eb))/max(1e-300, np.max(abs(b)))) if gf else 0.
            result["shaft_cases"].append(dict(case=ic, phi=phi, analytical_B_error=b_error,
                                             transformed_ROSS_G_error=gr_error,
                                             ROSS_Kst_equals_EB_B_transpose_error=eb_transpose_error,
                                             shear_effect_relative_gap=shear_gap,
                                             canonical_B_comparison="PASS", gyro_comparison="PASS",
                                             full_ROSS_Kalpha_equivalence="NOT_QUALIFIED"))
        elif line.startswith("POLES"):
            om, al = map(float, line.split()[1:])
            native = np.array([complex(*map(float, lines[cursor+j].split())) for j in range(1, 5)])
            # Scalar determinant, independently expanded; Id=1, Ip=1.6,
            # spring stiffnesses 9 and 25. Nonconstant-spin roots are frozen
            # instantaneous roots, not LTI stability classifications.
            expected = np.roots([1, 0, 34+(1.6*om)**2, 1.6**2*om*al, 225])
            rr, cc = linear_sum_assignment(abs(native[:, None]-expected[None, :]))
            error = float(max(abs(native[rr]-expected[cc])))
            assert error < 2e-12
            if al == 0: assert max(abs(native.real)) < 2e-12
            result["poles"].append(dict(omega=om, alpha=al, error=error, result="PASS"))
    assert len(result["shaft_cases"]) == 5 and len(result["poles"]) == 9
    obj = SimpleNamespace(Ip=1.6)
    gd = p.T @ disk["G"](obj) @ p
    kd = p.T @ disk["Kdt"](obj) @ p
    bn = np.zeros((4, 4)); bn[3, 2] = obj.Ip
    assert np.max(abs(gd-(bn-bn.T))) < 1e-15
    assert np.max(abs(kd-kd.T+gd)) < 1e-15
    assert np.max(abs(kd-bn)) == obj.Ip
    assert np.max(abs(rotor["Ksdt"](SimpleNamespace(Ksdt0=kd))-kd)) == 0
    result["ross_disk"] = {"gyro_transformation": "PASS", "skew_Kdt_equals_minus_G": "PASS",
                           "canonical_Kalpha_vs_ROSS_max_difference": float(np.max(abs(kd-bn))),
                           "physical_equivalence": "NOT_QUALIFIED",
                           "Rotor_Ksdt_copy_behavior": "PASS"}
    # Numerical kernel run-up/rundown under the explicitly declared Euler
    # drive model. Independent reduction uses conserved p_psi, eliminating
    # the second second-order equation instead of integrating native matrices.
    ip = 1.6; th0, ps0, vt0, vp0 = .001, -.002, .0003, .0004
    for om0, al in [(0., 0.), (2., 0.), (0., 1.), (3., -1.), (-1., 1.), (1., -1.)]:
        momentum = vp0+ip*om0*th0
        def reduced(t, z):
            om = om0+al*t
            return [z[1], ip*om*(momentum-ip*om*z[0]), momentum-ip*om*z[0]]
        oracle = solve_ivp(reduced, [0., 2.], [th0, vt0, ps0], method="DOP853",
                           rtol=1e-12, atol=1e-15, dense_output=True)
        assert oracle.success
        errors = []
        for dt in [.001, .0005]:
            text = subprocess.check_output([str(args.native), "integrate", str(om0), str(al), str(dt)], text=True)
            arr = np.loadtxt(io.StringIO(text)); assert np.all(np.isfinite(arr))
            t, th, ps, vt, vp, at, ap = arr.T
            rz = oracle.sol(t); expected = np.c_[rz[0], rz[2], rz[1], momentum-ip*(om0+al*t)*rz[0]]
            error = float(np.max(abs(arr[:, 1:5]-expected))); errors.append(error)
            assert error < 3e-8
            drift = float(np.max(abs(vp+ip*(om0+al*t)*th-momentum)))
            assert drift < 1e-8
            energy = (vt**2+vp**2)/2
            work = cumulative_trapezoid(-al*ip*th*vp, t, initial=0.)
            energy_error = float(np.max(abs(energy-energy[0]-work)))
            assert energy_error < 2e-11
            # Full-energy / actuator-work identity after subtracting the exact
            # 0.5*Ip*Omega^2 spin baseline to avoid loss of significance.
            edot = vt*at+vp*ap
            crossdot = ip*(al*th*vp+(om0+al*t)*(vt*vp+th*ap))
            drive_increment_power = ip*(om0+al*t)*(vt*vp+th*ap)
            power_error = float(np.max(abs(edot+crossdot-drive_increment_power)))
            assert power_error < 1e-10
            result["ramps"].append(dict(omega0=om0, alpha=al, dt=dt, state_error=error,
                                        conserved_momentum_drift=drift, energy_work_error=energy_error,
                                        full_actuator_work_error=power_error,
                                        declared_Euler_kernel="PASS", production_ramp="NOT_QUALIFIED" if al else "PASS"))
        if errors[0] > 1e-11:
            assert errors[0]/errors[1] > 3.5
    result["canonical_kernel_numerical_qualification"] = "PASS"
    result["A07_production_variable_spin"] = "NOT_QUALIFIED"
    (args.output/"oracles.json").write_text(json.dumps(result, indent=2)+"\n")
    print("A07 independent oracles: PASS (5 shafts, 9 frozen pole sets, 12 declared-drive integrations)")
    print("A07 production variable-spin: NOT_QUALIFIED (drive tilt-work contract unspecified)")
    print("ROSS acceleration-matrix physical equivalence: NOT_QUALIFIED; measured discrepancy retained")


if __name__ == "__main__":
    main()
