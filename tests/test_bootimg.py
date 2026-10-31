"""Run with: python -m unittest discover -s tests (from duolinux/)"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "toolkit"))

from duolib.bootimg import BootImage, pack, unpack  # noqa: E402


class BootImageTests(unittest.TestCase):
    def test_roundtrip(self):
        d = Path(tempfile.mkdtemp())
        img = BootImage(
            kernel=b"K" * 9000,
            ramdisk=b"R" * 5000,
            dtb=b"D" * 3000,
            cmdline="console=tty0 root=LABEL=DUOROOT rw",
        )
        p = pack(img, d / "boot.img")
        back = unpack(p)
        self.assertEqual(back.kernel, img.kernel)
        self.assertEqual(back.ramdisk, img.ramdisk)
        self.assertEqual(back.dtb, img.dtb)
        self.assertEqual(back.cmdline, img.cmdline)
        self.assertEqual(back.header_version, 2)
        self.assertEqual(p.stat().st_size % 4096, 0)

    def test_header_size(self):
        d = Path(tempfile.mkdtemp())
        p = pack(BootImage(kernel=b"x" * 1), d / "boot.img")
        self.assertEqual(int.from_bytes(p.read_bytes()[1644:1648], "little"), 1660)
