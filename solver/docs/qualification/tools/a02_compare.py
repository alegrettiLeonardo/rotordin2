#!/usr/bin/env python3
"""Compare native output to its independent 2x2 analytical shaft oracle.

Tolerance is the half-ULP of each printed decimal plus a binary64 roundoff
allowance based on the deliberately ill-conditioned free-rotor FRF (bound 1e4).
No stored golden values or solver outputs serve as numerical authority.
"""
from pathlib import Path
import cmath
import math
import re
import sys

ROOT = Path(sys.argv[1])
NUM = re.compile(r"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[EeDd][+-]?\d+)?$")
NATIVE_ALLOWANCE = 20 * sys.float_info.epsilon * 1e4
checks = 0
phasor_checks = 0
max_phasor_error = {"angle": 0., "twist": 0., "torque": 0., "stress": 0.}
max_error = {"angle": 0., "phase": 0., "twist": 0., "torque": 0., "stress": 0.}


def load(path):
    text = path.read_text()
    assert "NATIVE_RESULT=0" in text, path
    assert not re.search(r"\b(?:NaN|Inf(?:inity)?)\b", text, re.I), path
    lines = text.splitlines()
    oracle = [[float(x) for x in line.split()[1:]] for line in lines if line.startswith("ORACLE ")]
    times = [[float(x) for x in line.split()[1:]] for line in lines if line.startswith("TIME_ORACLE ")]
    return lines, oracle, times


def block(lines, title):
    start = next(i for i, line in enumerate(lines) if line.strip().startswith(title))
    rows = []
    for line in lines[start+1:]:
        tok = line.split()
        if len(tok) == 2 and all(NUM.fullmatch(x) for x in tok):
            rows.append(tok)
        elif rows:
            break
    assert rows, title
    return rows


def compare(token, expected, category, scale, context):
    global checks
    actual = float(token)
    mantissa, exponent = re.split("[EeDd]", token) if re.search("[EeDd]", token) else (token, "0")
    digits = len(mantissa.split(".")[1]) if "." in mantissa else 0
    printed_half_ulp = .5001 * 10.**(int(exponent)-digits)
    allowance = printed_half_ulp + NATIVE_ALLOWANCE * max(abs(expected), scale)
    difference = abs(actual-expected)
    max_error[category] = max(max_error[category], difference)
    assert difference <= allowance, (context, category, actual, expected, difference, allowance)
    checks += 1


for path in sorted((ROOT / "current").glob("*-r*-p*.log")):
    lines, oracle, times = load(path)
    native = [[float(x) for x in line.split()[1:]] for line in lines if line.startswith("NATIVE_PHASOR ")]
    assert len(native) == len(oracle) == 2
    for actual, expected in zip(native, oracle):
        for idx, category, scale in [(1,"angle",1.),(3,"twist",.001),(5,"torque",100.),(7,"stress",2e6)]:
            a=complex(actual[idx],actual[idx+1]);e=complex(expected[idx],expected[idx+1])
            err=abs(a-e);max_phasor_error[category]=max(max_phasor_error[category],err)
            assert err <= NATIVE_ALLOWANCE*max(abs(e),scale), (path.name,category,a,e,err)
            phasor_checks += 1
    if path.name.startswith(("frequency-", "firstnode-")):
        amp = block(lines, "Amplitude (rad/s)")
        phase = block(lines, "Phase (rad/s)")
        twist = block(lines, "Angular Displacement (rad/s)")
        torque = block(lines, "Torsion Output Torque")
        stress = block(lines, "Torsion Output Shear Stress")
        assert len(amp) == len(phase) == len(twist) == len(torque) == len(stress) == len(oracle) == 2
        for i, ref in enumerate(oracle):
            q = complex(ref[1],ref[2]);dq=complex(ref[3],ref[4])
            compare(amp[i][1], abs(q), "angle", 1., path.name)
            expected_phase = cmath.phase(q) % (2*math.pi)
            # An exactly zero response has no defined phase.
            if abs(q) > 1e-10:
                compare(phase[i][1], expected_phase, "phase", 1., path.name)
            compare(twist[i][1], abs(dq), "twist", .001, path.name)
            compare(torque[i][1], ref[9], "torque", 100., path.name)
            compare(stress[i][1], ref[10], "stress", 2e6, path.name)
    else:
        angle = block(lines, "Angular Displacement (rad/s)")
        twist = block(lines, "Angular Displacement at division")
        torque = block(lines, "Torsion Output Torque")
        stress = block(lines, "Torsion Output Shear Stress")
        assert len(angle) == len(twist) == len(torque) == len(stress) == len(times) == 4
        for i, ref in enumerate(times):
            compare(angle[i][1],ref[1],"angle",1.,path.name)
            compare(twist[i][1],ref[2],"twist",.001,path.name)
            compare(torque[i][1],ref[3],"torque",100.,path.name)
            compare(stress[i][1],ref[4],"stress",2e6,path.name)

# Prove the three independent defects against compiled baseline production routes.
lines, oracle, _ = load(ROOT / "baseline/frequency-r1-p180.log")
old = float(block(lines,"Torsion Output Torque")[0][1])
assert abs(old) < 1e-8 and oracle[0][9] > 100.
print(f"BASELINE_PHASE_FAIL_REPRODUCED old={old:.12g} expected={oracle[0][9]:.12g} Nm")
lines, _, times = load(ROOT / "baseline/periodic-r2-p90.log")
old = float(block(lines,"Torsion Output Torque")[0][1])
assert abs(old/times[0][3]-2) < 1e-7
print(f"BASELINE_DOUBLE_RATIO_FAIL_REPRODUCED old={old:.12g} expected={times[0][3]:.12g} Nm")
lines, _, times = load(ROOT / "baseline/periodic_firstnode-r1-p90.log")
old = float(block(lines,"Torsion Output Torque")[0][1])
assert abs(old/times[0][3]+1) < 1e-7
print(f"BASELINE_FACE_SIGN_FAIL_REPRODUCED old={old:.12g} expected={times[0][3]:.12g} Nm")
print(f"A02_NATIVE_OUTPUT_ASSERTIONS PASS {checks}; 49 current native route cases")
print(f"A02_NATIVE_COMPLEX_PHASOR_ASSERTIONS PASS {phasor_checks}")
for name, error in max_phasor_error.items():
    print(f"MAX_NATIVE_COMPLEX_ERROR_{name.upper()} {error:.12g}")
for name, error in max_error.items():
    print(f"MAX_PRINTED_ABSOLUTE_ERROR_{name.upper()} {error:.12g}")
print("COMPLEX_PHASE_PRESERVED PASS (two-node)")
print("TORSIONAL_TORQUE PASS (two-node)")
print("TORSIONAL_STRESS PASS (two-node nominal circular/equivalent-section)")
print("THREE_NODE_FULL_INTERPOLATION NOT_QUALIFIED (preserved native K/J mismatch, harmonic routes blocked)")
