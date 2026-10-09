#!/usr/bin/env python3
"""Read-only audit of the final REV campaign; no solver/build invocation."""
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

base = Path(sys.argv[1]).resolve()
expected = sys.argv[2]
errors = []
facts = {}


def require(condition, description):
    if not condition:
        errors.append(description)


def read(relative):
    return (base / relative).read_text().strip()


def data(relative):
    return json.loads(read(relative))


def git(source, *args):
    result = subprocess.run(['git', '-C', str(source), *args], capture_output=True, text=True)
    require(result.returncode == 0, 'git command failed: ' + ' '.join(args))
    return result.stdout.strip()


def hash_file(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_hash_list(path, cwd):
    lines = path.read_text().splitlines()
    for line in lines:
        expected_hash, name = line.split(maxsplit=1)
        target = Path(name.lstrip('*'))
        if not target.is_absolute():
            target = cwd / target
        require(target.is_file() and hash_file(target) == expected_hash,
                'hash mismatch/missing file: ' + str(target))
    return len(lines)


try:
    require(read('integrated.returncode.txt') == '0', 'outer integrated return code')
    require(read('integrated/returncode.txt') == '0', 'inner integrated return code')
    require(read('after-directed.returncode.txt') == '0', 'directed review return code')
    command = data('integrated.command.json')
    source = Path(command['cwd'])
    facts['source'] = str(source)
    require(git(source, 'rev-parse', 'HEAD') == expected, 'live clone HEAD differs')
    require(not git(source, 'status', '--porcelain=v1'), 'live clone dirty')
    for name in ('source_commit.txt', 'source_commit.after.txt', 'ST41/source_commit.txt',
                 'REV/release/source_commit.txt', 'REV/debug/source_commit.txt'):
        require(read('integrated/' + name) == expected, name + ' differs')
    for name in ('source_status.before.txt', 'source_status.after.txt', 'ST41/source_status.txt'):
        require(read('integrated/' + name) == '', name + ' is not clean')
    require(read('integrated/source_tree.txt') == git(source, 'rev-parse', 'HEAD^{tree}'), 'tree identity')
    original = '4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47'
    require(read('integrated/original_branch.txt') == original and
            read('integrated/original_branch.after.txt') == original, 'original branch altered')
    facts['tracked_hashes_checked'] = verify_hash_list(base/'integrated/tracked_source.sha256', source)
    facts['manifest_hashes_checked'] = verify_hash_list(base/'integrated/ST41/source_manifests.sha256', source)
    facts['binary_hashes_checked'] = verify_hash_list(base/'integrated/final_binaries.sha256', source)
    frozen = ['tests/', ':(exclude)tests/reliability/**', 'lapack/', 'docs/legacy/lapack/',
              'docs/manifests/LAPACK.sha256', 'src/source/resp_f.f90', 'src/source/resp_fv.f90',
              'src/source/resp_t.f90', 'src/source/rd_harmonic_response.f90',
              'src/source/rd_campbell_engine.f90', 'src/source/rd_campbell_families.f90',
              'src/source/transient_speed.f90']
    require(not git(source, 'diff', '--exit-code', original, 'HEAD', '--', *frozen), 'frozen regression diff')
    facts['frozen_regression_diff_rechecked'] = True
    facts['binary_identity'] = {}
    for mode, filename in (('release','rotordin2'),('debug','rotordin2-debug')):
        independent = hash_file(base/'after_directed'/mode/filename)
        integrated = hash_file(base/'integrated/binaries'/filename)
        require(independent == integrated, mode+' original/integrated binary differs')
        facts['binary_identity'][mode] = {'identical':independent == integrated,'sha256':integrated}
    original_review = base.parent/'review_original/Revisao_Codex_644b85_Evidencias'
    review_record = data('review_unmodified.json')
    require(review_record['status'] == 'PASS', 'review unchanged record')
    for name, recorded_hash in review_record['files'].items():
        require(hash_file(original_review/name) == recorded_hash, 'original review file changed: '+name)
    facts['original_review_hashes_rechecked'] = len(review_record['files'])
    checks = list(csv.DictReader((base/'integrated/status.tsv').open(), delimiter='\t'))
    require(len(checks) == 19 and len({x['check'] for x in checks}) == 19, 'aggregate check count/duplicates')
    require(all(x['result'] == 'PASS' and x['returncode'] == '0' for x in checks), 'aggregate check failed')
    st41 = list(csv.DictReader((base/'integrated/ST41/status.tsv').open(), delimiter='\t'))
    blocked = [x for x in st41 if x['result'] != 'PASS']
    require(len(st41) == 26 and len({x['check'] for x in st41}) == 26, 'ST41 check count/duplicates')
    require(len(blocked) == 1 and blocked[0]['check'] == 'historical-st41' and
            blocked[0]['result'] == 'BLOCKED_MISSING_FIXTURES', 'historical scope lost/additional failure')
    require(all(x['returncode'] == '0' for x in st41 if x['result'] == 'PASS'), 'ST41 return code')
    facts['executor_checks'] = len(checks)
    facts['st41_checks'] = {'passed': len(st41)-len(blocked), 'historical_blocked': len(blocked)}
    aggregate = data('integrated/REV-gates.json')
    require(aggregate['status'] == 'PASS' and all(x == 'PASS' for x in aggregate['gates'].values()), 'REV aggregate')
    require('no repeated executions or case counts' in aggregate['scope'], 'REV aggregate scope')
    require(set(aggregate['modes']) == {'release', 'debug'}, 'REV mode set')
    facts['modes'] = {}
    for mode in ('release', 'debug'):
        folder = 'integrated/REV/' + mode + '/'
        summary, status = data(folder+'summary.json'), data(folder+'status.json')
        native, cli = data(folder+'native/native_summary.json'), data(folder+'cli/cli_summary.json')
        require(read(folder+'returncode') == '0', mode+' runner return code')
        for doc in (summary, status):
            require(doc['mode'] == mode and doc['source_commit'] == expected and doc['status'] == 'PASS', mode+' metadata')
            require(all(x == 'PASS' for x in doc['gates'].values()) and len(doc['gates']) == 7, mode+' gates')
        require(status['summary'] == 'summary.json' and status['gates'] == summary['gates'], mode+' status consistency')
        require(summary['native'] == native and summary['cli'] == cli, mode+' embedded evidence consistency')
        require(summary['native_returncode'] == summary['cli_returncode'] == 0 and not summary['errors'], mode+' embedded return codes')
        require(native['status'] == 'PASS' and native['baseline'] is False, mode+' native scope')
        cases = native['cases']
        invalid = [name for name in cases if '_invalid_' in name]
        nonfinite = [name for name in cases if '_invalid_nonfinite_' in name]
        fine = [name for name in cases if name.endswith('_fine41')]
        require(native['case_count'] == len(cases) == 140, mode+' native case count')
        require(len(invalid) == 46 and len(nonfinite) == 28 and len(fine) == 2, mode+' required case families')
        require(all(item['status'] == 'PASS' for item in cases.values()), mode+' native case failure')
        require(len(cli['cases']) == 8 and cli['status'] == 'PASS' and not cli['failures'], mode+' CLI case count/status')
        require(all(item['status'] == 'PASS' for item in cli['cases'].values()), mode+' CLI case failure')
        for name in fine:
            lines = (base/folder/'native'/name/'stdout.txt').read_text().splitlines()
            row_count = sum(line.startswith('ROW ') for line in lines)
            require(row_count == 41, mode+'/'+name+' must publish 41 actual rows')
            report = next(line.split() for line in lines if line.startswith('REPORT '))
            require(report[1:5] == ['10','41','41','1'], mode+'/'+name+' accounting')
        require(not native['refinement_failures'] and all(x['status']=='PASS' for x in native['refinements']), mode+' refinement')
        require(all(x['status']=='PASS' for x in native['publication_independence']), mode+' publication independence')
        provenance = read(folder+'provenance.txt')
        require('baseline=0' in provenance and 'source_commit='+expected in provenance, mode+' provenance identity')
        legacy_cmd = read('integrated/ST41/logs/legacy-'+mode+'.command.txt')
        require('make' in legacy_cmd and 'MODE='+mode in legacy_cmd and ' test' in legacy_cmd, mode+' legacy execution route')
        facts['modes'][mode] = {'native_cases':len(cases),'valid_cases':len(cases)-len(invalid),
                               'invalid_cases':len(invalid),'nonfinite_input_cases':len(nonfinite),
                               'fine41_cases':len(fine),'cli_cases':len(cli['cases']),
                               'gates':summary['gates'],'refinement_metrics':len(native['refinements'])}
    require(sorted(p.name for p in (base/'integrated/REV').iterdir() if p.is_dir()) == ['debug','release'], 'duplicate REV run directories')
    require(read('integrated/logs/REV-summary-gates.command.txt') == 'collect_rev_gates', 'REV aggregate reruns solver')
    result = read('integrated/result.txt')
    for value in ('AVAILABLE_EXECUTED_CONTROLS=PASS','A02_GLOBAL=NOT_QUALIFIED',
                  'A02_THREE_NODE_GLOBAL_FORMULATION=NOT_QUALIFIED','A07_GLOBAL=NOT_QUALIFIED',
                  'A07_ACTIVE_GYRO_RUNUP_RUNDOWN=NOT_QUALIFIED','HISTORICAL_ST41=BLOCKED'):
        require(value in result, 'scope missing: '+value)
    directed = data('after_directed/directed_summary.json')
    require(directed['status'] == 'PASS' and not directed['failures'], 'original directed review')
    facts['directed_results'] = directed['results']
    facts['counting_scope'] = ('140 native + 8 CLI corpus cases per profile; 296 corpus cases summed across two profiles, '
                               'not 296 distinct physical scenarios. Native fill controls and derived comparisons are '
                               'reported separately. Aggregate and ST41 wrapper rows are not additional REV cases.')
except (OSError, ValueError, KeyError, TypeError, StopIteration) as exc:
    errors.append(type(exc).__name__ + ': ' + str(exc))

print(json.dumps({'status':'PASS' if not errors else 'FAIL','source_commit':expected,
                  'scope':'Read-only evidence audit; no compilation or solver execution',
                  'errors':errors,'facts':facts}, indent=2, allow_nan=False))
sys.exit(bool(errors))
