"""Offline codec fixtures only, not network or E2E evidence."""
import unittest
from unittest.mock import patch

import probe_public_rendezvous as probe


class SocketFixture:
    def __init__(self, data):
        self.data = bytearray(data)

    def settimeout(self, timeout):
        pass

    def recv(self, size):
        chunk = bytes(self.data[:min(size, 7)])
        del self.data[:len(chunk)]
        return chunk


class CodecTests(unittest.TestCase):
    def test_frame_boundaries(self):
        for size in (0, 1, 63, 64, 16383, 16384, 65536):
            data = b"x" * size
            self.assertEqual(probe.receive(SocketFixture(probe.frame(data))), data)

    def test_limits_and_truncation(self):
        with self.assertRaises(ValueError):
            probe.frame(b"x" * 65537)
        header = ((65537 << 2) | 2).to_bytes(3, "little")
        with self.assertRaises(ValueError):
            probe.receive(SocketFixture(header))
        with self.assertRaises(EOFError):
            probe.receive(SocketFixture(b"\x04"))
        with patch.object(probe.time, "monotonic", side_effect=(0, 5)):
            with self.assertRaises(TimeoutError):
                probe.receive(SocketFixture(b"\x00"))

    def test_protobuf(self):
        self.assertEqual(probe.fields(probe.field(1, "hello")), [(1, b"hello")])
        self.assertEqual(probe.payload(probe.field(11, b""), 11), {})
        self.assertEqual(probe.payload(probe.field(11, b"\x18\x03"), 11), {3: 3})
        for data in (b"\x00", b"\x0a\x04x", b"\x08" + b"\xff" * 10):
            with self.assertRaises(ValueError):
                probe.fields(data)
        with self.assertRaises(ValueError):
            probe.payload(probe.field(11, b"\x18\x03\x18\x00"), 11)
        with self.assertRaises(ValueError):
            probe.payload(probe.field(25, b""), 11)


if __name__ == "__main__":
    unittest.main()
