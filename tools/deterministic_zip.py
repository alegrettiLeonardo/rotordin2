#!/usr/bin/env python3
"""Create and verify deterministic delivery ZIPs using only Python's stdlib.

The manifest covers every regular file except itself. ZIP-level SHA256 binds
the manifest, directory entries, permissions, and all ZIP metadata as well.
No archive is extracted by this utility. Requires Python 3.9 or newer.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath, PureWindowsPath
import shutil
import stat
import struct
import sys
import tempfile
import zipfile
import zlib


STAMP = (1980, 1, 1, 0, 0, 0)
CHUNK = 1024 * 1024
DEFAULT_MANIFEST = "SHA256SUMS"
METHODS = {"deflated": zipfile.ZIP_DEFLATED, "stored": zipfile.ZIP_STORED}


class PackageError(Exception):
    """An unsafe, inconsistent, or unverifiable package was rejected."""


def require(condition, message):
    if not condition:
        raise PackageError(message)


def safe_name(name, directory=False):
    """Validate an exact relative POSIX archive path without normalizing it."""
    require(isinstance(name, str) and name, "Empty package path")
    require(not any(ord(c) < 32 or ord(c) == 127 for c in name),
            "Control character in package path: " + repr(name))
    require("\\" not in name, "Backslash in package path: " + repr(name))
    require(not PureWindowsPath(name).drive, "Drive-qualified package path: " + repr(name))
    require(not name.startswith("/"), "Absolute package path: " + repr(name))
    value = name[:-1] if directory and name.endswith("/") else name
    require(value and all(p not in ("", ".", "..") for p in value.split("/")),
            "Noncanonical or traversing package path: " + repr(name))
    require(name == value + ("/" if directory else ""),
            "Incorrect directory suffix: " + repr(name))
    try:
        require(len(name.encode("utf-8")) <= 65535, "ZIP path exceeds 65535 bytes")
    except UnicodeEncodeError as exc:
        raise PackageError("Package paths must be valid UTF-8") from exc
    return value


def manifest_name(value):
    try:
        safe_name(value)
    except PackageError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc
    return value


def digest_stream(stream, target=None):
    digest = hashlib.sha256()
    size = 0
    while True:
        block = stream.read(CHUNK)
        if not block:
            break
        digest.update(block)
        size += len(block)
        if target is not None:
            target.write(block)
    return digest.hexdigest(), size


def digest_file(path):
    with open(path, "rb") as stream:
        return digest_stream(stream)[0]


def source_tree(source):
    given = Path(source).absolute()
    require(not given.is_symlink(), "The staging root must not be a symlink")
    root = given.resolve(strict=True)
    require(root.is_dir(), "The staging source must be a directory")
    entries = []

    def walk_error(error):
        raise PackageError("Cannot read complete staging tree: " + str(error)) from error

    for directory, dirs, files in os.walk(root, followlinks=False, onerror=walk_error):
        for name in sorted(dirs + files):
            path = Path(directory) / name
            mode = path.lstat().st_mode
            require(not stat.S_ISLNK(mode), "Symlink rejected: " + str(path))
            is_dir = stat.S_ISDIR(mode)
            require(is_dir or stat.S_ISREG(mode), "Special file rejected: " + str(path))
            relative = path.relative_to(root).as_posix() + ("/" if is_dir else "")
            safe_name(relative, is_dir)
            # Preserve the executable distinction, stripping host-specific
            # permission bits. Existing 0644/0755 files keep those modes.
            perms = 0o755 if is_dir or mode & 0o111 else 0o644
            entries.append((relative, path, is_dir, perms))
    entries.sort(key=lambda entry: entry[0].encode("utf-8"))
    return root, entries


def open_regular(path):
    flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        require(stat.S_ISREG(os.fstat(fd).st_mode), "Not a regular file: " + str(path))
        return os.fdopen(fd, "rb")
    except BaseException:
        os.close(fd)
        raise


def parse_manifest(data, name):
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise PackageError("Manifest must be UTF-8") from exc
    require(not text or text.endswith("\n"), "Manifest must end with LF")
    values = {}
    names = []
    for line in text.splitlines():
        require(len(line) >= 67 and line[64:66] == "  ", "Malformed SHA256 manifest line")
        digest, relative = line[:64], line[66:]
        require(all(c in "0123456789abcdef" for c in digest), "Invalid SHA256 digest")
        safe_name(relative)
        require(relative != name, "Manifest must not hash itself")
        require(relative not in values, "Duplicate manifest path: " + relative)
        names.append(relative)
        values[relative] = digest
    require(names == sorted(names, key=lambda x: x.encode("utf-8")), "Manifest paths are not sorted")
    return values


def write_manifest(source, name):
    safe_name(name)
    root, entries = source_tree(source)
    destination = root / name
    require(destination.parent.is_dir(), "Manifest parent directory must already exist")
    require(not destination.is_dir(), "Manifest path is a directory")
    lines = []
    for relative, path, is_dir, _ in entries:
        if not is_dir and relative != name:
            with open_regular(path) as stream:
                digest, _ = digest_stream(stream)
            lines.append(digest + "  " + relative + "\n")
    data = "".join(lines).encode("utf-8")
    fd, temporary = tempfile.mkstemp(prefix=".manifest-", dir=destination.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
        os.chmod(temporary, 0o644)
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    _, _, _, report = verify_source(root, name)
    return report


def verify_source(source, name):
    safe_name(name)
    root, entries = source_tree(source)
    files = {entry[0]: entry for entry in entries if not entry[2]}
    require(name in files, "Missing manifest: " + name)
    with open_regular(files[name][1]) as stream:
        manifest_data = stream.read()
    expected = parse_manifest(manifest_data, name)
    actual_names = set(files) - {name}
    require(set(expected) == actual_names,
            "Manifest coverage mismatch; missing entries=" + repr(sorted(actual_names - set(expected))) +
            "; absent files=" + repr(sorted(set(expected) - actual_names)))
    byte_count = 0
    for relative, path, is_dir, _ in entries:
        if is_dir:
            continue
        with open_regular(path) as stream:
            digest, size = digest_stream(stream)
        byte_count += size
        wanted = hashlib.sha256(manifest_data).hexdigest() if relative == name else expected[relative]
        require(digest == wanted, "SHA256 mismatch: " + relative)
    report = {"status": "PASS", "operation": "verify-stage", "source": str(root),
              "manifest": name, "manifest_sha256": hashlib.sha256(manifest_data).hexdigest(),
              "manifested_files": len(expected), "files": len(files),
              "directories": sum(entry[2] for entry in entries), "uncompressed_bytes": byte_count}
    expected[name] = report["manifest_sha256"]
    return root, entries, expected, report


def zip_info(name, directory, perms, method, size=0):
    info = zipfile.ZipInfo(name, date_time=STAMP)
    info.create_system = 3
    info.create_version = 20
    info.extract_version = 20
    info.internal_attr = 0
    info.external_attr = ((stat.S_IFDIR if directory else stat.S_IFREG) | perms) << 16
    if directory:
        info.external_attr |= 0x10
    info.compress_type = zipfile.ZIP_STORED if directory else method
    info.file_size = size
    info.extra = b""
    info.comment = b""
    return info


def write_zip_from_stage(destination, entries, expected, method):
    with zipfile.ZipFile(destination, "w", compression=method, allowZip64=True) as archive:
        archive.comment = b""
        for name, path, directory, perms in entries:
            if directory:
                archive.writestr(zip_info(name, True, perms, method), b"")
                continue
            with open_regular(path) as source:
                info = zip_info(name, False, perms, method, os.fstat(source.fileno()).st_size)
                with archive.open(info, "w") as target:
                    digest, size = digest_stream(source, target)
                require(digest == expected[name] and size == info.file_size,
                        "Staged file changed while packaging: " + name)


def allowed_extra(data):
    """The canonical writer may emit ZIP64 metadata for large archives."""
    while data:
        require(len(data) >= 4, "Truncated ZIP extra field")
        field, size = struct.unpack_from("<HH", data)
        require(field == 1 and len(data) >= 4 + size, "Unexpected ZIP extra field")
        data = data[4 + size:]


def verify_archive(path, name):
    safe_name(name)
    files = {}
    directories = 0
    byte_count = 0
    methods = set()
    with zipfile.ZipFile(path) as archive:
        require(archive.comment == b"", "Unexpected ZIP archive comment")
        infos = archive.infolist()
        names = [info.filename for info in infos]
        require(len(names) == len(set(names)), "Duplicate ZIP entries")
        require(names == sorted(names, key=lambda x: x.encode("utf-8")), "ZIP entries are not sorted")
        require(name in names, "ZIP manifest is missing: " + name)
        file_names = {info.filename for info in infos if not info.is_dir()}
        for info in infos:
            directory = info.is_dir()
            base = safe_name(info.orig_filename, directory)
            require(info.orig_filename == info.filename, "ZIP filename was normalized by the reader")
            require(not any(parent.as_posix() in file_names for parent in PurePosixPath(base).parents),
                    "File/directory conflict in ZIP: " + base)
            require(not directory or base not in file_names, "File/directory conflict in ZIP: " + base)
            require(info.date_time == STAMP and info.create_system == 3, "Unexpected ZIP time or platform")
            require(not info.flag_bits & 1, "Encrypted ZIP entries are not accepted")
            mode = info.external_attr >> 16
            perms = stat.S_IMODE(mode)
            require((stat.S_ISDIR(mode) and directory and perms == 0o755) or
                    (stat.S_ISREG(mode) and not directory and perms in (0o644, 0o755)),
                    "Unsafe or noncanonical ZIP file mode: " + info.filename)
            require(info.comment == b"", "Unexpected ZIP entry comment")
            allowed_extra(info.extra)
            require(info.compress_type in METHODS.values(), "Unsupported ZIP compression")
            if directory:
                directories += 1
                require(info.file_size == 0 and info.compress_type == zipfile.ZIP_STORED,
                        "Directory entry has content or compression")
                continue
            methods.add(info.compress_type)
            with archive.open(info) as stream:
                digest, size = digest_stream(stream)
            require(size == info.file_size, "ZIP entry size mismatch: " + info.filename)
            files[info.filename] = digest
            byte_count += size
        require(len(methods) <= 1, "ZIP regular files use inconsistent compression methods")
        data = archive.read(name)
        expected = parse_manifest(data, name)
        require(set(expected) == set(files) - {name}, "ZIP manifest does not cover exactly every other file")
        for relative, digest in expected.items():
            require(files[relative] == digest, "ZIP SHA256 mismatch: " + relative)
    return {"status": "PASS", "operation": "verify-archive", "archive": str(Path(path).resolve()),
            "archive_sha256": digest_file(path), "archive_bytes": Path(path).stat().st_size,
            "manifest": name, "manifest_sha256": files[name], "manifested_files": len(expected),
            "files": len(files), "directories": directories, "uncompressed_bytes": byte_count}


def identical_files(first, second):
    if Path(first).stat().st_size != Path(second).stat().st_size:
        return False
    with open(first, "rb") as a, open(second, "rb") as b:
        while True:
            block = a.read(CHUNK)
            if block != b.read(CHUNK):
                return False
            if not block:
                return True


def check_repack(path, name):
    """Rebuild directly from verified ZIP streams, without extracting files."""
    report = verify_archive(path, name)
    fd, temporary = tempfile.mkstemp(prefix=".repack-", suffix=".zip", dir=Path(path).resolve().parent)
    os.close(fd)
    try:
        with zipfile.ZipFile(path) as original, zipfile.ZipFile(temporary, "w", allowZip64=True) as repack:
            for old in original.infolist():
                info = zip_info(old.filename, old.is_dir(), stat.S_IMODE(old.external_attr >> 16),
                                old.compress_type, old.file_size)
                if old.is_dir():
                    repack.writestr(info, b"")
                else:
                    with original.open(old) as source, repack.open(info, "w") as target:
                        shutil.copyfileobj(source, target, CHUNK)
        require(identical_files(path, temporary), "Repack differs byte-for-byte from the original ZIP")
        report["byte_identical_repack"] = "PASS"
        report["repack_sha256"] = digest_file(temporary)
        return report
    finally:
        os.unlink(temporary)


def build_archive(source, output, name, compression, repack):
    root, entries, expected, stage_report = verify_source(source, name)
    given = Path(output).absolute()
    require(not given.is_symlink(), "Output must not be a symlink")
    destination = given.resolve()
    require(not destination.is_relative_to(root), "ZIP output must be outside the staged directory")
    require(destination.parent.is_dir(), "Output parent directory must already exist")
    require(not destination.exists(), "ZIP output already exists; choose a new output path")
    fd, temporary = tempfile.mkstemp(prefix=".package-", suffix=".zip", dir=destination.parent)
    os.close(fd)
    try:
        write_zip_from_stage(temporary, entries, expected, METHODS[compression])
        _, final_entries, final_expected, _ = verify_source(root, name)
        require([(e[0], e[2], e[3]) for e in final_entries] == [(e[0], e[2], e[3]) for e in entries]
                and final_expected == expected, "Staged package changed during the build")
        report = check_repack(temporary, name) if repack else verify_archive(temporary, name)
        require(report["manifest_sha256"] == stage_report["manifest_sha256"], "Archive manifest changed")
        os.chmod(temporary, 0o644)
        # Same-directory hard link publishes atomically and cannot overwrite
        # an output that appeared concurrently. The temporary link is removed.
        os.link(temporary, destination)
        report.update(operation="build", archive=str(destination), compression=compression,
                      fixed_timestamp="1980-01-01T00:00:00", python=sys.version.split()[0],
                      zlib_runtime=zlib.ZLIB_RUNTIME_VERSION)
        return report
    finally:
        os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for command in ("manifest", "verify", "build", "verify-archive"):
        child = commands.add_parser(command)
        child.add_argument("source", help="Staged directory, or ZIP for verify-archive")
        child.add_argument("--manifest", default=DEFAULT_MANIFEST, type=manifest_name)
        if command == "build":
            child.add_argument("output", help="New ZIP path outside the staged directory")
            child.add_argument("--compression", choices=METHODS, default="deflated")
        if command in ("build", "verify-archive"):
            child.add_argument("--check-repack", action="store_true")
        if command == "verify-archive":
            child.add_argument("--expected-sha256", help="Optional externally recorded ZIP SHA256")
    args = parser.parse_args()
    try:
        if args.command == "manifest":
            report = write_manifest(args.source, args.manifest)
            report["operation"] = "manifest"
        elif args.command == "verify":
            report = verify_source(args.source, args.manifest)[3]
        elif args.command == "build":
            report = build_archive(args.source, args.output, args.manifest, args.compression, args.check_repack)
        else:
            report = check_repack(args.source, args.manifest) if args.check_repack else verify_archive(args.source, args.manifest)
            if args.expected_sha256:
                require(report["archive_sha256"] == args.expected_sha256.lower(), "External ZIP SHA256 mismatch")
        print(json.dumps(report, indent=2, sort_keys=True))
    except (PackageError, OSError, ValueError, zipfile.BadZipFile, RuntimeError, zlib.error, EOFError) as exc:
        print(json.dumps({"status": "FAIL", "operation": args.command, "reason": str(exc)}, sort_keys=True),
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
