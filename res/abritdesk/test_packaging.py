#!/usr/bin/env python3
"""Linux packaging smoke test using fixture bundles, not compiled applications."""
import hashlib
import importlib.util
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('native_build', ROOT / 'build.py')
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class NativePackagingTest(unittest.TestCase):
    def test_folder_packaging_dispatch(self):
        with tempfile.TemporaryDirectory(prefix='abritdesk-routing-') as temporary:
            bundle = Path(temporary)
            (bundle / 'rustdesk').write_bytes(b'fixture Sciter executable')
            with patch.object(build, 'build_abrit_deb') as abrit, \
                    patch.object(build.os, 'chdir', side_effect=RuntimeError('legacy packaging path')):
                for want_drm in (False, True):
                    with self.subTest(want_drm=want_drm), self.assertRaisesRegex(
                            RuntimeError, 'legacy packaging path'):
                        build.build_deb_from_folder('1.0.0', temporary, want_drm)
                abrit.assert_not_called()
                (bundle / 'abritdesk').write_bytes(b'not yet a Flutter bundle')
                with self.assertRaisesRegex(RuntimeError, 'legacy packaging path'):
                    build.build_deb_from_folder('1.0.0', temporary)
                abrit.assert_not_called()
                (bundle / 'lib').mkdir()
                (bundle / 'lib/librustdesk.so').write_bytes(b'fixture FFI library')
                build.build_deb_from_folder('1.0.0', temporary)
                abrit.assert_called_once_with('1.0.0', temporary)
                abrit.reset_mock()
                with self.assertRaisesRegex(ValueError, 'does not support --drm'):
                    build.build_deb_from_folder('1.0.0', temporary, True)
                abrit.assert_not_called()

    def test_macos_build_paths(self):
        with patch.object(build, 'skip_cargo', True), patch.object(build.os, 'chdir'), \
                patch.object(build, 'system2') as command, \
                patch.object(build.platform, 'machine', return_value='arm64'):
            build.build_flutter_dmg('1.0.0', 'flutter')
        commands = '\n'.join(call.args[0] for call in command.call_args_list)
        self.assertIn('AbritDesk.app/Contents/MacOS/', commands)
        self.assertIn('abritdesk-1.0.0-macos-arm64.dmg', commands)
        self.assertIn('target/release/liblibrustdesk.dylib', commands)
        self.assertNotIn('RustDesk.app', commands)
        self.assertNotIn('.zip', commands)

    def test_macos_metadata(self):
        macos = ROOT / 'flutter/macos'
        info = plistlib.loads((macos / 'Runner/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleName'], 'AbritDesk')
        self.assertEqual(info['CFBundleDisplayName'], 'AbritDesk')
        self.assertEqual(info['CFBundleExecutable'], '$(EXECUTABLE_NAME)')
        self.assertEqual(set(info['CFBundleURLTypes'][0]['CFBundleURLSchemes']),
                         {'abritdesk', 'rustdesk'})
        config = (macos / 'Runner/Configs/AppInfo.xcconfig').read_text()
        self.assertIn('PRODUCT_NAME = AbritDesk', config)
        project = (macos / 'Runner.xcodeproj/project.pbxproj').read_text()
        self.assertNotIn('RustDesk.app', project)
        self.assertEqual(project.count('PRODUCT_BUNDLE_IDENTIFIER = com.carriez.abritdesk;'), 3)
        scheme = ET.parse(macos / 'Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme')
        for reference in scheme.findall('.//BuildableReference'):
            self.assertEqual(reference.get('BuildableName'), 'AbritDesk.app')
        nib = ET.parse(macos / 'Runner/Base.lproj/MainMenu.xib')
        for node in nib.iter():
            if node.get('customModule'):
                self.assertEqual(node.get('customModule'), 'AbritDesk')

    @unittest.skipUnless(shutil.which('dpkg-deb'), 'requires Linux dpkg-deb')
    def test_deb_packages(self):
        with tempfile.TemporaryDirectory(prefix='abritdesk-test-') as temporary:
            root = Path(temporary)
            (root / 'res').mkdir()
            shutil.copytree(ROOT / 'res/abritdesk', root / 'res/abritdesk')
            for icon in ('128x128@2x.png', 'scalable.svg'):
                shutil.copyfile(ROOT / 'res' / icon, root / 'res' / icon)
            bundle = root / 'bundle'
            (bundle / 'lib').mkdir(parents=True)
            (bundle / 'abritdesk').write_bytes(b'fixture executable')
            core = bundle / 'lib/librustdesk.so'
            core.write_bytes(b'fixture FFI library')
            with patch.object(build, 'REPO_ROOT', str(root)):
                for arch, label in (('amd64', 'x64'), ('arm64', 'arm64')):
                    with self.subTest(arch=arch), patch.dict(os.environ, DEB_ARCH=arch):
                        build.build_abrit_deb('1.0.0', bundle)
                        deb = root / f'abritdesk-1.0.0-linux-{label}.deb'
                        fields = subprocess.check_output(
                            ['dpkg-deb', '-f', str(deb)], text=True)
                        self.assertIn('Package: abritdesk\n', fields)
                        self.assertIn('Version: 1.0.0\n', fields)
                        self.assertIn(f'Architecture: {arch}\n', fields)
                        listing = subprocess.check_output(['dpkg-deb', '-c', str(deb)], text=True)
                        for line in listing.splitlines():
                            self.assertEqual(line.split()[1], 'root/root')
                        for field in ('Conflicts:', 'Replaces:', 'Provides:'):
                            self.assertNotIn(field, fields)
                        extracted = root / arch
                        subprocess.check_call(['dpkg-deb', '-R', str(deb), str(extracted)])
                        self.assertEqual(os.readlink(extracted / 'usr/bin/abritdesk'),
                                         '/usr/share/abritdesk/abritdesk')
                        self.assertEqual((extracted / 'usr/share/abritdesk/abritdesk').stat().st_mode & 0o777,
                                         0o755)
                        for path in extracted.rglob('*'):
                            self.assertNotIn('rustdesk', path.relative_to(extracted).parts)
                        for name in ('postinst', 'prerm', 'postrm'):
                            script = extracted / 'DEBIAN' / name
                            self.assertEqual(script.stat().st_mode & 0o777, 0o755)
                            self.assertNotIn('rustdesk', script.read_text())
                            subprocess.check_call(['sh', '-n', str(script)])
                        subprocess.check_call(['desktop-file-validate', str(
                            extracted / 'usr/share/applications/abritdesk.desktop')])
                        desktop = (extracted / 'usr/share/applications/abritdesk.desktop').read_text()
                        self.assertIn('MimeType=x-scheme-handler/rustdesk;\n', desktop)
                        self.assertIn('Exec=abritdesk %u\n', desktop)
                        service = (extracted / 'usr/lib/systemd/system/abritdesk.service').read_text()
                        self.assertIn('ExecStart=/usr/bin/abritdesk --service', service)
                        self.assertNotIn('rustdesk', service)
                        for line in (extracted / 'DEBIAN/md5sums').read_text().splitlines():
                            digest, filename = line.split('  ', 1)
                            self.assertEqual(hashlib.md5((extracted / filename).read_bytes()).hexdigest(), digest)
                with patch.dict(os.environ, DEB_ARCH='armhf'), self.assertRaises(ValueError):
                    build.build_abrit_deb('1.0.0', bundle)
                core.write_bytes(build.DRMTAP_DLOPEN_MARKER)
                with patch.dict(os.environ, DEB_ARCH='amd64'), self.assertRaises(ValueError):
                    build.build_abrit_deb('1.0.0', bundle)


if __name__ == '__main__':
    unittest.main()
