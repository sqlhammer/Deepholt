"""Reads play-test telemetry (D-206, logging-and-telemetry section 2.4).

Usage:
	python scripts/telemetry_report.py <zip or folder> [<zip or folder> ...]

Each argument is a tester's deepholt-telemetry.zip, or a telemetry folder.
Prints each session, then everything together, then what the data says,
and can't yet say, about the pre-alpha success criteria
(pre-alpha-scope section 6). Reads only; writes nothing.
"""

import json
import os
import sys
import zipfile
from collections import Counter

SESSION_PREFIX = "session-"
CRASH_PREFIX = "crash-"


def _files(source):
	"""Name to text, for every file in a zip or a folder."""
	found = {}
	if zipfile.is_zipfile(source):
		with zipfile.ZipFile(source) as archive:
			for name in archive.namelist():
				found[name] = archive.read(name).decode("utf-8", "replace")
	elif os.path.isdir(source):
		for name in os.listdir(source):
			path = os.path.join(source, name)
			if os.path.isfile(path) and not name.endswith(".zip"):
				with open(path, encoding="utf-8", errors="replace") as handle:
					found[name] = handle.read()
	else:
		raise SystemExit("Not a zip or a folder: %s" % source)
	return found


def _events(text):
	events = []
	for line in text.splitlines():
		line = line.strip()
		if not line:
			continue
		try:
			events.append(json.loads(line))
		except ValueError:
			pass
	return events


def read(sources):
	"""Every session found, keyed by source and name: its events, its
	summary if it ended, and its crash record if it didn't."""
	sessions = []
	for source in sources:
		files = _files(source)
		for name in sorted(files):
			if not (name.startswith(SESSION_PREFIX) and name.endswith(".jsonl")):
				continue
			stamp = name[len(SESSION_PREFIX):-len(".jsonl")]
			summary_text = files.get("%s%s.summary.json" % (SESSION_PREFIX, stamp))
			crash_text = files.get("%s%s.jsonl" % (CRASH_PREFIX, stamp))
			sessions.append({
				"source": os.path.basename(source),
				"session": stamp,
				"events": _events(files[name]),
				"summary": json.loads(summary_text) if summary_text else None,
				"crash": _events(crash_text) if crash_text is not None else None,
			})
	# A crash is reported by the session after it: mark the one it names
	crashed = set()
	for session in sessions:
		for event in session["events"]:
			if event.get("event") == "crashed":
				crashed.add((session["source"], event.get("data", {}).get("session")))
	for session in sessions:
		session["crashed"] = (session["source"], session["session"]) in crashed
	return sessions


def _of(events, name):
	return [e.get("data", {}) for e in events if e.get("event") == name]


def _minutes(seconds):
	if seconds < 60:
		return "%d s" % round(seconds)
	return "%.1f min" % (seconds / 60.0)


def session_lines(session):
	events = session["events"]
	summary = session["summary"]
	started = (_of(events, "session_started") or [{}])[0]
	lines = ["%s / %s" % (session["source"], session["session"])]
	lines.append("  build %s on %s, %s, gpu %s" % (started.get("build", "?"),
		started.get("os", "?"), started.get("source", "?"), started.get("gpu", "?")))
	if summary:
		lines.append("  length %s" % _minutes(summary.get("length_seconds", 0)))
	elif session["crashed"]:
		lines.append("  CRASHED (no end)%s" % (", last minutes kept" if session["crash"] else ""))
	else:
		lines.append("  no end recorded (still running, or its crash not yet seen)")
	trips = _of(events, "trip_ended")
	for i, trip in enumerate(trips):
		lines.append("  trip %d: %s below, deepest -%s, %s kg home, %s overloaded%s" % (i + 1,
			_minutes(trip.get("seconds_below", 0)), trip.get("deepest", "?"),
			trip.get("kilos_home", 0), _minutes(trip.get("overloaded_seconds", 0)),
			"" if trip.get("finished") else " (unfinished)"))
	refusals = Counter("%s:%s" % (r.get("verb"), r.get("reason")) for r in _of(events, "refused"))
	for key, count in refusals.most_common():
		lines.append("  refused %s x%d" % (key, count))
	if summary:
		frames = summary.get("frames", {})
		lines.append("  frames p50 %s ms, p95 %s ms, p99 %s ms (slowest bucket %s ms)" % (
			frames.get("p50"), frames.get("p95"), frames.get("p99"), frames.get("max_bucket")))
		for kind in ("saves", "loads", "generations"):
			timing = summary.get(kind, {})
			if timing.get("count"):
				lines.append("  %s: %d, mean %s ms, max %s ms" % (kind, timing["count"],
					timing.get("mean_msec"), timing.get("max_msec")))
		errors = summary.get("errors", {}).get("counts", {})
		if errors:
			lines.append("  engine: %s" % ", ".join("%s %s" % (v, k) for k, v in errors.items()))
		# Where they were raised, never what they said (D-209)
		sites = summary.get("errors", {}).get("sites", {})
		for site, count in sorted(sites.items(), key=lambda kv: -kv[1])[:3]:
			lines.append("    %s x%d" % (site, count))
	return lines


def overall_lines(sessions):
	ended = [s for s in sessions if s["summary"]]
	crashed = [s for s in sessions if s["crashed"]]
	trips = [t for s in sessions for t in _of(s["events"], "trip_ended")]
	finished = [t for t in trips if t.get("finished")]
	played = sum(s["summary"].get("length_seconds", 0) for s in ended)
	lines = ["All together: %d sessions (%d ended, %d crashed), %s played" % (len(sessions),
		len(ended), len(crashed), _minutes(played))]
	if trips:
		lines.append("  %d trips, %d finished; mean %s below; %.1f kg home in all; %s overloaded" % (
			len(trips), len(finished),
			_minutes(sum(t.get("seconds_below", 0) for t in trips) / len(trips)),
			sum(t.get("kilos_home", 0) for t in finished),
			_minutes(sum(t.get("overloaded_seconds", 0) for t in trips))))
	refusals = Counter("%s:%s" % (r.get("verb"), r.get("reason"))
		for s in sessions for r in _of(s["events"], "refused"))
	for key, count in refusals.most_common(5):
		lines.append("  most refused: %s x%d" % (key, count))
	return lines


def criteria_lines(sessions):
	"""What the data can say about pre-alpha-scope section 6."""
	lines = ["Pre-alpha criteria (pre-alpha-scope section 6):"]
	lines.append("  1 chute before the 5th expedition: not measurable yet (the chute comes in 015)")
	for n in (2, 3, 6):
		lines.append("  %d: judged in testers' own words, not from telemetry" % n)
	lines.append("  4 smelter sited near the mine: not measurable yet (no smelter)")
	# Criterion 5, the kill switch: sessions that ended mid-trip or
	# straight after a long overloaded one are the ones to ask about
	flagged = []
	for s in sessions:
		trips = _of(s["events"], "trip_ended")
		if not trips:
			continue
		last = trips[-1]
		if not last.get("finished") or last.get("overloaded_seconds", 0) > 120:
			flagged.append("%s/%s" % (s["source"], s["session"]))
	lines.append("  5 nobody abandons a session out of backtracking fatigue: %d of %d sessions "
		"ended below or after a trip overloaded over 2 min%s" % (len(flagged), len(sessions),
		(" (ask about: %s)" % ", ".join(flagged)) if flagged else ""))
	return lines


def report(sources):
	sessions = read(sources)
	if not sessions:
		return "No sessions found."
	lines = []
	for session in sessions:
		lines.extend(session_lines(session))
		lines.append("")
	lines.extend(overall_lines(sessions))
	lines.append("")
	lines.extend(criteria_lines(sessions))
	return "\n".join(lines)


def main(argv):
	if len(argv) < 2:
		print(__doc__)
		return 2
	print(report(argv[1:]))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv))
