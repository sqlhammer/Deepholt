"""Tests for telemetry_report.py, against a fixture zip built here.

Run: python -m unittest scripts/test_telemetry_report.py
"""

import json
import os
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.dirname(__file__))
import telemetry_report  # noqa: E402


def _lines(events):
	return "\n".join(json.dumps(e) for e in events) + "\n"


def _fixture(path):
	"""Two sessions: one that crashed mid-trip, and the next one, which
	reports the crash, makes a finished trip and ends."""
	crashed = [
		{"t": 0, "event": "session_started", "data": {"build": "0.0.0", "os": "Windows"}},
		{"t": 10, "event": "trip_started", "data": {"from_depth": 0, "to_depth": 1}},
	]
	second = [
		{"t": 0, "event": "session_started", "data": {"build": "0.0.0", "os": "Windows"}},
		{"t": 1, "event": "crashed", "data": {"session": "20261110T100000Z", "seconds": 300,
			"last_minutes": True}},
		{"t": 5, "event": "trip_started", "data": {"from_depth": 0, "to_depth": 1}},
		{"t": 6, "event": "refused", "data": {"verb": "breach", "reason": "NEEDS_PICK"}},
		{"t": 7, "event": "refused", "data": {"verb": "breach", "reason": "NEEDS_PICK"}},
		{"t": 9, "event": "trip_ended", "data": {"seconds_below": 600, "deepest": 2,
			"kilos_home": 31.5, "overloaded_seconds": 200, "finished": True}},
		{"t": 10, "event": "session_ended", "data": {"length_seconds": 900}},
	]
	summary = {"length_seconds": 900, "frames": {"p50": 17, "p95": 20, "p99": 34,
		"max_bucket": 120}, "saves": {"count": 3, "mean_msec": 4.0, "max_msec": 6.0},
		"loads": {"count": 0}, "generations": {"count": 1, "mean_msec": 13.0, "max_msec": 13.0},
		"errors": {"counts": {"warning": 2},
			"sites": {"warning at game.gd:612 _local_player": 2}}}
	with zipfile.ZipFile(path, "w") as archive:
		archive.writestr("session-20261110T100000Z.jsonl", _lines(crashed))
		archive.writestr("crash-20261110T100000Z.jsonl", _lines([{"event": "breached"}]))
		archive.writestr("session-20261110T110000Z.jsonl", _lines(second))
		archive.writestr("session-20261110T110000Z.summary.json", json.dumps(summary))


class ReportTest(unittest.TestCase):
	def setUp(self):
		self.folder = tempfile.mkdtemp()
		self.zip = os.path.join(self.folder, "deepholt-telemetry.zip")
		_fixture(self.zip)

	def test_sessions_are_read_and_the_crash_is_matched(self):
		sessions = telemetry_report.read([self.zip])
		self.assertEqual(len(sessions), 2)
		first, second = sessions
		self.assertTrue(first["crashed"])
		self.assertIsNotNone(first["crash"])
		self.assertFalse(second["crashed"])
		self.assertEqual(second["summary"]["length_seconds"], 900)

	def test_the_report_names_trips_refusals_health_and_criteria(self):
		text = telemetry_report.report([self.zip])
		self.assertIn("CRASHED (no end), last minutes kept", text)
		self.assertIn("trip 1: 10.0 min below, deepest -2, 31.5 kg home", text)
		self.assertIn("refused breach:NEEDS_PICK x2", text)
		self.assertIn("frames p50 17 ms, p95 20 ms, p99 34 ms", text)
		self.assertIn("2 sessions (1 ended, 1 crashed)", text)
		self.assertIn("1 chute before the 5th expedition: not measurable yet", text)
		# The second session's only trip was overloaded over 2 minutes
		self.assertIn("5 nobody abandons", text)
		self.assertIn("1 of 2 sessions", text)
		self.assertIn("warning at game.gd:612 _local_player x2", text)

	def test_a_folder_reads_like_a_zip(self):
		unpacked = os.path.join(self.folder, "unpacked")
		with zipfile.ZipFile(self.zip) as archive:
			archive.extractall(unpacked)
		self.assertEqual(len(telemetry_report.read([unpacked])), 2)

	def test_no_arguments_prints_usage(self):
		self.assertEqual(telemetry_report.main(["telemetry_report.py"]), 2)


if __name__ == "__main__":
	unittest.main()
