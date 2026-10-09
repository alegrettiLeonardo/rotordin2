#!/usr/bin/env python3
"""Stage a traceable RotorDin2 delivery after qualification on an exact SHA.

Input is an explicit JSON manifest of already completed evidence and reports.
This script creates a new directory; it never resets or edits the repository.
ZIP construction and manifest verification use the previously qualified tool.
"""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile


def run(args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, stderr=subprocess.STDOUT)


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def safe_relative(name):
    p = Path(name)
    if p.is_absolute() or '..' in p.parts or not p.parts:
        raise ValueError(f'Invalid delivery destination: {name}')
    return p


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    repo = Path(config['repo']).resolve(strict=True)
    bundle_repo = Path(config.get('bundle_repo', config['repo'])).resolve(strict=True)
    stage = Path(config['stage']).absolute()
    restore = Path(config['restore']).absolute()
    expected = config['head']
    assert run(['git', 'rev-parse', 'HEAD'], repo).decode().strip() == expected
    assert run(['git', 'rev-parse', 'HEAD'], bundle_repo).decode().strip() == expected
    assert not run(['git', 'status', '--porcelain=v1'], bundle_repo).strip()
    assert not run(['git', 'status', '--porcelain=v1'], repo).strip()
    assert run(['git', 'branch', '--show-current'], repo).decode().strip() == 'fix/rotordin2-mathematical-reliability'
    for item in config['required_returncodes']:
        assert Path(item).read_text().strip() == '0', item
    for item in config.get('required_statuses', []):
        value = json.loads(Path(item['path']).read_text())
        for key in item.get('keys', ['status']):
            assert value[key] == 'PASS', (item['path'], key, value[key])
    stage.mkdir(parents=True, exist_ok=False)
    verify = stage / 'verification'
    verify.mkdir()
    solver = stage / 'solver'
    solver.mkdir()
    archive = run(['git', 'archive', '--format=tar', expected], repo)
    with tempfile.TemporaryFile() as stream:
        stream.write(archive)
        stream.seek(0)
        with tarfile.open(fileobj=stream) as tar:
            for member in tar.getmembers():
                safe_relative(member.name)
                assert member.isdir() or member.isfile(), member.name
            tar.extractall(solver, filter='data')
    exported = run(['git', 'ls-files', '-z'], repo).decode().split('\0')[:-1]
    for name in exported:
        assert (repo / name).read_bytes() == (solver / name).read_bytes(), name
    (verify / 'tracked_source.sha256').write_text(''.join(
        digest(solver / name) + '  solver/' + name + '\n' for name in exported))
    bundle = stage / 'rotordin2-history.bundle'
    # Use the preserved development repository for branch refs. A normal clone
    # only creates its selected local branch; rebundling just that clone would
    # turn the other branch names into remote refs and lose normal restore UX.
    run(['git', 'bundle', 'create', str(bundle), '--all'], bundle_repo)
    (verify / 'bundle_verify.log').write_bytes(run(['git', 'bundle', 'verify', str(bundle)], repo))
    assert not restore.exists()
    (verify / 'restore_clone.log').write_bytes(run([
        'git', 'clone', '--branch', 'fix/rotordin2-mathematical-reliability', str(bundle), str(restore)]))
    (verify / 'restore_fsck.log').write_bytes(run(['git', 'fsck', '--full'], restore))
    assert run(['git', 'rev-parse', 'HEAD'], restore).decode().strip() == expected
    assert run(['git', 'rev-parse', 'refs/remotes/origin/task/st41-priority-fixes'], restore).decode().strip() == '4d928f79c8daf0ad9ee67e4439e23e0e7c6b6f47'
    assert run(['git', 'rev-parse', 'refs/remotes/origin/checkpoint/reviewed-644b85a7a486'], restore).decode().strip() == '644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd'
    assert not run(['git', 'status', '--porcelain=v1'], restore).strip()
    for name in exported:
        assert (restore / name).read_bytes() == (solver / name).read_bytes(), name
        assert bool((restore / name).stat().st_mode & 0o111) == bool((solver / name).stat().st_mode & 0o111), name
    for destination, origin in config['copies'].items():
        src = Path(origin).resolve(strict=True)
        dst = stage / safe_relative(destination)
        assert not dst.exists(), dst
        dst.parent.mkdir(parents=True, exist_ok=True)
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    binary_records = []
    for item in config['binaries']:
        tested = Path(item['tested']).resolve(strict=True)
        native = repo / item['native']
        dst = stage / safe_relative(item['destination'])
        dst.parent.mkdir(parents=True, exist_ok=True)
        assert digest(tested) == digest(native), item
        shutil.copy2(tested, dst)
        binary_records.append({'path': item['destination'], 'sha256': digest(dst), 'tested_source_head': expected})
    (verify / 'source.diff').write_bytes(run(['git', 'diff', '644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd', expected], repo))
    (verify / 'commits.txt').write_bytes(run(['git', 'log', '--format=%H %s', '644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd..HEAD'], repo))
    (verify / 'refs.txt').write_bytes(run(['git', 'show-ref'], bundle_repo))
    result = {
        'status': 'PASS', 'head': expected,
        'tree': run(['git', 'rev-parse', 'HEAD^{tree}'], repo).decode().strip(),
        'reviewed_checkpoint': '644b85a7a486ae45ecdc5f575c8a2210f5ad6bfd',
        'clean_tracked_and_untracked_tree': True,
        'export_and_restored_bundle_identical_files': len(exported),
        'restored_executable_modes_identical': True,
        'bundle_sha256': digest(bundle), 'binaries': binary_records,
        'books_redistributed': False,
    }
    assert not any('project_sources' in p.parts for p in stage.rglob('*'))
    (verify / 'identity.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
