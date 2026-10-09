#!/usr/bin/env python3
"""Run the unmodified review and product qualification on a fresh exact-SHA clone."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
MAIN = ROOT / 'work/rotordin2'
REVIEW = ROOT / 'rev_work/review_original/Revisao_Codex_644b85_Evidencias'
BASELINES = MAIN / 'build/pre-st41-baseline'


def git(*args, cwd=MAIN):
    return subprocess.check_output(['git', *args], cwd=cwd, text=True).strip()


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    expected = sys.argv[1]
    assert git('rev-parse', 'HEAD') == expected
    assert not git('status', '--porcelain=v1')
    assert git('branch', '--show-current') == 'fix/rotordin2-mathematical-reliability'
    campaign = ROOT / ('rev_work/final_campaign_' + expected[:12])
    campaign.mkdir(exist_ok=False)
    repo = ROOT / ('rev_work/final_source_' + expected[:12])
    assert not repo.exists()
    env = os.environ.copy()
    env['PATH'] = str(ROOT / 'toolchain') + os.pathsep + env['PATH']
    env['FC'] = 'gfortran'
    env['LC_ALL'] = 'C'
    for key in ('RELIABILITY_BUILD_DIR', 'REV_TEMPORAL_BIN', 'REV_TEMPORAL_SKIP_BUILD',
                'REV_TEMPORAL_BASELINE', 'REV_TEMPORAL_EVIDENCE_ROOT', 'A04_BASELINE',
                'A05_BASELINE', 'A02_BASE_REF'):
        assert not env.get(key), 'Unexpected final qualification override: ' + key

    def run(label, args, cwd=ROOT, extra=None):
        command = {'argv': list(map(str, args)), 'cwd': str(cwd),
                   'environment': {'FC': 'gfortran', 'LC_ALL': 'C', **(extra or {})}}
        (campaign / (label + '.command.json')).write_text(json.dumps(command, indent=2) + '\n')
        print('START ' + label, flush=True)
        with (campaign / (label + '.log')).open('wb') as stream:
            completed = subprocess.run(command['argv'], cwd=cwd, env={**env, **(extra or {})},
                                       stdout=stream, stderr=subprocess.STDOUT)
        (campaign / (label + '.returncode.txt')).write_text(str(completed.returncode) + '\n')
        print(('PASS ' if completed.returncode == 0 else 'FAIL ') + label +
              ' rc=' + str(completed.returncode), flush=True)
        if completed.returncode:
            raise SystemExit(completed.returncode)

    bundle = campaign / 'candidate-history.bundle'
    run('bundle-create', ['git', 'bundle', 'create', bundle, '--all'], MAIN)
    run('bundle-verify', ['git', 'bundle', 'verify', bundle], MAIN)
    run('restore', ['git', 'clone', '--branch', 'fix/rotordin2-mathematical-reliability', bundle, repo])
    run('restored-fsck', ['git', 'fsck', '--full'], repo)
    assert git('rev-parse', 'HEAD', cwd=repo) == expected
    assert not git('status', '--porcelain=v1', cwd=repo)
    run('source-integrity', ['bash', 'tests/check_sources.sh'], repo)
    run('source-layout', ['bash', 'tests/check_sources.sh', '--layout'], repo)
    originals = {name: sha256(REVIEW / name) for name in
                 ('run_directed_review.sh', 'verify_directed_results.py', 'probes/review_time_grid.f90',
                  'cases/default_output.txt', 'cases/explicit_output.txt', 'cases/roundoff_end.txt')}
    after = campaign / 'after_directed'
    run('after-directed', ['bash', REVIEW / 'run_directed_review.sh', repo, after],
        extra={'ALLOW_OTHER_HEAD': '1'})
    original_binaries = {}
    for mode, filename in (('release', 'rotordin2'), ('debug', 'rotordin2-debug')):
        src = repo / 'bin' / filename
        dst = after / mode / filename
        shutil.copy2(src, dst)
        original_binaries[mode] = sha256(dst)
        shutil.copy2(repo / 'build' / mode / 'config.stamp', after / mode / 'native_build_config.txt')
    assert all(sha256(REVIEW / name) == digest for name, digest in originals.items())
    (campaign / 'review_unmodified.json').write_text(json.dumps({
        'status': 'PASS', 'files': originals}, indent=2) + '\n')
    # The second campaign starts from fresh object and binary directories too.
    # All evidence lives outside this disposable clone and survives distclean.
    run('clean-between-campaigns', ['make', 'FC=gfortran', 'distclean'], repo)
    final = campaign / 'integrated'
    run('integrated', ['bash', 'tests/reliability/run_qualification.sh', final,
                      BASELINES / 'rotordin2-baseline', BASELINES / 'rotordin2-debug-baseline'], repo)
    assert git('rev-parse', 'HEAD', cwd=repo) == expected
    assert not git('status', '--porcelain=v1', cwd=repo)
    binaries = []
    for mode, filename in (('release', 'rotordin2'), ('debug', 'rotordin2-debug')):
        tested = final / 'binaries' / filename
        native = repo / 'bin' / filename
        digest = sha256(tested)
        assert digest == sha256(native) == original_binaries[mode], (mode, 'binary identity differs')
        binaries.append({'mode': mode, 'filename': filename, 'sha256': digest})
    result = {'status': 'PASS', 'source_head': expected, 'source_tree': git('rev-parse', 'HEAD^{tree}', cwd=repo),
              'branch': git('branch', '--show-current', cwd=repo), 'repo': str(repo),
              'review_runner_unmodified': True, 'source_clean_before_after': True,
              'independent_and_integrated_binaries_identical': True, 'binaries': binaries}
    (campaign / 'qualification_identity.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)


if __name__ == '__main__':
    main()
