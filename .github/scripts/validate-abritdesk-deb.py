"""Inspect the actual DEB before uploading it, without installing or running it."""

import pathlib
import subprocess
import sys
import tempfile


def validate(package, version, arch):
    for field, expected in (("Package", "abritdesk"), ("Version", version), ("Architecture", arch)):
        actual = subprocess.check_output(
            ["dpkg-deb", "--field", package, field], text=True).strip()
        if actual != expected:
            raise ValueError(f"{field}: expected {expected!r}, got {actual!r}")
    subprocess.run(["dpkg-deb", "--info", package], check=True)
    subprocess.run(["dpkg-deb", "--contents", package], check=True)
    with tempfile.TemporaryDirectory(prefix="abritdesk-validation-") as directory:
        subprocess.run(["dpkg-deb", "--extract", package, directory], check=True)
        root = pathlib.Path(directory)
        for name in (
            "usr/share/abritdesk/abritdesk",
            "usr/share/abritdesk/lib/librustdesk.so",
            "usr/share/applications/abritdesk.desktop",
            "usr/lib/systemd/system/abritdesk.service",
        ):
            if not (root / name).is_file():
                raise ValueError(f"Missing payload: {name}")
        binary = root / "usr/share/abritdesk/abritdesk"
        if not binary.stat().st_mode & 0o111:
            raise ValueError("AbritDesk binary is not executable")
        link = root / "usr/bin/abritdesk"
        if not link.is_symlink() or str(link.readlink()) != "/usr/share/abritdesk/abritdesk":
            raise ValueError("Incorrect AbritDesk launcher symlink")
        for path in root.rglob("*"):
            if path.name in ("rustdesk", "rustdesk.service", "rustdesk.desktop") or path.name.startswith("libdrmtap"):
                raise ValueError(f"Incompatible stock/DRM payload: {path.relative_to(root)}")
        data = binary.read_bytes()
        machine = int.from_bytes(data[18:20], "little")
        if data[:4] != b"\x7fELF" or machine != {"amd64": 62, "arm64": 183}[arch]:
            raise ValueError("Binary ELF architecture does not match DEB metadata")


if __name__ == "__main__":
    validate(*sys.argv[1:])
