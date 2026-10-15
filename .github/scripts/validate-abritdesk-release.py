"""Accept exactly the seven current-run preview packages and record their provenance."""

import hashlib
import json
import os
from pathlib import Path
import re
import sys


def validate(directory):
    version = os.environ['VERSION']
    sha = os.environ['GITHUB_SHA']
    if not re.fullmatch(r'[0-9a-f]{40,64}', sha):
        raise ValueError('Invalid source SHA')
    windows_signed = os.environ['WINDOWS_SIGNED'] == 'true'
    macos_signed = os.environ['MACOS_SIGNED'] == 'true'
    android_signed = os.environ['ANDROID_SIGNED'] == 'true'
    prefix = f'abritdesk-{version}'
    mac_suffix = '' if macos_signed else '-unsigned-preview'
    android_suffix = '' if android_signed else '-debug-signed-TEST'
    expected = {
        f'{prefix}-x86_64.exe': b'MZ',
        f'{prefix}-x86_64.msi': bytes.fromhex('d0cf11e0a1b11ae1'),
        f'{prefix}-macos-x86_64{mac_suffix}.dmg': b'koly',
        f'{prefix}-macos-arm64{mac_suffix}.dmg': b'koly',
        f'{prefix}-linux-x64.deb': b'!<arch>\n',
        f'{prefix}-linux-arm64.deb': b'!<arch>\n',
        f'{prefix}-universal{android_suffix}.apk': b'PK\x03\x04',
    }
    root = Path(directory)
    actual = {path.name for path in root.iterdir()}
    if actual != expected.keys():
        raise ValueError(f'Incorrect release set: missing={expected.keys() - actual}, extra={actual - expected.keys()}')
    files = []
    for name, magic in sorted(expected.items()):
        path = root / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f'Not a nonempty regular package: {name}')
        with path.open('rb') as package:
            if path.suffix == '.dmg':
                package.seek(-512, 2)
            if package.read(len(magic)) != magic:
                raise ValueError(f'Invalid package format: {name}')
            package.seek(0)
            digest = hashlib.sha256()
            for chunk in iter(lambda: package.read(1024 * 1024), b''):
                digest.update(chunk)
        files.append({'name': name, 'size': path.stat().st_size, 'sha256': digest.hexdigest()})
    run_url = f"{os.environ['GITHUB_SERVER_URL']}/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
    caveats = [
        'Preview packaging acceptance is not a substitute for end-user platform testing.',
        'Public two-device desktop connectivity is not accepted: the previous Windows E2E still failed with ID does not exist. These packages do not claim to fix public rendezvous routing or API certificate trust.',
        ('Windows signing service was used; OS trust was not independently verified.' if windows_signed
         else 'Windows EXE/MSI are unsigned previews; SmartScreen may block execution.'),
        ('macOS bundles and DMGs were codesigned and notarized by the build.' if macos_signed
         else 'macOS DMGs are unsigned and not notarized; Gatekeeper may block installation.'),
        ('Android APK uses the configured release signing key.' if android_signed
         else 'Android TEST APK is debug-signed, not unsigned or production-signed. The ephemeral key may require uninstalling before future previews.'),
        'Android application ID is ir.abrit.abritdesk; minimum Android API is 22 (native API 21 builds remain compatible).',
        'Linux DEBs do not carry a repository/package signature; verify SHA-256 checksums.',
    ]
    manifest = {
        'version': version, 'source_sha': sha, 'repository': os.environ['GITHUB_REPOSITORY'],
        'run_url': run_url, 'run_attempt': os.environ['GITHUB_RUN_ATTEMPT'],
        'acceptance': 'All required platform jobs succeeded; exact seven-package set validated.',
        'files': files, 'signature_caveats': caveats,
    }
    output = Path('release-metadata')
    output.mkdir(exist_ok=True)
    manifest_path = output / 'release-manifest.json'
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    checksums = [f"{item['sha256']}  {item['name']}" for item in files]
    checksums.append(f'{hashlib.sha256(manifest_path.read_bytes()).hexdigest()}  release-manifest.json')
    (output / 'SHA256SUMS').write_text('\n'.join(checksums) + '\n', encoding='ascii')
    notes = [f'# AbritDesk {version} Preview', '', f'Source SHA: `{sha}`',
             f'Build: {run_url} (attempt {manifest["run_attempt"]})', '', manifest['acceptance'], '',
             '## Exact Package Set', '', *[f'- `{item["name"]}`' for item in files], '',
             '## Signature Caveats', '', *[f'- {caveat}' for caveat in caveats], '',
             'Use SHA256SUMS to verify packages; release-manifest.json records file sizes and source provenance.', '']
    (output / 'release-notes.md').write_text('\n'.join(notes), encoding='utf-8')


if __name__ == '__main__':
    validate(sys.argv[1])
