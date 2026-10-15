# AbritDesk 1.0.0 Multiplatform Preview

## Verified Build And Publication

- Source: `d01043acad2dde0b84650512517658130aac7de6`.
- Build: https://github.com/mahdihz05/rustdesk/actions/runs/38694937223
  completed with `success` on its first attempt.
- Release: https://github.com/mahdihz05/rustdesk/releases/tag/abritdesk-v1.0.0-multiplatform-preview.1
  is public, marked prerelease, and contains all seven packages plus
  `SHA256SUMS` and `release-manifest.json`.
- Both macOS jobs, both Linux jobs, all three Android native jobs, universal APK
  assembly, Windows packaging/acceptance, and aggregate publication succeeded.
- Actual Linux artifacts were independently downloaded and extracted. Package
  version/name, ELF architectures, payload checksums, launchers and service paths
  were checked for both architectures. x64 dependency resolution found no
  missing libraries in the test WSL environment; isolated `--version` returned
  `1.0.0` with exit code zero. No host package or service was installed.
- Linux x64 DEB SHA-256:
  `095f793f66d8d52863d01041422cdd7d1b5bb5ce8021e54b15b209a5c2b00545`.
- Linux ARM64 DEB SHA-256:
  `6405d6d594cc40cf2e69b247028ddfc2bf7dbea4ab1e4f9be19b216a30703a5d`.

macOS/Android device operation, ARM64 Linux execution, and public end-to-end
desktop connectivity are not established by these packaging checks.

## Scope

The `release-packages` input of Flutter Tag Build builds fresh Windows x64
portable EXE and MSI, macOS Intel and Apple Silicon DMGs, Linux x64 and ARM64
DEBs, and a universal Android APK. End-user packages are not ZIP archives.
Internal GitHub artifact transport may still use ZIP.

All required platform jobs must succeed before publication. The aggregate job
checks the exact seven-package set, records the source SHA and SHA-256 sums,
uploads a draft, downloads its assets for verification, and only then publishes
a prerelease. Failed builds do not publish a partial collection.

## Identity And Regression Surface

- `src/common.rs`, `src/flutter_ffi.rs`, and `src/service.rs` initialize the
  AbritDesk name before non-Windows configuration and service IPC. Existing
  Windows identity and portable password isolation are unchanged.
- Android uses application ID `ir.abrit.abritdesk` while retaining internal
  Kotlin/JNI namespaces. Existing RustDesk-scheme links remain supported.
- macOS product metadata and `build.py` agree on `AbritDesk.app`, its executable,
  helper service, and architecture-qualified DMG filenames.
- Linux Flutter CMake produces `abritdesk`; dedicated resources under
  `res/abritdesk` package its binary, service, launcher, and URL registration
  independently from stock RustDesk. Legacy Sciter folder packaging is retained.
- The workflows select only the requested packages and validate package
  metadata. Unsupported Flutter DRM packaging is disabled rather than scheduled
  into a known failure. Stock-path DRM, RPM, Arch, AppImage and Flatpak are not
  part of this preview.

## Validation And Limits

Local fixture tests cover both DEB architectures, metadata, ownership,
permissions, checksums, legacy packaging routing, and URL registration. Workflow
shell syntax, YAML, actionlint and aggregate-validator positive/negative cases
were checked before dispatch. These are not native compilation or device tests.

Without signing credentials, macOS packages are explicitly unsigned previews;
Android packages are explicitly debug-signed TEST APKs, not unsigned releases.
The Android test key is ephemeral and later updates may require uninstalling.

Public two-device connectivity is still not accepted: the preceding Windows
desktop E2E failed with `ID does not exist`. This package work does not repair
public rendezvous routing or the previously observed API certificate trust issue.
Do not describe packaging success as successful end-to-end remote control.
