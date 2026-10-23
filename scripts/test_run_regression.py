"""Negative tests for regression exit handling; no HDL simulator required."""
import sys
import tempfile
import unittest
from pathlib import Path
from run_regression import check_manifest, run_process, verdict


class RunnerTests(unittest.TestCase):
    def test_pass_requires_real_line(self):
        self.assertTrue(verdict("# PASS tb_alu 10 checks\n", "tb_alu", 0)[0])
        self.assertFalse(verdict('echo "PASS tb_alu 10 checks"\n', "tb_alu", 0)[0])

    def test_failure_wins_over_marker(self):
        for error in ("# ** Fatal: assertion", "# ** Error: compile", "# [FAIL] result", "# Errors: 1"):
            with self.subTest(error=error):
                self.assertFalse(verdict("# PASS tb_alu 10 checks\n"+error, "tb_alu", 0)[0])

    def test_nonzero_exit_and_missing_marker(self):
        self.assertFalse(verdict("# PASS tb_alu 10 checks", "tb_alu", 1)[0])
        self.assertFalse(verdict("# Errors: 0", "tb_alu", 0)[0])

    def test_system_verdict(self):
        self.assertTrue(verdict("# [PASS] tb_top completed with no errors.\n", "tb_top", 0)[0])
        self.assertFalse(verdict("# [PASS] result[0] = 0\n", "tb_top", 0)[0])

    def test_nonzero_child_with_pass_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            rc, output = run_process([sys.executable, "-c", "print('PASS tb_alu 10 checks'); raise SystemExit(2)"], Path(tmp), 5)
        self.assertEqual(rc, 2)
        self.assertFalse(verdict(output, "tb_alu", rc)[0])

    def test_timeout(self):
        with tempfile.TemporaryDirectory() as tmp:
            rc, output = run_process([sys.executable, "-c", "import time; time.sleep(10)"], Path(tmp), 0.2)
        self.assertEqual(rc, 124)
        self.assertIn("TIMEOUT", output)

    def test_all_active_modules_have_benches(self):
        check_manifest()


if __name__ == "__main__":
    unittest.main()
