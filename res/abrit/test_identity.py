"""Check generated MSI identities and matching native/runner namespaces."""
import importlib.util
from pathlib import Path
import re
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("msi_preprocess", ROOT / "res/msi/preprocess.py")
MSI = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MSI)


class IdentityTests(unittest.TestCase):
    def test_native_flutter_and_locked_release_versions_match(self):
        manifest = (ROOT / "Cargo.toml").read_text(encoding="utf-8")
        version = re.search(r'^version\s*=\s*"([^"]+)"', manifest, re.M).group(1)
        lock = (ROOT / "Cargo.lock").read_text(encoding="utf-8")
        locked = re.search(r'name = "rustdesk"\nversion = "([^"]+)"', lock).group(1)
        self.assertEqual(locked, version, "cargo --locked must accept the release version")
        flutter = (ROOT / "flutter/pubspec.yaml").read_text(encoding="utf-8")
        self.assertEqual(re.search(r'^version:\s*([^+\s]+)', flutter, re.M).group(1), version)
        workflow = (ROOT / ".github/workflows/flutter-build.yml").read_text(encoding="utf-8")
        self.assertEqual(re.search(r'^  VERSION:\s*"([^"]+)"', workflow, re.M).group(1), version)

    def test_msi_upgrade_identity_is_stable_and_different_from_rustdesk(self):
        args = MSI.make_parser().parse_args([])
        self.assertEqual(args.app_name, "AbritDesk")
        identities = []
        for name in ["AbritDesk", "AbritDesk", "RustDesk"]:
            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                shutil.copytree(ROOT / "res/msi/Package", root / "Package")
                args.app_name = name
                with patch.object(sys, "argv", [str(root / "preprocess.py")]):
                    self.assertTrue(MSI.gen_pre_vars(args, root / "dist"))
                text = (root / "Package/Includes.wxi").read_text(encoding="utf-8")
                self.assertIn(f'Product="{name}"', text)
                identity = re.search(r'UpgradeCode = "([^"]+)"', text).group(1)
                self.assertEqual(uuid.UUID(identity), uuid.uuid5(uuid.NAMESPACE_OID, name + ".exe"))
                identities.append(identity)
        self.assertEqual(identities[0], identities[1])
        self.assertNotEqual(identities[0], identities[2])

    def test_custom_msi_components_do_not_reuse_stock_component_guids(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            shutil.copytree(ROOT / "res/msi/Package", root / "Package")
            pattern = re.compile(r'Component.+Guid="([^"]+)"')
            before = {m for file in (root / "Package").rglob("*.wxs") for m in pattern.findall(file.read_text(encoding="utf-8"))}
            with patch.object(sys, "argv", [str(root / "preprocess.py")]):
                MSI.replace_component_guids_in_wxs()
            after = {m for file in (root / "Package").rglob("*.wxs") for m in pattern.findall(file.read_text(encoding="utf-8"))}
            self.assertTrue(before)
            self.assertEqual(len(before), len(after))
            self.assertFalse(before & after)

    def test_native_runner_and_helpers_use_matching_namespaces(self):
        native = (ROOT / "src/platform/windows.rs").read_text(encoding="utf-8")
        runner = (ROOT / "flutter/windows/runner/win32_window.cpp").read_text(encoding="utf-8")
        namespace = "ABRITDESK_FLUTTER_RUNNER_WIN32_WINDOW"
        self.assertIn(f'"{namespace}"', native)
        self.assertIn(f'L"{namespace}"', runner)
        broker = "RuntimeBroker_abritdesk.exe"
        for file in ["src/privacy_mode/win_topmost_window.rs", "libs/portable/src/main.rs",
                     "res/msi/CustomActions/CustomActions.cpp", "res/msi/Package/Components/RustDesk.wxs"]:
            text = (ROOT / file).read_text(encoding="utf-8")
            self.assertIn(broker, text)
            self.assertNotIn("RuntimeBroker_rustdesk.exe", text)
        self.assertNotIn("54E86BC2-6C85-41F3-A9EB-1A94AC9B1F93", native)
        self.assertNotIn('get_subkey("RustDesk"', native)

    def test_msi_printer_uses_internal_identity_instead_of_display_brand(self):
        import xml.etree.ElementTree as ET
        root = ET.parse(ROOT / "res/msi/Package/Components/RustDesk.wxs").getroot()
        namespace = {"w": "http://wixtoolset.org/schemas/v4/wxs"}
        actions = {node.attrib["Id"]: node.attrib for node in root.findall(".//w:CustomAction", namespace)}
        self.assertEqual(actions["InstallPrinter.SetParam"]["Value"], "$(var.Product)|[INSTALLFOLDER_INNER]")
        self.assertEqual(actions["UninstallPrinter.SetParam"]["Value"], "$(var.Product)")


if __name__ == "__main__":
    unittest.main()
