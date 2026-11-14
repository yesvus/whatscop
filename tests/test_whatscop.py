import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

CLI = Path(__file__).resolve().parents[1] / "whatscop"
loader = importlib.machinery.SourceFileLoader("whatscop", str(CLI))
spec = importlib.util.spec_from_loader("whatscop", loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class ReadOnlyScannerTests(unittest.TestCase):
    def test_aggregate_and_symlink_skip(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            a = root / "group@g.us" / "nested"
            b = root / "person@s.whatsapp.net"
            a.mkdir(parents=True)
            b.mkdir()
            old = a / "photo.jpg"
            old.write_bytes(b"x" * 9000)
            os.utime(old, (time.time() - 100 * 86400,) * 2)
            (a / "video.mp4").write_bytes(b"x" * 500)
            (b / "photo.jpg").write_bytes(b"x" * 500)
            (b / "linked").symlink_to(old)
            before = {str(p): p.stat().st_mtime_ns for p in root.rglob("*")
                      if p.is_file() and not p.is_symlink()}
            result = module.scan(root)
            self.assertEqual(result["summary"]["files"], 3)
            self.assertEqual(result["summary"]["logical"], 10000)
            self.assertEqual(result["summary"]["old_files"], 1)
            self.assertEqual(result["types"][".jpg"]["files"], 2)
            self.assertEqual(result["symlinks_skipped"], 1)
            after = {str(p): p.stat().st_mtime_ns for p in root.rglob("*")
                     if p.is_file() and not p.is_symlink()}
            self.assertEqual(before, after)

    def test_redaction_and_opt_in_identifiers(self):
        with tempfile.TemporaryDirectory() as temp:
            group = Path(temp) / "sensitive@g.us"
            group.mkdir()
            (group / "x.jpg").write_bytes(b"ok")
            cmd = [sys.executable, str(CLI), "--root", temp, "--json"]
            hidden = json.loads(subprocess.check_output(cmd, text=True))
            self.assertEqual(hidden["chats"][0]["chat"], "Chat #1")
            self.assertNotIn("sensitive@g.us", json.dumps(hidden))
            shown = json.loads(subprocess.check_output(cmd + ["--show-ids"], text=True))
            self.assertEqual(shown["chats"][0]["chat"], "sensitive@g.us")

    def test_reject_missing_and_symlink_root(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaises(ValueError):
                module.scan(root / "missing")
            link = root / "linked"
            link.symlink_to(root)
            with self.assertRaises(ValueError):
                module.scan(link)


if __name__ == "__main__":
    unittest.main()
