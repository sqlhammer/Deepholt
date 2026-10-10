"""Line coverage for the Godot project, measured by instrumentation.

Godot and GUT have no coverage tool, so this:
  1. copies game/ to a temporary folder (the real project is never touched),
  2. inserts a probe before every executable line in src/, scenes/ and singletons/,
  3. imports the copy and runs the full GUT suite on it, headless,
  4. reports which probed lines ran: per file, then every uncovered line.

Counted: executable lines inside functions. Not counted: declarations, else/elif
lines, match patterns, and lines inside multi-line lambdas. Autoloads' _ready()
runs when GUT starts, so it counts as covered.

Usage:  python scripts/coverage.py [--keep]
Godot:  GODOT_BIN, or `godot` on PATH (as scripts/test.ps1).
Exit:   GUT's exit code, so a failing suite fails this too.
"""
import collections
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(REPO, "game")
ROOTS = ["src", "scenes", "singletons"]

NO_PROBE_PREFIX = ("elif ", "elif(", "else:", "else :", "func ", "static func ",
	"class ", "class_name", "extends", "signal ", "enum ", "@", "#", "const ")
STR_DQ = re.compile(r'"(?:\\.|[^"\\])*"')
STR_SQ = re.compile(r"'(?:\\.|[^'\\])*'")

PROBE_SCRIPT = '''class_name CovProbe
extends RefCounted

static var _seen: Dictionary = {}


static func h(id: String) -> void:
	if _seen.has(id):
		return
	_seen[id] = true
	var path: String = "res://coverage_hits.txt"
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	f.seek_end()
	f.store_line(id)
	f.close()
'''


def godot_bin():
	found = os.environ.get("GODOT_BIN") or shutil.which("godot")
	if not found:
		sys.exit("Godot not found. Set GODOT_BIN, or put 'godot' on PATH.")
	return found


def indent_of(line):
	return len(line) - len(line.lstrip("\t"))


def bracket_delta(code):
	code = STR_DQ.sub('""', code)
	code = STR_SQ.sub("''", code)
	code = code.split("#", 1)[0]
	opens = sum(code.count(c) for c in "([{")
	closes = sum(code.count(c) for c in ")]}")
	return opens - closes


def instrument(root):
	"""Insert probes into every .gd under ROOTS in `root`. Returns {id: source line}."""
	probes = {}
	for sub in ROOTS:
		for dirpath, _, files in os.walk(os.path.join(root, sub)):
			for name in files:
				if not name.endswith(".gd"):
					continue
				path = os.path.join(dirpath, name)
				rel = os.path.relpath(path, root).replace("\\", "/")
				lines = open(path, encoding="utf-8").read().split("\n")
				out = []
				depth = 0
				continued = False
				in_func = False
				match_stack = []
				for number, line in enumerate(lines, 1):
					text = line.strip()
					indent = indent_of(line)
					if text and depth == 0 and not continued:
						while match_stack and indent <= match_stack[-1]:
							match_stack.pop()
						if indent == 0:
							in_func = text.startswith("func ") or text.startswith("static func ")
						is_pattern = bool(match_stack) and indent == match_stack[-1] + 1
						if (in_func and indent > 0 and not is_pattern
								and not text.startswith(NO_PROBE_PREFIX)):
							probe_id = "%s:%d" % (rel, number)
							probes[probe_id] = text
							out.append("\t" * indent + 'CovProbe.h("%s")' % probe_id)
						if text.startswith("match ") and text.endswith(":"):
							match_stack.append(indent)
					out.append(line)
					if text:
						depth += bracket_delta(text)
						continued = text.endswith("\\")
				with open(path, "w", encoding="utf-8", newline="\n") as f:
					f.write("\n".join(out))
	with open(os.path.join(root, "cov_probe.gd"), "w", encoding="utf-8", newline="\n") as f:
		f.write(PROBE_SCRIPT)
	return probes


def run_suite(root):
	godot = godot_bin()
	subprocess.run([godot, "--headless", "--path", root, "--import"],
		stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	result = subprocess.run(
		[godot, "--headless", "--path", root, "-s", "res://addons/gut/gut_cmdln.gd",
			"-gdir=res://tests", "-ginclude_subdirs", "-gexit"],
		capture_output=True, text=True, encoding="utf-8", errors="replace")
	output = result.stdout + result.stderr
	for line in output.splitlines():
		if "Passing Tests" in line or "Failing Tests" in line or "Ignoring script" in line:
			print(re.sub(r"\x1b\[[0-9;]*m", "", line).strip())
	return result.returncode


def report(probes, hits_path):
	hits = set()
	if os.path.exists(hits_path):
		hits = {line.strip() for line in open(hits_path, encoding="utf-8") if line.strip()}
	by_file = collections.OrderedDict()
	for probe_id in sorted(probes, key=lambda p: (p.rsplit(":", 1)[0], int(p.rsplit(":", 1)[1]))):
		path, number = probe_id.rsplit(":", 1)
		by_file.setdefault(path, []).append((int(number), probe_id in hits, probes[probe_id]))
	total = sum(len(v) for v in by_file.values())
	covered = sum(sum(hit for _, hit, _ in v) for v in by_file.values())
	print()
	print("TOTAL %d/%d = %.1f%%" % (covered, total, 100.0 * covered / max(total, 1)))
	print()
	for path, entries in by_file.items():
		done = sum(hit for _, hit, _ in entries)
		print("%-50s %4d/%-4d %5.1f%%" % (path, done, len(entries), 100.0 * done / len(entries)))
	missing = [(p, e) for p, e in by_file.items() if any(not hit for _, hit, _ in e)]
	if missing:
		print()
		print("Uncovered lines:")
		for path, entries in missing:
			print("## " + path)
			for number, hit, text in entries:
				if not hit:
					print("  %4d  %s" % (number, text[:90]))


def main():
	keep = "--keep" in sys.argv
	work = tempfile.mkdtemp(prefix="deepholt_coverage_")
	root = os.path.join(work, "game")
	try:
		shutil.copytree(GAME, root)
		hits_path = os.path.join(root, "coverage_hits.txt")
		if os.path.exists(hits_path):
			os.remove(hits_path)
		probes = instrument(root)
		print("Probed %d lines in %s." % (len(probes), ", ".join(ROOTS)))
		code = run_suite(root)
		report(probes, hits_path)
		return code
	finally:
		if keep:
			print("\nInstrumented copy kept at " + root)
		else:
			shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
	sys.exit(main())
