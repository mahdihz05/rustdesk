# AbrIT Desk 1.0.0 Connection Investigation

Follow-up: [Portable password/IPC fix and Preview 3 results](ABRIT_PORTABLE_PASSWORD_FIX.md). The original results below are historical; the follow-up distinguishes the verified application fix from the still-failing public desktop path.

## Delivery Status

**Experimental build available; end-to-end remote desktop acceptance FAILED. Do not promote this build as a verified connection fix.**

- Requested base: `2fa91856236196404881b90b76a7a7a369c11c50`.
- Built source: `13f49231730377ca1c76d46340e936fcea1f7ec1`.
- Working branch: `fix/abritdesk-1.0.0-connection`.
- Build and installation acceptance: https://github.com/mahdihz05/rustdesk/actions/runs/38449754633
- Latest two-machine acceptance: https://github.com/mahdihz05/rustdesk/actions/runs/38526376465
- Release: https://github.com/mahdihz05/rustdesk/releases/tag/abritdesk-v1.0.0-connection-preview.1
- Product version remains `1.0.0`. No approved UI, layout, colors, menus, languages, fonts, or branding source was changed.

## Confirmed Findings

### MSI publication failure was a test defect

The original x64 build compiled and packaged successfully, then failed its MSI ProductName/Manufacturer assertion. Inspection of the published same-run ARM64 MSI showed the expected `abritdesk` and `Abrit` values. Reproducing the original PowerShell property reader returned `System.Object[]`: COM `Execute()` and `Close()` emitted null success-stream entries alongside the string. Array comparison falsely rejected the metadata.

Suppressing those method outputs restores a scalar string. The strict branding comparisons remain unchanged. The new x64 MSI passed actual install, service restart, and uninstall acceptance.

### Main connection failure is not resolved

Two independent hosted Windows VMs used identical binaries from the built source, with distinct SMBIOS hardware UUIDs. Their cloned Windows hostnames are identical; hostname is not used as evidence of machine independence.

In the final run, receiver ID `499156629` and sender ID `230741584` both reported positive rendezvous latency, own-key confirmation, and the expected effective ID server, relay, and public server key. Receiver PID/creation-time checks, ongoing heartbeat, fresh listener diagnostics, service state, and bounded Notepad reads verified receiver liveness across steps. Both resolved the server to `2.180.18.102`.

The sender nevertheless displayed `ID does not exist`, both with default `ID/r` routing and with an explicit server URI carrying the percent-encoded trusted key. No remote display or input receipt was proven. An earlier explicit-server attempt using a cached peer option produced `Key mismatch`; that error was not reproduced after unambiguous inline-key delivery and must not be treated as proof of a server key mismatch.

`key_confirmed` means the client's own public-key registration was acknowledged. It is **not** authenticated proof of the responding hbbs identity or successful peer lookup. A green registration diagnostic alone is not end-to-end acceptance.

The inspected Ubuntu hbbs log contains the sender registration and the initial build-acceptance ID, but not the final receiver's RegisterPk event. This discrepancy still needs endpoint/packet and registration-state correlation. A log-event absence alone does not prove a NAT fault, because ordinary keepalives are not repeated RegisterPk log entries. The root cause of the peer lookup failure remains unconfirmed; neither a client configuration rewrite nor an infrastructure change was guessed into production.

### Windows IPC and profile isolation

The existing workstation runs an installed AbritDesk `1.5.4` service from `C:\Program Files\AbritDesk\AbritDesk.exe`. Baseline GUI logs repeatedly contain `ipc connection closed: reset by the peer`.

Windows main IPC authenticates the peer's full canonical executable path. A separately extracted/portable GUI cannot automatically control a server child launched from another installation path. This is a concrete explanation to check for those local IPC failures, not proof of their exact rejection: protected service logs could not be collected without an approved elevated read. The elevation request did not produce an evidence file. No ACL or executable-authentication checks were weakened.

Configuration precedence remains overrides, stored AbritDesk Config2 options, then defaults. Defaults do not overwrite stored values. Config2 and service profiles are independent from stock RustDesk; LocalSystem configuration paths can resolve under `ServiceProfiles\LocalService`. Merely inspecting the GUI profile is insufficient. The new diagnostic reads status and allowlisted options from the actual listener and reports IPC errors explicitly instead of treating local fallback data as success.

### Server and management API are separate

Read-only SSH checks confirmed Ubuntu at `10.0.0.150`, hbbs `1.1.16`, both services active, TCP listeners `21115/21116/21117`, and UDP listener `21116`. The server's `id_ed25519.pub` exactly matches:

```text
XDQrtTIvt+ISB6Zp8iqpjNpwmjRmkfpLHilOsBmrZHM=
```

Internal TCP probes passed. A real UDP RegisterPeer probe received RegisterPeerResponse/request_pk. The public Windows acceptance run registered ID `136053173`, confirmed by hbbs at `2026-10-13T19:43:45Z` from `172.203.207.241`. This proves an external registration path, not all public NAT rules or a relayed desktop session.

The server's UFW was inactive and its inspected netfilter tables did not show a blocking/NAT rule. pfSense rules could not be inspected with the available Ubuntu-only access.

Public DNS queried through `1.1.1.1` returned `2.180.18.102`; internal resolution returned `10.0.0.150`. Public HTTPS with normal certificate validation returned HTTP 200 and an optional policy (`latest=1.0.0`, `minimum=0.0.0`, `mandatory=false`). The historical public HTTP 503/default-certificate failure was not reproduced on that route.

The internal HTTPS route fails normal Windows trust validation. The origin nginx certificate is self-signed, CN/SAN `serverdesk.abrit.cloud`, also covering `10.0.0.150`, valid October 5, 2026 through January 3, 2027. Thus the banner/API can fail inside the network while the public route works. TLS verification was never disabled.

Cloudflare is authoritative DNS (`chase.ns.cloudflare.com`, `kristina.ns.cloudflare.com`). This does not establish that native RustDesk TCP/UDP traverses a Cloudflare proxy. No cloudflared service/configuration was found on this Ubuntu host. No authenticated Cloudflare, internal DNS, or pfSense administration was available, so no DNS or edge certificate/routing changes were made.

## Test Results

| Test | Result | Evidence / Scope |
| --- | --- | --- |
| Windows x64 Rust/Flutter build and EXE/MSI packaging | PASS | Build run `38449754633` |
| Flutter regression tests | PASS | 27 tests in that run |
| Native identity tests | PASS | 2 tests in that run |
| Native policy model tests | PASS | 6 tests in that run |
| Python identity/version tests | PASS | 5 tests locally and in CI |
| MSI scalar-property regression | PASS | Reproduces old failure and verifies corrected reader; not connection proof |
| Actual approved GUI smoke | PASS | 60 screenshots across Persian/English and light/dark |
| Fresh standalone native bundle registration | PASS | `portable-registration/Registration.json`, ID `136053173` |
| Standalone process restart preserves ID and reconnects | PASS | `portable-restart/Restart.json` |
| Installed native service registration and restart | PASS | `installed-registration`, `installed-restart` |
| MSI service registration and restart | PASS | `msi-registration`, `msi-restart` |
| Native and MSI install/uninstall; stock RustDesk preservation | PASS | `identity-acceptance.txt` and installation logs |
| Receiver lifetime across CI steps | PASS | Final E2E heartbeat, 209 PID/creation-time checks, normal monitor completion |
| Two independent Windows peer lookup/session | FAIL | Final E2E screenshot: `ID does not exist` |
| Actual remote display and keyboard input | NOT PROVEN | Display gate failed; no keyboard events sent |
| Forced relay desktop session on TCP 21117 | NOT PROVEN | `/r` requested, but no accepted desktop session |
| Network-loss recovery / OS reboot | NOT RUN | Process/service restarts are not a network-loss or OS reboot test |
| Public management API TLS/policy | PASS | Validated public HTTPS 200; optional live policy |
| Internal management API TLS | FAIL | Self-signed origin certificate / Windows untrusted root |
| Both final E2E owned-install cleanups | PASS | Both `cleanup.json` artifacts |

E2E credentials were generated only on disposable runners and exchanged using the sender's public RSA key. Plaintext passwords, private RSA keys, and native command logs were not uploaded. Early harness failures remain visible in Actions history; successful fixtures are not represented as successful remote desktop sessions.

## Downloads

- EXE: https://github.com/mahdihz05/rustdesk/releases/download/abritdesk-v1.0.0-connection-preview.1/abritdesk-1.0.0-x86_64.exe
- MSI: https://github.com/mahdihz05/rustdesk/releases/download/abritdesk-v1.0.0-connection-preview.1/abritdesk-1.0.0-x86_64.msi

Downloaded files were checked against the release digests:

```text
cc4499753b84f20d716dd7a640d226583fb63e197ed64515a6e7bdf8ad2ef12a  abritdesk-1.0.0-x86_64.exe
50600cc18f66e03fa583b648af87e5b6652c864940a186eb3675d2de796fa3ca  abritdesk-1.0.0-x86_64.msi
```

Do not mix an extracted GUI with an older installed native bundle and assume its IPC is trusted. The MSI downgrade guard remains intact: a pre-existing 1.5.x MSI installation is not silently treated as an older 1.0.0 installation. The workstation's existing installation was not replaced without elevation.

## Regression Surface

- `src/core_main.rs`: one Windows-only read-only diagnostic command hook; normal GUI startup is unchanged.
- `src/platform/windows.rs`: listener status/allowlisted-option diagnostic helper only; initialization defaults and executable authentication are unchanged.
- `res/abrit/test_windows_identity.ps1`: scalar COM result fix, metadata evidence, opt-in live registration/restart assertions.
- `.github/workflows/flutter-tag.yml` and `flutter-build.yml`: opt-in x64-only build, exact source SHA for a new prerelease, native regression tests and failure artifact retention. Existing default platform selection remains intact.
- New E2E workflow/scripts: disposable test installations, encrypted coordination, liveness/display/input/relay acceptance and cleanup. They refuse developer-machine execution.

No server service was restarted or reconfigured, no private identity key was changed, no RustDesk installation/configuration was overwritten, and no published tag was moved.
