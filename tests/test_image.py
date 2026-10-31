import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "toolkit"))

from duolib import image  # noqa: E402


class GptTests(unittest.TestCase):
    def test_roundtrip(self):
        d = Path(tempfile.mkdtemp())
        p = d / "disk.img"
        total = 4096 * 1024  # 2 GiB in sectors? total is sectors
        total = 2 * 1024 * 1024  # 1 GiB
        with p.open("wb") as f:
            f.truncate(total * 512)
        parts = [
            {"start": 2048, "end": 2048 + 512 * 2048 - 1,
             "type": image.CFG.image.esp_type, "name": "DUOBOOT"},
            {"start": 2048 + 512 * 2048, "end": total - 34,
             "type": image.CFG.image.linux_type, "name": "DUOROOT"},
        ]
        image.build_gpt(p, total, parts)
        got = image.parse_gpt(p)
        self.assertEqual([g["name"] for g in got], ["DUOBOOT", "DUOROOT"])
        self.assertEqual(got[0]["start"], 2048)
        self.assertEqual(got[1]["end"], total - 34)

    def test_backup_header(self):
        d = Path(tempfile.mkdtemp())
        p = d / "disk.img"
        total = 4096
        with p.open("wb") as f:
            f.truncate(total * 512)
        image.build_gpt(p, total, [])
        data = p.read_bytes()
        self.assertEqual(data[(total - 1) * 512:(total - 1) * 512 + 8], b"EFI PART")
        self.assertEqual(data[510:512], b"\x55\xaa")


class PlanTests(unittest.TestCase):
    def test_plan(self):
        boot, root, total = image.plan(8192)
        self.assertEqual(boot, 2048)
        self.assertGreaterEqual(root, boot + image.CFG.image.boot_mb * 2048)
        self.assertGreater(total, root)
