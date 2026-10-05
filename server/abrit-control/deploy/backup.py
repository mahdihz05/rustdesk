#!/usr/bin/env python3
"""Create a private, portable application backup without stopping connections."""
import argparse
from contextlib import closing
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tarfile
import tempfile
from zoneinfo import ZoneInfo


def snapshot(source, destination):
    with closing(sqlite3.connect(source.as_uri() + '?mode=ro', uri=True, timeout=20)) as current:
        with closing(sqlite3.connect(destination)) as backup:
            current.backup(backup)
            backup.execute('PRAGMA journal_mode=DELETE')
            if backup.execute('PRAGMA quick_check').fetchone()[0] != 'ok':
                raise RuntimeError(f'Invalid database snapshot: {source.name}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='/srv/abritdesk-transfer')
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise SystemExit('Run as root; private server keys are included')
    os.umask(0o077)
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    output.chmod(0o700)
    for source in ('/var/lib/rustdesk-server/id_ed25519', '/var/lib/rustdesk-server/id_ed25519.pub', '/etc/abrit-control/config.json'):
        if not Path(source).is_file():
            raise SystemExit(f'Required application file missing: {source}')
    with tempfile.TemporaryDirectory(prefix='abritdesk-transfer-') as temporary:
        root = Path(temporary)
        payload = root / 'payload'
        shutil.copytree('/opt/abrit-control', payload / 'opt/abrit-control',
                        ignore=shutil.ignore_patterns('.venv', '__pycache__', '*.pyc', '.git', 'config.json', 'data'))
        shutil.copytree('/etc/abrit-control', payload / 'etc/abrit-control')
        shutil.copytree('/var/lib/abrit-control/media', payload / 'var/lib/abrit-control/media')
        snapshot(Path('/var/lib/abrit-control/control.sqlite3'), payload / 'var/lib/abrit-control/control.sqlite3')
        server = payload / 'var/lib/rustdesk-server'
        server.mkdir(parents=True)
        for path in Path('/var/lib/rustdesk-server').iterdir():
            if path.is_file() and not path.name.startswith('db_v2.sqlite3'):
                shutil.copy2(path, server / path.name)
            elif path.is_dir():
                shutil.copytree(path, server / path.name)
        snapshot(Path('/var/lib/rustdesk-server/db_v2.sqlite3'), server / 'db_v2.sqlite3')
        binaries = payload / 'usr/bin'
        binaries.mkdir(parents=True)
        for name in ('hbbs', 'hbbr'):
            shutil.copy2('/usr/bin/' + name, binaries / name)
            unit = 'rustdesk-' + name + '.service'
            merged = subprocess.check_output(['systemctl', 'cat', unit])
            destination = payload / 'etc/systemd/system' / unit
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(merged)
        for name in ('abrit-control-http', 'abrit-control-https'):
            destination = payload / 'etc/nginx/sites-available' / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2('/etc/nginx/sites-available/' + name, destination)
        shutil.copy2('/opt/abrit-control/deploy/restore.py', root / 'restore.py')
        shutil.copy2('/opt/abrit-control/README.md', root / 'README.md')
        checksums = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
                     for path in root.rglob('*') if path.is_file()}
        metadata = {'format': 1, 'domain': 'serverdesk.abrit.cloud', 'os': 'Ubuntu 24.04 x86_64',
                    'contains_private_keys': True, 'files': checksums,
                    'server_public_key_sha256': hashlib.sha256((server / 'id_ed25519.pub').read_bytes()).hexdigest()}
        (root / 'transfer-manifest.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
        stamp = datetime.now(ZoneInfo('Asia/Tehran')).strftime('%Y%m%d-%H%M%S')
        archive = output / f'abritdesk-transfer-{stamp}.tar.gz'
        with tarfile.open(archive, 'x:gz') as bundle:
            for path in root.iterdir():
                bundle.add(path, arcname=path.name)
        archive.chmod(0o600)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        (output / (archive.name + '.sha256')).write_text(f'{digest}  {archive.name}\n', encoding='ascii')
        print(f'Private application backup: {archive}')
        print(f'SHA256: {digest}')
        print('Connection services stayed running. SSH accounts and network settings were not exported or changed.')


if __name__ == '__main__':
    main()
