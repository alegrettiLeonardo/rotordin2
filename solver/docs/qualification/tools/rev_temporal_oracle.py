"""Independent physical/coverage oracles for real tnuinteg output.

No production Newmark/Wilson formula is copied here. References are exact
polynomials, augmented matrix exponentials, and DOP853 for a declared natural
cubic forcing spline. CubicHermiteSpline is used only to assess dense-output
kinematics/work, not as the physical state oracle.
"""
import argparse
import copy
from decimal import Decimal, ROUND_CEILING
import json
import re
from pathlib import Path
import subprocess
import sys

import numpy as np
from scipy.integrate import solve_ivp
from scipy.interpolate import CubicHermiteSpline, CubicSpline
from scipy.linalg import expm, solve

EPS = np.finfo(float).eps
MARKER = -7.654321987654321e190
FLOOR = 1e-11


def fixture(name, model="free", t0=0., duration=.016, h=.001, hs=None, linear=False, zero=False,
            table_start=None, method=0, gate="REV02", **extra):
    tf = float(Decimal(str(t0)) + Decimal(str(duration)))
    if model == "coupled":
        m = np.array([[2., 1.], [1., 2.]]) / 3.
        c = .4*np.array([[1., -1.], [-1., 1.]])
        k = 3.*np.array([[1., -1.], [-1., 1.]])
        aa = np.array([1., -1.]); bb = np.array([.7, -.7]) if linear else np.zeros(2)
        rind = [1, 2]; effort = 1
    elif model == "multi":
        m = np.diag([2., 3., 5.]); c = np.diag([.4, .7, 0.]); k = np.diag([3., 5., 0.])
        aa = np.array([1., -2., 0.]); bb = np.array([.7, -.2, 0.]) if linear else np.zeros(3)
        rind = [2, 3, 1]; effort = 0
    else:
        m = np.ones((1, 1)); c = np.array([[2. if model == "viscous" else 0.]])
        k = np.zeros((1, 1)); aa = np.ones(1); bb = np.array([.7 if linear else 0.])
        rind = [1]; effort = 0
    if zero:
        aa *= 0; bb *= 0
    start = t0 if table_start is None else table_start
    n = len(m)
    case = dict(name=name, model=model, t0=t0, tf=tf, h=h, hs=h if hs is None else hs,
                method=method, gate=gate, M=m, C=c, K=k, A=aa, B=bb, rind=rind,
                lind=list(range(1, n+1)), table_start=start, table_end=tf, ntable=5,
                effort=effort, ratio=1., radius=.5, jp=1., ke=3., marker=MARKER,
                wrapper=0, outcap=4097, invalid=False, periodic=False)
    case.update(extra)
    return case


def expected_grid(case):
    start, finish, step = map(lambda key: Decimal(str(case[key])), ("t0", "tf", "hs"))
    out = [start]
    j = 1
    tol = Decimal(str(16*EPS*max(1., abs(case['tf']))))
    while start+j*step < finish-tol:
        out.append(start+j*step)
        j += 1
    if finish != start:
        out.append(finish)
    return np.array([float(t) for t in out])


def load_table(case):
    if case["periodic"]:
        x = np.linspace(case["table_start"], case["table_end"], case["ntable"])
        phase = (x-case["table_start"])/(case["table_end"]-case["table_start"])
        f = np.sin(2*np.pi*phase)[:, None]*case["A"][None, :]
    else:
        x = np.linspace(case["table_start"], case["table_end"], case["ntable"])
        f = case["A"][None, :]+(x-case["table_start"])[:, None]*case["B"][None, :]
    if case.get("bad_table"):
        x[2] = x[1]
    if 'nonfinite_table_time' in case:
        x[2]=case['nonfinite_table_time']
    if 'nonfinite_load' in case:
        f[2,0]=case['nonfinite_load']
    return x, f


def force_function(case):
    if not case["periodic"]:
        return lambda t: case["A"]+(t-case["table_start"])*case["B"]
    x, values = load_table(case)
    spline = CubicSpline(x, values, bc_type="natural", axis=0)
    period = x[-1]-x[0]
    return lambda t: np.asarray(spline(x[0]+np.mod(t-x[0], period)))


def reference(case, times):
    n = len(case["M"]); tau = times-case["t0"]
    force = force_function(case)
    a0 = force(case["t0"])
    if case["model"] == "free" and not case["periodic"]:
        q = tau[:, None]**2*a0/2+tau[:, None]**3*case["B"]/6
        v = tau[:, None]*a0+tau[:, None]**2*case["B"]/2
    else:
        system = np.zeros((2*n+2, 2*n+2))
        system[:n, n:2*n] = np.eye(n)
        system[n:2*n, :n] = -solve(case["M"], case["K"])
        system[n:2*n, n:2*n] = -solve(case["M"], case["C"])
        system[n:2*n, 2*n] = solve(case["M"], a0)
        system[n:2*n, 2*n+1] = solve(case["M"], case["B"])
        system[-1, -2] = 1.
        z0 = np.zeros(2*n+2); z0[-2] = 1.
        if not case["periodic"]:
            z = np.array([expm(system*t)@z0 for t in tau])
        else:
            matrix = system[:2*n, :2*n]
            def rhs(t, state):
                return matrix@state+np.r_[np.zeros(n), solve(case["M"], force(t))]
            solution = solve_ivp(rhs, (case["t0"], case["tf"]), np.zeros(2*n), method="DOP853",
                                 rtol=2e-12, atol=2e-14, dense_output=True,
                                 max_step=(case["table_end"]-case["table_start"])/32)
            if not solution.success:
                raise ValueError(solution.message)
            z = solution.sol(times).T
        q, v = z[:, :n], z[:, n:2*n]
    f = np.array([force(t) for t in times])
    a = solve(case["M"], (f-v@case["C"].T-q@case["K"].T).T).T
    return q, v, a, f


def write_input(case, path):
    n = len(case["M"]); x, f = load_table(case)
    lines = [" ".join(map(str, [n, case["method"], len(case["lind"]), len(case["rind"]),
                               len(x), case["effort"], case["wrapper"], case["outcap"]]))]
    period = case.get('input_period',case["table_end"]-case["table_start"])
    lines.append(" ".join(f"{v:.17g}" for v in [case["t0"], case["tf"], case["h"], case["hs"], period, case["marker"]]))
    lines.append(" ".join(f"{v:.17g}" for v in [case["ke"], case["ratio"], case["radius"], case["jp"]]))
    for key in ("M", "C", "K"):
        lines.extend(" ".join(f"{v:.17g}" for v in row) for row in case[key])
    lines += [" ".join(map(str, case["lind"])), " ".join(map(str, case["rind"]))]
    lines.extend(" ".join(f"{v:.17g}" for v in [xx, *ff]) for xx, ff in zip(x, f))
    path.write_text("\n".join(lines)+"\n")


def run_native(binary, case, output):
    folder = output/case["name"]; folder.mkdir()
    write_input(case, folder/"input.txt")
    process = subprocess.run([str(binary), str(folder/"input.txt")], capture_output=True, text=True, timeout=40)
    (folder/"stdout.txt").write_text(process.stdout)
    (folder/"stderr.txt").write_text(process.stderr)
    (folder/"returncode").write_text(str(process.returncode)+"\n")
    result = dict(name=case["name"], native_returncode=process.returncode, report=None, rows=[])
    for line in process.stdout.splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "STATE":
            result.update(ok=int(parts[1]), requested=int(parts[2]))
        elif parts[0] == "REPORT":
            keys = ["n_integrated", "n_requested", "n_published", "complete", "t_initial", "t_final_requested",
                    "last_integrated_time", "last_step", "last_published_time"]
            vals = [int(x) for x in parts[1:5]]+[float(x) for x in parts[5:]]
            result["report"] = dict(zip(keys, vals))
        elif parts[0] == "FILLED":
            result["filled"] = [int(x) for x in parts[1:]]
        elif parts[0] == 'DIAGNOSTIC':
            result['diagnostic']=line.partition(' ')[2].strip()
        elif parts[0] == "ROW":
            result["rows"].append([float(x) for x in parts[2:]])
    result["stderr"] = process.stderr
    return result


def assess(case, result, baseline):
    issues = []; completeness = []
    if case["invalid"]:
        if result["native_returncode"] != 0 or result.get("ok", 0) >= 0:
            issues.append("invalid input was not rejected contextually")
        if result["report"] and result["report"]["complete"]:
            issues.append("invalid input published complete status")
        if re.search(r'TORSION_TRANSIENT.*(?:EVENT=END.*STATUS=OK|PERCENT=\s*100)', result['stderr']):
            issues.append('invalid input emitted terminal success or 100 percent')
        if case.get('nonfinite_input'):
            if not result.get('diagnostic'):
                issues.append('nonfinite input lacked a contextual diagnostic')
            if result.get('requested',0)!=0 or result['rows']:
                issues.append('nonfinite input exposed output rows before rejection')
            if not baseline:
                report=result['report']
                if not report or report['n_integrated']!=0 or report['n_published']!=0 or any(result.get('filled',[])):
                    issues.append('nonfinite input integrated or published before rejection')
        return dict(status="FAIL" if issues else "PASS", issues=issues, completeness_issues=[], metrics={})
    if result["native_returncode"] != 0 or result.get("ok", -1) != 0:
        issues.append("valid native analysis failed")
    grid = expected_grid(case)
    rows = np.asarray(result["rows"], dtype=float)
    if rows.ndim != 2 or len(rows) != len(grid) or result.get("requested") != len(grid):
        completeness.append("advertised/actual/expected row count mismatch")
    report = result["report"]
    if not baseline:
        expected_steps = len(expected_grid(dict(case, hs=case['h'])))-1
        if not report:
            completeness.append("instrumentation report missing")
        else:
            if (report["n_requested"] != len(grid) or report["n_published"] != len(grid) or
                    report["n_integrated"] != expected_steps or report["complete"] != 1):
                completeness.append("integration/publication counters or completion flag disagree")
            ttol = 16*EPS*max(1., abs(case["tf"]))
            for key, want in (("t_initial", case["t0"]), ("t_final_requested", case["tf"]),
                              ("last_integrated_time", case["tf"]), ("last_published_time", case["tf"])):
                actual_time=report.get(key,float('inf'))
                if not np.isfinite(actual_time) or abs(actual_time-want) > ttol:
                    completeness.append(key+" does not match actual contract")
            if expected_steps and (not np.isfinite(report['last_step']) or not 0 < report["last_step"] <= case["h"]+ttol):
                completeness.append("last actual step invalid")
            if len(result.get("filled", [])) != len(grid) or not all(result.get("filled", [])):
                completeness.append("fill mask absent/incomplete")
    if rows.ndim != 2 or not len(rows):
        return dict(status="FAIL", issues=issues+completeness, completeness_issues=completeness, metrics={})
    nr, nl = len(case["rind"]), len(case["lind"])
    active = np.c_[rows[:, :1+nr], rows[:, 1+3*nr:1+3*nr+nl]] if case["wrapper"] else rows[:, :1+3*nr+nl]
    if not np.all(np.isfinite(active)) or np.any(active == case["marker"]):
        completeness.append("active q/v/a/load/time contains marker or nonfinite value")
    if len(rows) != len(grid) or completeness:
        return dict(status="FAIL", issues=issues+completeness, completeness_issues=completeness, metrics={})
    times = rows[:, 0]
    if np.max(np.abs(times-grid)) > 16*EPS*max(1., abs(case["tf"])):
        issues.append("output time grid differs from independent decimal grid")
    if np.any(np.diff(times) <= 0):
        issues.append('published times are not distinct/increasing')
        return dict(status='FAIL',issues=issues,completeness_issues=issues,metrics={})
    q, v, a, f = reference(case, times)
    order = np.array(case["rind"])-1
    actual = [rows[:, 1:1+nr], rows[:, 1+nr:1+2*nr], rows[:, 1+2*nr:1+3*nr], rows[:, 1+3*nr:1+3*nr+nl]]
    wanted = [q[:, order], v[:, order], a[:, order], f]
    metrics = {}
    for key, got, want in zip(("q", "v", "a_dyn", "load"), actual, wanted):
        if case["wrapper"] and key in ("v", "a_dyn"):
            continue
        error = float(np.max(np.abs(got-want))/max(1., float(np.max(np.abs(want)))))
        metrics[key+"_scaled_error"] = error
        tolerance = 1e-10 if key == "load" or (case["model"] == "free" and not np.any(case["B"])) else 5e-3
        if error > tolerance:
            issues.append(key+" differs from physical oracle")
    if not case["wrapper"]:
        undo = np.argsort(order)
        qn, vn, an = (x[:, undo] for x in actual[:3])
        ma, cv, kq = an@case["M"].T, vn@case["C"].T, qn@case["K"].T
        residual = np.max(np.abs(ma+cv+kq-actual[3]), axis=1)
        den = sum(np.max(np.abs(x), axis=1) for x in (ma, cv, kq, actual[3]))
        eta = np.divide(residual, den, out=residual.copy(), where=den != 0)
        metrics["equilibrium_eta"] = float(np.max(eta))
        if np.max(eta) > 1000*EPS*len(case["M"]):
            issues.append("original-coordinate equilibrium residual exceeds declared criterion")
        dense = CubicHermiteSpline(times, qn, vn, axis=0)
        points, weights = np.polynomial.legendre.leggauss(4)
        work = loss = 0.
        forcing = force_function(case)
        for left, right in zip(times[:-1], times[1:]):
            xx = (left+right)/2+(right-left)*points/2
            vv = dense(xx, 1)
            work += (right-left)/2*sum(w*np.dot(forcing(t), vel) for w, t, vel in zip(weights, xx, vv))
            loss += (right-left)/2*sum(w*vel@case["C"]@vel for w, vel in zip(weights, vv))
        energy = .5*(vn[-1]@case["M"]@vn[-1]+qn[-1]@case["K"]@qn[-1])
        exact_energy = .5*(v[-1]@case['M']@v[-1]+q[-1]@case['K']@q[-1])
        balance = abs(energy+loss-work)/max(1., abs(work), abs(energy), abs(loss))
        metrics.update(energy_balance_scaled=float(balance), energy_scaled_error=float(abs(energy-exact_energy)/max(1.,abs(exact_energy))),
                       energy_J=float(energy), dissipation_J=float(loss), work_J=float(work))
        if loss < -1e-13 or balance > 5e-3:
            issues.append("energy/dissipation gate failed")
    if case["effort"]:
        torque = case["ke"]*case["ratio"]*(q[:, 1]-q[:, 0])
        # Native legacy kernel publishes the two oriented nodal faces.
        wanted_effort = np.c_[-torque, torque, -torque*case["radius"]/case["jp"], torque*case["radius"]/case["jp"]]
        err = float(np.max(np.abs(rows[:, -4:]-wanted_effort))/max(1., float(np.max(np.abs(wanted_effort)))))
        metrics["effort_scaled_error"] = err
        if err > 5e-3:
            issues.append("signed native torque/stress differs from constitutive oracle")
    return dict(status="FAIL" if issues else "PASS", issues=issues, completeness_issues=[], metrics=metrics)


def cases_for_method(method):
    def make(name, **kw):
        return fixture(f"m{method}_{name}", method=method, **kw)
    cases = [make("aligned", duration=.01, gate="REV01"),
             make("roundoff03", duration=.3, h=.1, gate="REV01"),
             make("roundoff029", duration=.29, h=.01, gate="REV01"),
             make("fraction", duration=.0105, h=.004, hs=.004, gate="REV01"),
             make("short", duration=.001, h=.004, hs=.004, gate="REV01"),
             make('short_huge_nominal',duration=.001,h=1e200,hs=.001,gate='REV01'),
             make('translated_large', t0=1e6, duration=.003, h=.001, hs=.001, ntable=4, gate='REV01')]
    cases.append(make('fine41',duration=.01,h=.001,hs=.00025))
    for ratio in (.25, .5, 1., 2., 1.3):
        cases.append(make("stride_"+str(ratio), duration=.016, h=.001, hs=.001*ratio))
    for ratio in (.25,1.,2.,1.3):
        cases.append(make('coupled_stride_'+str(ratio),model='coupled',duration=.04,h=.001,hs=.001*ratio))
    cases += [make("shifted", t0=.37, duration=.016, linear=True, h=.001, hs=.00025),
              make("cropped", t0=.037, duration=.016, table_start=0., linear=True, h=.001, hs=.0007),
              make("affine", linear=True, duration=.12, h=.004, hs=.001),
              make('affine_nodes',linear=True,duration=.12,h=.004,hs=.004),
              make('cropped_nodes',t0=.037,duration=.016,table_start=0.,linear=True,h=.001,hs=.001),
              make("damped_affine", model="viscous", linear=True, duration=.12, h=.002, hs=.0013),
              make("multi", model="multi", linear=True, duration=.04, h=.001, hs=.00025),
              make("zero", model="multi", zero=True, duration=.016, h=.001, hs=.00025),
              make("zero_other_marker", model="multi", zero=True, duration=.016, h=.001, hs=.00025, marker=4.321987e180),
              make("two_load_points", linear=True, duration=.012, h=.001, hs=.00025, ntable=2),
              make("wrapper", model="coupled", duration=.04, h=.001, hs=.00025, wrapper=1),
              make("periodic_spline", model="coupled", t0=.3, duration=.12, h=.0005, hs=.0007,
                   periodic=True, table_end=.38, ntable=17)]
    for key, changes in [("hzero", dict(h=0.)), ("hnegative", dict(h=-.001)),
                         ("hszero", dict(hs=0.)), ("hsnegative", dict(hs=-.001)),
                         ("reversed", dict(tf=-.01)), ("capacity", dict(outcap=2)),
                         ("bad_time_table", dict(bad_table=True)), ("bad_index", dict(rind=[8])),
                         ("unrepresentable_time", dict(t0=float(2**52), tf=float(2**52+2), h=.25, hs=.5,
                                                       table_start=float(2**52), table_end=float(2**52+2), ntable=3))]:
        cases.append(make("invalid_"+key, invalid=True, **changes))
    # Deliberately alter one field only, leaving all other input fields finite.
    # These are real Fortran input tokens, not altered output/parser evidence.
    for field in ('h','hs','t0','tf','input_period','nonfinite_table_time','nonfinite_load'):
        for label,value in (('nan',float('nan')),('positive_inf',float('inf'))):
            case=make('invalid_nonfinite_'+field+'_'+label,invalid=True,nonfinite_input=True)
            case[field]=value
            cases.append(case)
    for model in ("free", "viscous", "coupled"):
        for level, h in enumerate((.008, .004, .002)):
            for sampling, hs in (("dense", .008/7), ("nodes", h)):
                cases.append(make(f"refine_{model}_{level}_{sampling}", model=model, linear=model!="coupled",
                                  duration=.16, h=h, hs=hs, refinement_model=model, level=level, sampling=sampling))
    return cases


def refinements(cases, raw, assessed):
    reports = []; failures = []
    for method in (0, 1):
        for model in ("free", "viscous", "coupled"):
            errors = {key: [] for key in ("q", "v", "a_dyn", "effort", "energy", "energy_balance_nodes", "kinematic_defect")}
            for level in range(3):
                name = f"m{method}_refine_{model}_{level}_dense"
                nodes_name = f"m{method}_refine_{model}_{level}_nodes"
                met = assessed[name]["metrics"]
                for key in ("q", "v", "a_dyn", "effort"):
                    errors[key].append(met.get(key+"_scaled_error", float("inf")))
                errors["energy"].append(met.get("energy_scaled_error", float("inf")))
                errors['energy_balance_nodes'].append(assessed[nodes_name]['metrics'].get('energy_balance_scaled',float('inf')))
                dense = np.asarray(raw[name]["rows"]); nodes = np.asarray(raw[nodes_name]["rows"])
                n = len(cases[name]["rind"])
                defect = float("inf")
                if dense.ndim == nodes.ndim == 2 and len(dense)>2 and len(nodes)>2 and assessed[nodes_name]["status"] == "PASS":
                    time = dense[:, 0]
                    mask = np.ones(len(time), dtype=bool); mask[[0, -1]] = False
                    for hh in (.008, .004, .002):
                        rr = (time-cases[name]["t0"])/hh
                        mask &= np.abs(rr-np.round(rr)) > 1e-6
                    if assessed[name]['status'] == 'PASS':
                        qref,vref,aref,_ = reference(cases[name],time[mask])
                        for key,got,want in [('q',dense[mask,1:1+n],qref),
                                             ('v',dense[mask,1+n:1+2*n],vref),
                                             ('a_dyn',dense[mask,1+2*n:1+3*n],aref)]:
                            errors[key][-1] = float(np.max(np.abs(got-want))/max(1.,float(np.max(np.abs(want)))))
                        if model == 'coupled':
                            tq=cases[name]['ke']*(qref[:,1]-qref[:,0])
                            wanted=np.c_[-tq,tq,-tq*.5,tq*.5]
                            errors['effort'][-1]=float(np.max(np.abs(dense[mask,-4:]-wanted))/max(1.,float(np.max(np.abs(wanted)))))
                    poly = CubicHermiteSpline(nodes[:, 0], nodes[:, 1:1+n], nodes[:, 1+n:1+2*n], axis=0)
                    for derivative,offset in ((0,1),(1,1+n)):
                        observed=dense[:,offset:offset+n]
                        hermite_error=float(np.max(np.abs(poly(time,derivative)-observed))/max(1.,float(np.max(np.abs(observed)))))
                        if hermite_error>1e-12:
                            failures.append(f'method {method} {model} level{level} Hermite derivative{derivative}: {hermite_error}')
                    adyn = dense[:, 1+2*n:1+3*n]
                    defect = float(np.max(np.abs(poly(time[mask], 2)-adyn[mask]))/max(1., float(np.max(np.abs(adyn[mask])))))
                errors["kinematic_defect"].append(defect)
            for key, sequence in errors.items():
                if key == "effort" and model != "coupled":
                    continue
                minimum = .9 if key == "kinematic_defect" else 1.8
                orders = []; status = "PASS"
                for coarse, fine in zip(sequence[:-1], sequence[1:]):
                    if max(coarse, fine) <= FLOOR:
                        orders.append("ROUND_OFF_LIMIT")
                    elif not np.isfinite(coarse+fine) or coarse <= 0 or fine <= 0:
                        status = "FAIL"; orders.append(None)
                    else:
                        order = float(np.log2(coarse/fine)); orders.append(order)
                        if order < minimum:
                            status = "FAIL"
                if status == "FAIL":
                    failures.append(f"method {method} {model} {key} refinement")
                reports.append(dict(method=method, model=model, metric=key, errors=sequence, orders=orders,
                                    minimum_order=minimum, status=status))
    return reports, failures


def invariance(cases, raw, assessed):
    reports=[]
    for method in (0,1):
        base=f'm{method}_stride_1.0'
        for other in [f'm{method}_stride_{r}' for r in (.25,.5,2.,1.3)]:
            status='FAIL'; error=None; count=0
            if assessed[base]['status']==assessed[other]['status']=='PASS':
                left=np.asarray(raw[base]['rows']);right=np.asarray(raw[other]['rows'])
                errors=[]
                for row in left:
                    matches=right[np.abs(right[:,0]-row[0])<=16*EPS]
                    if len(matches)==1:
                        errors.append(np.max(np.abs(matches[0,1:5]-row[1:5])))
                count=len(errors);error=float(max(errors)) if errors else None
                status='PASS' if count>=2 and error<=1e-12 else 'FAIL'
            reports.append(dict(base=base,other=other,common_rows=count,max_error=error,status=status))
        base=f'm{method}_coupled_stride_1.0'
        for other in [f'm{method}_coupled_stride_{r}' for r in (.25,2.,1.3)]:
            status='FAIL';error=None;count=0
            if assessed[base]['status']==assessed[other]['status']=='PASS':
                left=np.asarray(raw[base]['rows']);right=np.asarray(raw[other]['rows']);errors=[]
                for row in left:
                    matches=right[np.abs(right[:,0]-row[0])<=16*EPS]
                    if len(matches)==1:errors.append(np.max(np.abs(matches[0,1:]-row[1:])))
                count=len(errors);error=float(max(errors)) if errors else None
                status='PASS' if count>=2 and error<=1e-12 else 'FAIL'
            reports.append(dict(base=base,other=other,common_rows=count,max_error=error,status=status))
        first=f'm{method}_zero'; second=f'm{method}_zero_other_marker'
        status='FAIL'
        if assessed[first]['status']==assessed[second]['status']=='PASS':
            left=np.asarray(raw[first]['rows'])[:,:13];right=np.asarray(raw[second]['rows'])[:,:13]
            status='PASS' if np.array_equal(left,right) else 'FAIL'
        reports.append(dict(base=first,other=second,status=status))
    return reports


def json_finite(value):
    if isinstance(value,float) and not np.isfinite(value): return None
    if isinstance(value,dict): return {k:json_finite(v) for k,v in value.items()}
    if isinstance(value,list): return [json_finite(v) for v in value]
    return value


def partial_diagnostics(cases,raw):
    """Retain before-fix state evidence even when publication is incomplete.

    These filtered observations cannot make any gate pass. Excluded sentinel
    cells and times are explicitly counted; only the full assessor qualifies.
    """
    result={}
    for name,case in cases.items():
        if case['invalid']:continue
        rows=np.asarray(raw[name]['rows']);n=len(case['rind'])
        if rows.ndim!=2 or not len(rows):continue
        valid=np.all(np.isfinite(rows[:,:1+n]),axis=1)&np.all(rows[:,:1+n]!=case['marker'],axis=1)
        valid &= (rows[:,0]>=case['t0'])&(rows[:,0]<=case['tf'])
        if not np.any(valid):continue
        times=rows[valid,0];q,v,a,f=reference(case,times);order=np.array(case['rind'])-1
        error=float(np.max(np.abs(rows[valid,1:1+n]-q[:,order])))
        result[name]=dict(observed_rows=int(sum(valid)),excluded_rows=int(sum(~valid)),q_max_error_rad=error,
                          scope='partial observations only; never used to grant PASS')
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("binary", type=Path); parser.add_argument("output", type=Path)
    parser.add_argument("--baseline", action="store_true"); parser.add_argument("--mode", required=True)
    parser.add_argument('--focused-rev01',action='store_true')
    parser.add_argument('--nonfinite-only',action='store_true')
    parser.add_argument('--supplement-only',action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    cases = {case["name"]: case for method in (0, 1) for case in cases_for_method(method)}
    if args.focused_rev01:
        cases={name:case for name,case in cases.items() if case['gate']=='REV01' or case['invalid']}
    if args.nonfinite_only:
        cases={name:case for name,case in cases.items() if case.get('nonfinite_input')}
    if args.supplement_only:
        cases={name:case for name,case in cases.items() if case.get('nonfinite_input') or name.endswith('_fine41')}
    raw = {}; assessed = {}
    for name, case in cases.items():
        result = run_native(args.binary.resolve(), case, args.output)
        raw[name] = result; assessed[name] = assess(case, result, args.baseline)
        print(assessed[name]["status"], name, "; ".join(assessed[name]["issues"]), flush=True)
    if args.focused_rev01 or args.nonfinite_only or args.supplement_only:
        report=dict(status='PASS' if all(x['status']=='PASS' for x in assessed.values()) else 'FAIL',mode=args.mode,
                    case_count=len(cases),cases=assessed)
        filename='supplement_summary.json' if args.supplement_only else ('nonfinite_summary.json' if args.nonfinite_only else 'focused_rev01_summary.json')
        (args.output/filename).write_text(json.dumps(report,indent=2)+'\n')
        return int(report['status']!='PASS')
    refinement, ref_failures = refinements(cases, raw, assessed)
    independence=invariance(cases,raw,assessed)
    negative = []
    for method in (0, 1):
        name = f"m{method}_zero"
        if assessed[name]["status"] == "PASS" and not args.baseline:
            changed = copy.deepcopy(raw[name]); changed["filled"][-1] = 0
            rejected = assess(cases[name], changed, False)["status"] == "FAIL"
            negative.append(dict(case=name, zero_values_preserved=True, removed_fill_bit_rejected=rejected))
    gates = {}
    for gate in ("REV01", "REV02"):
        gates[gate] = "PASS" if all(assessed[name]["status"] == "PASS" for name, c in cases.items() if c["gate"] == gate) else "FAIL"
    gates["completeness"] = "PASS" if not any(v["completeness_issues"] for v in assessed.values()) else "FAIL"
    gates["no_false_success"] = "PASS" if (all(assessed[n]["status"] == "PASS" for n, c in cases.items() if c["invalid"])
                                               and len(negative)==2 and all(x["removed_fill_bit_rejected"] for x in negative)) else "FAIL"
    native_fill=dict(status='FAIL',reason='baseline has no native completion instrumentation')
    if not args.baseline:
        proc=subprocess.run([str(args.binary.resolve()),'--fill-control'],text=True,capture_output=True,timeout=10)
        (args.output/'native_fill_control.txt').write_text(proc.stdout+proc.stderr)
        native_fill=dict(status='PASS' if proc.returncode==0 and 'NATIVE_MISSING_MARK -1 0 2' in proc.stdout and
                         'NATIVE_EXACT_ZERO 0 1 3' in proc.stdout and 'NATIVE_TINY_SPAN 0 1' in proc.stdout
                         else 'FAIL',returncode=proc.returncode)
    if native_fill['status']!='PASS': gates['no_false_success']='FAIL'
    gates["physics"] = "PASS" if all(v["status"] == "PASS" for v in assessed.values()) else "FAIL"
    gates["refinement"] = "PASS" if not ref_failures else "FAIL"
    if any(item['status']!='PASS' for item in independence): gates['REV02']='FAIL'
    report = dict(status="PASS" if all(x=="PASS" for x in gates.values()) else "FAIL", mode=args.mode,
                  baseline=args.baseline, gates=gates, cases=assessed, case_count=len(cases),
                  refinements=refinement, refinement_failures=ref_failures, negative_fill_controls=negative,
                  publication_independence=independence,
                  native_fill_control=native_fill,
                  partial_state_diagnostics=partial_diagnostics(cases,raw),
                  criteria=dict(residual_factor=1000, precision="real64", order_q_v_a_effort_energy=1.8,
                                order_kinematic_defect=.9, normalized_order_floor=FLOOR))
    (args.output/"native_summary.json").write_text(json.dumps(json_finite(report), indent=2, allow_nan=False)+"\n")
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
