#!/usr/bin/env python3
"""Verify and restore an abritdesk transfer onto a fresh Ubuntu server."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import sqlite3
import subprocess


def verify(root):
    metadata = json.loads((root / 'transfer-manifest.json').read_text(encoding='utf-8'))
    if metadata.get('format') != 1 or metadata.get('domain') != 'serverdesk.abrit.cloud':
        raise SystemExit('Unsupported transfer format or unexpected domain')
    for relative, expected in metadata['files'].items():
        target = (root / relative).resolve()
        if not target.is_relative_to(root) or target.is_symlink() or not target.is_file():
            raise SystemExit(f'Unsafe or missing transfer file: {relative}')
        if hashlib.sha256(target.read_bytes()).hexdigest() != expected:
            raise SystemExit(f'Transfer checksum mismatch: {relative}')
    actual = {str(path.relative_to(root)) for path in root.rglob('*') if path.is_file() and path.name != 'transfer-manifest.json'}
    if actual != set(metadata['files']):
        raise SystemExit('Unexpected or missing files in transfer directory')
    for relative in ('payload/var/lib/rustdesk-server/db_v2.sqlite3', 'payload/var/lib/abrit-control/control.sqlite3'):
        with sqlite3.connect((root / relative).as_uri() + '?mode=ro', uri=True) as database:
            if database.execute('PRAGMA quick_check').fetchone()[0] != 'ok':
                raise SystemExit(f'Invalid database: {relative}')
    key = root / 'payload/var/lib/rustdesk-server/id_ed25519.pub'
    if hashlib.sha256(key.read_bytes()).hexdigest() != metadata['server_public_key_sha256']:
        raise SystemExit('Server identity does not match transfer manifest')
    return metadata


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory')
    parser.add_argument('--restore', action='store_true', help='Install on a fresh Ubuntu 24.04 x86_64 server')
    args = parser.parse_args()
    root = Path(args.directory).resolve()
    verify(root)
    print('All application files, both database snapshots and server identity verified')
    if not args.restore:
        return
    if os.geteuid() != 0 or platform.machine() != 'x86_64':
        raise SystemExit('Restore requires root on Ubuntu 24.04 x86_64')
    release = Path('/etc/os-release').read_text()
    if 'ID=ubuntu' not in release or 'VERSION_ID="24.04"' not in release:
        raise SystemExit('Use Ubuntu 24.04 for this transfer bundle')
    for destination in ('/opt/abrit-control', '/var/lib/abrit-control', '/var/lib/rustdesk-server', '/etc/abrit-control'):
        if Path(destination).exists():
            raise SystemExit(f'Refusing to overwrite an existing application: {destination}')
    for unit in ('rustdesk-hbbs', 'rustdesk-hbbr', 'abrit-control'):
        if subprocess.run(['systemctl', 'is-active', '--quiet', unit]).returncode == 0:
            raise SystemExit(f'Refusing to replace a running application service: {unit}')
    payload = root / 'payload'
    for relative in ('opt/abrit-control', 'etc/abrit-control', 'var/lib/abrit-control', 'var/lib/rustdesk-server'):
        destination = Path('/') / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(payload / relative, destination, copy_function=shutil.copy2)
    # Add the new local IPs for private panel access; preserve the domain and secrets.
    config_path = Path('/etc/abrit-control/config.json')
    config = json.loads(config_path.read_text())
    addresses = json.loads(subprocess.check_output(['ip', '-j', '-4', 'addr', 'show', 'scope', 'global']))
    hosts = config.get('TRUSTED_HOSTS', [])
    for interface in addresses:
        for address in interface.get('addr_info', []):
            if address['local'] not in hosts:
                hosts.append(address['local'])
    config['TRUSTED_HOSTS'] = hosts
    config_path.write_text(json.dumps(config), encoding='utf-8')
    config_path.chmod(0o640)
    for name in ('hbbs', 'hbbr'):
        shutil.copy2(payload / 'usr/bin' / name, '/usr/bin/' + name)
        Path('/usr/bin/' + name).chmod(0o755)
        unit = 'rustdesk-' + name + '.service'
        shutil.copy2(payload / 'etc/systemd/system' / unit, '/etc/systemd/system/' + unit)
    for name, source in (('nginx-http.conf', 'abrit-control-http'), ('nginx-https.conf', 'abrit-control-https')):
        shutil.copy2(payload / 'etc/nginx/sites-available' / source, Path('/opt/abrit-control/deploy') / name)
    subprocess.run(['/bin/sh', '/opt/abrit-control/deploy/install.sh'], check=True)
    subprocess.run(['chown', '-R', 'abrit-control:abrit-control', '/var/lib/abrit-control'], check=True)
    subprocess.run(['chown', 'root:abrit-control', '/etc/abrit-control/config.json'], check=True)
    subprocess.run(['systemctl', 'daemon-reload'], check=True)
    subprocess.run(['systemctl', 'enable', '--now', 'rustdesk-hbbs', 'rustdesk-hbbr'], check=True)
    subprocess.run(['systemctl', 'restart', 'abrit-control'], check=True)
    print('Application restored with the original server keys and panel accounts. Verify it before changing DNS.')
    print('SSH accounts, OS passwords, SSH host keys, DNS and firewall settings were not changed.')


if __name__ == '__main__':
    main()
