# abritDesk Windows V1 preview

Scope: Windows x64 on `feat/abritdesk-v1-preview`. No upstream sync, server/protocol changes, web work or production signing.

## Profile and policy

`flutter/assets/abrit_config.json` is the single non-secret product profile. Rust compiles it into `src/abritdesk.rs` and reapplies it after Windows bootstrap and Flutter FFI initialization; Flutter reads it for control API origins. Rust's existing `OVERWRITE_SETTINGS` enforces ID/relay/key and an empty Pro API value. Defaults apply to portable, installed and service processes. The first-run marker preserves later language/theme choices, including selecting the system language. Non-Windows clients retain upstream startup behavior.

The Network page hides the entire ID/Relay/API/key card and server-settings entry for abritDesk. Both server-dialog entry points also return before loading or displaying those values. The compiled connection policy is unchanged. Existing admin permission mechanisms remain responsible for proxy and other network switches.

## UI and reference artwork

Home/Settings/Printer/History use the original DesktopTabController. Settings/Printer/History are permanent and Home is initially selected. The Printer page is the existing `_Printer`, exposed through a small factory; it has no duplicated backend or Settings sidebar entry. History uses PeerTabPage. Home uses RecentPeersView with a scoped three-column presentation. Real peer models, context menus, selection, online updates and connection actions are preserved.

The Windows install button closes subwindows and invokes `mainGotoInstall`; it disappears when installation is detected. Upgrade/system/permission warnings stay on Home. The title bar reuses the original tab renderer and WindowActionPanel, with LTR physical window controls and locale-aware tab contents. Existing remote-session tab paths are unchanged.

The October visual refinement adds larger main navigation, labeled destination input, left-to-right physical connection actions, stronger local-device typography and decorative artwork from text-free reference regions. The recent/active session area and its data/actions are unchanged. Native input controllers, copy/password actions and connection handlers remain in use.

Approved reference artwork is bundled unmodified as `assets/abrit_reference.png`. Only the logo and banner rectangles render; none of its mock IDs/passwords/peer names become application data. This is temporary preview artwork. Add final `logo_light.png`, `logo_dark.png`, `logo.png` and a standalone campaign banner before release. Existing loadLogo() remains supported; no replacement logo was invented. The platform launcher icon remains the existing RustDesk icon pending an approved AbrIT icon.

## Control API

GET `promotion`: schema/version 1, enabled, HTTPS image_url/target_url, alt, optional expires_at. Exact origin allowlist, no credentials/query identifiers, no redirects, six-second timeouts, 64 KiB metadata / 4 MiB images, image decoding validation. A local envelope stores metadata+image together. Invalid/expired cache is discarded. Offline/404/cache failures leave approved bundled artwork visible and do not affect remote connections. No session/customer/host/peer data is sent.

GET `update`: schema 1, semantic version strings, blocked_versions, force_after, approved HTTPS download_url, SHA-256, title/message. The client foundation parses/validates the manifest and returns null on error. **It does not download, execute, force updates or block old clients.** Installer hash verification, signed manifest trust, rollback and update UI are remaining release work. Standard upstream update checks/download prompts are disabled for the branded Windows product so they cannot replace it with an official RustDesk release. Existing upgrade of the currently running binary is retained.

## Validation

Windows x64 selects only its required legacy bridge through an optional reusable-workflow input; all other callers keep the existing two-version matrix. Windows workflow runs scoped Dart analysis, control-contract tests, native x64 compilation and produces `abritdesk-windows-x64-preview` with SHA256SUMS.txt. It attempts native Home captures at 1200x860 and 900x700 in `abritdesk-windows-ui-qa`. A headless/black capture is not evidence of visual success. Read smoke.json and inspect captures. No full connection or install success is claimed solely from compilation.

Remaining manual checks: portable installation/elevation; installed and lower-version upgrade; two actual clients connecting through the AbrIT server/key; copy/password visibility/refresh; Settings/Printer/History actions; light/dark and Windows DPI; language/system-language persistence; offline/404/expired promotion behavior; restart and retained server policy.

Native dependency caching uses vcpkg's file archive provider with pinned actions/cache v5. The removed x-gha provider and the older run-vcpkg internal cache (which returned HTTP 400) are disabled. Package ABI validation remains vcpkg's responsibility; the cache key includes the dependency manifest and overlays.

## Regression surface

- `src/lib.rs`, `src/core_main.rs`, `src/flutter_ffi.rs`: Windows-only product initialization hook, needed before service/client startup.
- `src/common.rs`: remove the former scattered product constants and prevent upstream update checks for this branded Windows build.
- `desktop_home_page.dart`: mount isolated AbrIT Home, preserve errors/upgrade/permissions, relocate only normal install affordance.
- `connection_page.dart`: reuse the ID/autocomplete/controllers/connect handlers; mount AbrIT layout/actions and asynchronous update foundation.
- `desktop_tab_page.dart`, `tabbar_widget.dart`: permanent navigation and branded main title bar only; remote-session renderer/actions preserved.
- `desktop_setting_page.dart`: direct existing Printer entry and visible enforced network values; existing settings pages remain.
- `mobile/widgets/dialog.dart`: Windows-branded read-only server dialog/import policy; other platforms retain prior behavior.
- `peer_card.dart`: paint branded recent peer cards only, preserving menus/selection/connections.
- `peers_view.dart`: read optional Home presentation scope; existing views retain their original 220 px card width outside this scope.
- Windows `Runner.rc`: product/company/file metadata; original copyright/license retained.
- Windows preview workflow: analysis/tests/checksums and native capture evidence; packaging remains Windows x64 only.

Upstream drift at this review: fork master is 28 commits behind `rustdesk:master`. No sync/rebase or submodule bump was performed.
