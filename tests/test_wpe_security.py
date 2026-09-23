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


    def test_oversized_project_json_ignored(self):
        """Verify project.json exceeding 512KB is rejected before parsing."""
        with tempfile.TemporaryDirectory() as td:
            proj = Path(td) / "project.json"
            # Generate > 512KB payload
            huge_padding = "a" * (520 * 1024)
            proj.write_text(f'{{"general": {{"properties": {{"pad": {{"value": "{huge_padding}"}}}}}}}}')

            res = subprocess.run(
                [str(wpe_bin), "get-props", td],
                capture_output=True,
                text=True
            )
            self.assertEqual(res.returncode, 0)
            import json
            props = json.loads(res.stdout)
            self.assertEqual(props, [], "Oversized project.json should not produce properties.")

    def test_property_count_bounded_to_50(self):
        """Verify properties are capped to at most 50 items."""
        with tempfile.TemporaryDirectory() as td:
            proj = Path(td) / "project.json"
            raw_props = {f"prop_{i}": {"type": "slider", "min": 0, "max": 100, "value": i} for i in range(80)}
            import json
            proj.write_text(json.dumps({"general": {"properties": raw_props}}))

            res = subprocess.run(
                [str(wpe_bin), "get-props", td],
                capture_output=True,
                text=True
            )
            self.assertEqual(res.returncode, 0)
            props = json.loads(res.stdout)
            self.assertLessEqual(len(props), 50, "Property list must be bounded to 50 max.")


if __name__ == "__main__":
    unittest.main()
