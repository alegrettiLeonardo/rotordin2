"""Actual RotorDin CLI: constants preserved; unidentified spin-drive ramps stop."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import numpy as np


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("binary", type=Path)
    parser.add_argument("before_a07", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    template = (root/"tests/reliability/a07_native.txt").read_text()
    args.output.mkdir(parents=True, exist_ok=True)
    summary = {"binary_sha256": hashlib.sha256(args.binary.read_bytes()).hexdigest(),
               "before_A07_binary_sha256": hashlib.sha256(args.before_a07.read_bytes()).hexdigest(),
               "before_control_scope": "current other code; four A07 algorithm files restored from qualified baseline",
               "cases": []}
    constant = "SPEED_PROFILE CONSTANT\nRPM 1500"
    table = "SPEED_PROFILE TABLE\nNPOINTS 3\nTIME RPM\n0 1500\n0.05 1500\n0.1 1500"
    profiles = [
        ("constant1500", "CONSTANT", constant, True),
        ("constant0", "CONSTANT", "SPEED_PROFILE CONSTANT\nRPM 0", True),
        ("flat_table", "USER_PROFILE", table, True),
        ("startup", "STARTUP", "SPEED_PROFILE LINEAR\nSTART_RPM 0\nEND_RPM 1500", False),
        ("coastdown", "COASTDOWN", "SPEED_PROFILE LINEAR\nSTART_RPM 1500\nEND_RPM 0", False),
        ("delayed_ramp", "USER_PROFILE", table.replace("0.1 1500", "0.1 2000"), False),
    ]
    for name, model, profile, allowed in profiles:
        inp = template.replace("1 CONSTANT NEWMARK", f"1 {model} NEWMARK").replace(constant, profile)
        runs = {}
        for role, binary in [("before", args.before_a07), ("after", args.binary)]:
            directory = (args.output/name/role).resolve(); directory.mkdir(parents=True, exist_ok=True)
            (directory/"input.txt").write_text(inp)
            command = [str(binary.resolve()), "-std", "-t", "--transient"]
            proc = subprocess.run(command, input=inp, text=True, cwd=directory, capture_output=True,
                                  env=dict(os.environ, ROTORDIN_TRANSIENT_MATRIX_DUMP="1"), timeout=90)
            (directory/"stdout.txt").write_text(proc.stdout)
            (directory/"stderr.txt").write_text(proc.stderr)
            (directory/"returncode.txt").write_text(str(proc.returncode)+"\n")
            lines = proc.stdout.splitlines()
            matrices = np.array([line.split()[1:] for line in lines if line.startswith("MATRIX ")], float)
            states = np.array([line.split()[1:] for line in lines if line.startswith("STATE ")
                               and len(line.split()) == 10], float)
            assert np.all(np.isfinite(matrices)) and np.all(np.isfinite(states))
            runs[role] = (proc, matrices, states)
        before, bm, bs = runs["before"]; after, am, ass = runs["after"]
        assert before.returncode == 0 and "STATUS SUCCESS" in before.stdout and len(bs) > 0
        record = {"case": name, "before_returncode": before.returncode, "after_returncode": after.returncode}
        if allowed:
            assert after.returncode == 0 and "STATUS SUCCESS" in after.stdout
            assert am.shape == bm.shape and ass.shape == bs.shape and len(ass) > 0
            matrix_error = float(np.max(abs(am-bm))/max(1., np.max(abs(bm))))
            state_error = float(np.max(abs(ass[:, 6:]-bs[:, 6:]))/max(1e-30, np.max(abs(bs[:, 6:]))))
            assert matrix_error < 1e-14 and state_error < 1e-10
            record.update(result="PASS", matrix_error=matrix_error, state_error=state_error,
                          before_states=len(bs), after_states=len(ass))
        else:
            combined = after.stdout+after.stderr
            assert after.returncode != 0 and "A07 NOT_QUALIFIED" in combined
            assert "drive torque/tilt-work contract" in combined
            assert len(ass) == 0 and len(am) == 0
            assert "STATUS SUCCESS" not in after.stdout
            record.update(result="NOT_QUALIFIED", gate_test="PASS", after_states=0,
                          reason="native actuator tilt-work and torque distribution unspecified")
        summary["cases"].append(record)
    summary["constant_speed_equivalence"] = "PASS"
    summary["fail_closed_production_ramps"] = "PASS"
    summary["production_ramp_physics"] = "NOT_QUALIFIED"
    (args.output/"real-cli.json").write_text(json.dumps(summary, indent=2)+"\n")
    print("A07 actual CLI: PASS (3 constants preserved, 3 unidentified ramps rejected before integration)")


if __name__ == "__main__":
    main()
