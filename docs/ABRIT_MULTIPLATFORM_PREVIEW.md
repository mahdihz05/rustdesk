# AbritDesk 1.0.0 Multiplatform Preview

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
