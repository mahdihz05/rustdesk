"""Test the real Abrit presentation widgets without the Rust FFI build.

Usage: python res/abrit/check_ui.py --flutter-sdk path/to/flutter
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def check(sdk):
    dart = sdk / "bin/cache/dart-sdk/bin" / ("dart.exe" if os.name == "nt" else "dart")
    cli = sdk / "bin/cache/flutter_tools.snapshot"
    if not dart.is_file() or not cli.is_file():
        raise SystemExit("Initialize the Flutter SDK before running this check.")
    with tempfile.TemporaryDirectory(prefix="abrit-ui-") as directory:
        project = Path(directory)
        (project / "lib/abrit").mkdir(parents=True)
        (project / "test").mkdir()
        (project / "assets").mkdir()
        for source in (ROOT / "flutter/lib/abrit").glob("*.dart"):
            if source.name not in ("runtime.dart", "install_prompt.dart"):
                shutil.copy2(source, project / "lib/abrit" / source.name)
        shutil.copy2(ROOT / "flutter/test/abrit_layout_test.dart", project / "test")
        shutil.copytree(ROOT / "flutter/assets/abrit", project / "assets/abrit")
        (project / "pubspec.yaml").write_text("""name: flutter_hbb
environment:
  sdk: '>=3.5.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  window_manager:
    git:
      url: https://github.com/rustdesk-org/window_manager
      ref: cf4aef0512092fad9344a27ffe1c47ad83269dfc
  flutter_localizations:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
  assets:
    - assets/abrit/
  fonts:
    - family: Vazirmatn
      fonts:
        - asset: assets/abrit/Vazirmatn.ttf
        - asset: assets/abrit/Vazirmatn.ttf
          weight: 700
    - family: NotoSans
      fonts:
        - asset: assets/abrit/NotoSans.ttf
        - asset: assets/abrit/NotoSans.ttf
          weight: 700
""", encoding="utf-8")
        flutter = [str(dart), str(cli), "--suppress-analytics", "--no-version-check"]
        subprocess.run(flutter + ["pub", "get"], cwd=project, check=True)
        subprocess.run([str(dart), "analyze", "lib", "test"], cwd=project, check=True)
        subprocess.run(flutter + ["test", "--no-pub", "test/abrit_layout_test.dart",
                                  "--reporter", "expanded"], cwd=project, check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter-sdk", required=True, type=Path)
    check(parser.parse_args().flutter_sdk.resolve())
