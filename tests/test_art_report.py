"""Review report regression tests; these do not launch a renderer."""
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("art_report", Path(__file__).resolve().parents[1] / "tools/art_report.py")
REPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPORT)


class ArtReportTests(unittest.TestCase):
    def setUp(self):
        self.before = {"core": {"region": "core", "p95_ms": 20.0, "draw_calls": 100.0}}
        self.after = {"core": {"region": "core", "p95_ms": 22.0, "draw_calls": 90.0}}
        self.environment = {
            "engine": {"string": "test-engine"}, "platform": "test-platform", "renderer": "test-renderer",
            "adapter": "test-adapter", "resolution": [1280, 800], "vsync_mode": 1, "max_fps": 0,
            "capture_mode": "static_fixed_camera", "review_phase_seconds": 12.0,
            "samples_per_region": 80, "warmup_frames": 60,
        }

    def test_real_environment_is_used_and_absolute_timings_survive(self):
        result = REPORT.compare_captures(self.before, self.after, self.environment, self.environment)
        self.assertTrue(result["environment_verified"])
        self.assertTrue(result["p95_gate_passed"])
        self.assertIn("test-adapter", result["renderer"])
        self.assertEqual(result["regions"][0]["after"]["p95_ms"], 22.0)

    def test_changed_gpu_invalidates_timing_gate(self):
        changed = {**self.environment, "adapter": "another-adapter"}
        result = REPORT.compare_captures(self.before, self.after, self.environment, changed)
        self.assertFalse(result["environment_verified"])
        self.assertFalse(result["p95_gate_passed"])

    def test_legacy_captures_never_claim_verified_environment(self):
        result = REPORT.compare_captures(self.before, self.after, {}, {})
        self.assertFalse(result["environment_verified"])
        self.assertIn("unrecorded", result["renderer"])
        self.assertTrue(result["environment_warning"])

    def test_raw_regression_not_rounded_value_controls_gate(self):
        changed = {"core": {"region": "core", "p95_ms": 23.0001, "draw_calls": 100.0}}
        result = REPORT.compare_captures(self.before, changed, self.environment, self.environment)
        self.assertFalse(result["p95_gate_passed"])

    def test_mismatched_regions_or_invalid_samples_are_rejected(self):
        with self.assertRaises(ValueError):
            REPORT.compare_captures(self.before, {}, self.environment, self.environment)
        invalid = {"core": {"region": "core", "p95_ms": 0.0, "draw_calls": 100.0}}
        with self.assertRaises(ValueError):
            REPORT.compare_captures(self.before, invalid, self.environment, self.environment)


if __name__ == "__main__":
    unittest.main()
