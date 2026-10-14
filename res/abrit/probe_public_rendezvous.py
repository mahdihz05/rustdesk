"""Public-route network consistency only, not desktop E2E or identity proof.

Creates at most one new client identity per invocation. No existing peer IDs,
server credentials, private-key files, SSH, or application configuration are used.
"""
import argparse
import base64
import hashlib
import json
import os
import platform
import socket
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

EXPECTED_KEY = "XDQrtTIvt+ISB6Zp8iqpjNpwmjRmkfpLHilOsBmrZHM="
DOMAIN = "serverdesk.abrit.cloud"
PUBLIC_IP = "2.180.18.102"
TIMEOUT = 4
LIMIT = 65536


def varint(n):
    out = bytearray()
    while n > 127:
        out.append((n & 127) | 128)
        n >>= 7
    out.append(n)
    return bytes(out)


def field(n, value):
    if isinstance(value, str):
        value = value.encode("ascii")
    return varint(n * 8 + 2) + varint(len(value)) + value


def fields(data):
    pos = 0

    def number():
        nonlocal pos
        out = 0
        for shift in range(0, 70, 7):
            if pos >= len(data):
                break
            b = data[pos]
            pos += 1
            if shift == 63 and b > 1:
                raise ValueError("varint overflow")
            out |= (b & 127) << shift
            if not b & 128:
                return out
        raise ValueError("invalid varint")

    out = []
    while pos < len(data):
        tag = number()
        if tag >> 3 == 0:
            raise ValueError("invalid field number")
        if tag & 7 == 2:
            size = number()
            if size > len(data) - pos:
                raise ValueError("truncated field")
            value = data[pos:pos + size]
            pos += size
        elif tag & 7 == 0:
            value = number()
        else:
            raise ValueError("unsupported wire type")
        out.append((tag >> 3, value))
    return out


def payload(data, kind):
    outer = fields(data)
    if len(outer) != 1 or outer[0][0] != kind or not isinstance(outer[0][1], bytes):
        raise ValueError("unexpected response type; contents withheld")
    inner = fields(outer[0][1])
    if len({n for n, _ in inner}) != len(inner):
        raise ValueError("duplicate response fields")
    return dict(inner)


def frame(data):
    if len(data) > LIMIT:
        raise ValueError("frame limit exceeded")
    size = 1 if len(data) <= 63 else 2 if len(data) <= 16383 else 3
    return ((len(data) << 2) | (size - 1)).to_bytes(size, "little") + data


def receive(sock):
    deadline = time.monotonic() + TIMEOUT

    def exact(n):
        out = bytearray()
        while len(out) < n:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("frame deadline exceeded")
            sock.settimeout(remaining)
            chunk = sock.recv(n - len(out))
            if not chunk:
                raise EOFError("peer closed")
            out.extend(chunk)
        return bytes(out)

    first = exact(1)
    head = first + exact(first[0] & 3)
    size = int.from_bytes(head, "little") >> 2
    if size > LIMIT:
        raise ValueError("frame limit exceeded")
    return exact(size)


def tcp(ip, port, request, kind):
    with socket.create_connection((ip, port), TIMEOUT) as sock:
        sock.sendall(frame(request))
        return payload(receive(sock), kind)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if len(base64.b64decode(EXPECTED_KEY, validate=True)) != 32:
        raise ValueError("invalid expected public key")
    result = {
        "schema": 1, "diagnostic": "public-route network consistency, not E2E",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "provenance": {k: os.environ.get(k) for k in (
            "GITHUB_REPOSITORY", "GITHUB_SHA", "GITHUB_REF", "GITHUB_RUN_ID",
            "GITHUB_RUN_ATTEMPT", "GITHUB_JOB", "RUNNER_OS", "RUNNER_ARCH")},
        "platform": platform.system(), "python": platform.python_version(),
        "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "expected_server_public_key": EXPECTED_KEY,
        "limitations": [
            "Legacy 1.1.16 responses are not cryptographic server identity proof.",
            "External hosted-runner route only; no LAN or hairpin route is tested here.",
            "Behavior cannot identify a specific NAT/firewall/backend root cause; firewall administrator investigation is required.",
            "One new diagnostic identity may remain in each backend database; no cleanup or existing identity mutation is attempted.",
            "No desktop, relay, real peer lookup, or end-to-end connection is tested."],
        "observations": [],
    }
    observations = result["observations"]

    def record(operation, target, round_number, function):
        entry = {"operation": operation, "target": target, "round": round_number,
                 "utc": datetime.now(timezone.utc).isoformat()}
        try:
            entry.update(function())
        except Exception as error:
            # Do not serialize raw packets, arbitrary server text, or socket addresses.
            entry.update(classification="probe_error", error_type=type(error).__name__)
        observations.append(entry)
        return entry

    targets = [{"label": "direct_public_ip", "ip": PUBLIC_IP}]

    def resolve():
        addresses = sorted({x[4][0] for x in socket.getaddrinfo(
            DOMAIN, 21116, socket.AF_INET, socket.SOCK_STREAM)})
        if not addresses or len(addresses) > 8:
            raise ValueError("unexpected DNS address count")
        targets.extend({"label": "resolved_domain", "domain": DOMAIN, "ip": ip}
                       for ip in addresses)
        return {"classification": "dns_resolved", "ipv4": addresses}

    record("dns", DOMAIN, 0, resolve)
    identifier = "probe" + uuid.uuid4().hex[:20]
    result["diagnostic_id"] = identifier
    result["targets"] = targets
    client_uuid = uuid.uuid4().bytes
    client_pk = Ed25519PrivateKey.generate().public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
    registration = field(15, field(1, identifier) + field(2, client_uuid) + field(3, client_pk))
    sockets = []
    try:
        for target in targets:
            udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sockets.append((target, udp))

            def register():
                udp.settimeout(TIMEOUT)
                udp.connect((target["ip"], 21116))
                udp.send(registration)
                response = payload(udp.recv(LIMIT), 16)
                code = response.get(1, 0)
                if not isinstance(code, int):
                    raise ValueError("invalid registration result")
                return {"registration_result": code, "classification":
                        "registration_ok" if code == 0 else "registration_rejected"}

            record("udp_register_pk_21116", target, 0, register)

        for round_number in range(1, 7):
            for target, udp in sockets:

                def heartbeat():
                    udp.send(field(6, field(1, identifier)))
                    response = payload(udp.recv(LIMIT), 7)
                    wants_pk = response.get(2, 0)
                    if wants_pk not in (0, 1):
                        raise ValueError("invalid heartbeat response")
                    return {"request_pk": bool(wants_pk), "classification":
                            "heartbeat_requests_pk" if wants_pk else "heartbeat_ok"}

                record("udp_heartbeat_21116", target, round_number, heartbeat)
            time.sleep(0.5)
            for target in targets:
                ip = target["ip"]

                def online():
                    response = tcp(ip, 21115, field(23, field(1, identifier)
                                   + field(2, identifier)), 24)
                    states = response.get(1, b"")
                    if not isinstance(states, bytes) or len(states) != 1:
                        raise ValueError("invalid online bitmap")
                    present = bool(states[0] & 128)
                    return {"online": present, "classification":
                            "online" if present else "registered_id_absent"}

                def nat():
                    # Legacy hbbs has no initial exchange. Send only the read-only request.
                    response = tcp(ip, 21116, field(20, b""), 21)
                    port = response.get(1, 0)
                    if not isinstance(port, int) or not 1 <= port <= 65535:
                        raise ValueError("invalid TestNat port")
                    return {"classification": "test_nat_response", "reported_port": port,
                            "cryptographic_identity_proof": False}

                def lookup():
                    absent_id = "absent" + uuid.uuid4().hex[:20]
                    response = tcp(ip, 21116, field(8, field(1, absent_id)
                                   + field(3, EXPECTED_KEY)), 11)
                    if any(n in response for n in (1, 2, 4, 11, 12)):
                        raise ValueError("unexpected routing response; contents withheld")
                    code = response.get(3, 0)
                    if not isinstance(code, int):
                        raise ValueError("invalid lookup failure")
                    return {"failure_code": code, "classification":
                            {0: "id_not_exist", 3: "license_mismatch"}.get(code, "unexpected_lookup_failure"),
                            "cryptographic_identity_proof": False}

                record("tcp_online_21115", target, round_number, online)
                record("tcp_test_nat_21116", target, round_number, nat)
                record("tcp_fresh_nonexistent_id_21116", target, round_number, lookup)
    finally:
        for _, udp in sockets:
            udp.close()

    classes = {x["classification"] for x in observations}
    expected = {"dns_resolved", "registration_ok", "heartbeat_ok", "online",
                "test_nat_response", "id_not_exist"}
    issues = sorted(classes - expected)
    behavioral_issues = sorted(set(issues) - {"probe_error"})
    result["summary"] = {
        "pass": not issues, "unexpected_classifications": issues,
        "mixed_lookup_results": "id_not_exist" in classes and "license_mismatch" in classes,
        "mixed_online_results": "online" in classes and "registered_id_absent" in classes,
        "classification": ("consistent_expected_public_behavior" if not issues else
                           "public_behavior_inconsistent_with_expectation" if behavioral_issues else
                           "inconclusive_due_to_probe_errors"),
        "cryptographic_identity_proof": False,
    }
    result["finished_utc"] = datetime.now(timezone.utc).isoformat()
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["summary"], sort_keys=True))
    return 0 if result["summary"]["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
