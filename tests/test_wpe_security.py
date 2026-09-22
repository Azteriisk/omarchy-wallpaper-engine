import os
import subprocess
import tempfile
import unittest
from pathlib import Path

repo_root = Path(__file__).resolve().parent.parent
wpe_bin = repo_root / "scripts" / "omarchy-wpe"


class TestWpeSecurity(unittest.TestCase):
    def test_property_id_injection_prevented(self):
        """Verify arbitrary property IDs cannot perform shell injection or create files."""
        canary = Path("/tmp/wpe-injection")
        if canary.exists():
            canary.unlink()

        # Attempt command injection via property ID
        malicious_id = 'x"; touch /tmp/wpe-injection; #'
        res = subprocess.run(
            [str(wpe_bin), "set-prop", "active", malicious_id, "test_val"],
            capture_output=True,
            text=True
        )

        self.assertFalse(canary.exists(), "Command injection succeeded! /tmp/wpe-injection was created.")
        self.assertNotEqual(res.returncode, 0, "Hostile property ID should be rejected with non-zero exit code.")
        self.assertIn("Invalid property identifier", res.stderr)

    def test_get_properties_sanitizes_hostile_json(self):
        """Verify get_properties ignores hostile property keys in project.json."""
        with tempfile.TemporaryDirectory() as td:
            proj = Path(td) / "project.json"
            proj.write_text("""{
                "general": {
                    "properties": {
                        "safe_slider": {"type": "slider", "min": 0, "max": 100, "value": 50},
                        "bad\\"; id; #": {"type": "slider", "min": 0, "max": 100, "value": 10}
                    }
                }
            }""")

            res = subprocess.run(
                [str(wpe_bin), "get-props", td],
                capture_output=True,
                text=True
            )
            self.assertEqual(res.returncode, 0)
            import json
            props = json.loads(res.stdout)
            prop_ids = [p["id"] for p in props]
            self.assertIn("safe_slider", prop_ids)
            self.assertNotIn('bad"; id; #', prop_ids)


if __name__ == "__main__":
    unittest.main()
