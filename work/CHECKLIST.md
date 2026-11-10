# Slice 013 checklist

Working list for [NOW.md](./NOW.md). **Agent mode** (Derik, 2026-11-10), on a `slice-013`
branch: Claude builds, the suite green before each commit; Derik merges the PR and verifies by
hand. Numbers in brackets are the brief's outcomes.

Slice 012's checklist is in git history (last at the 012 close).

---

## A. Decided in planning

*Settled with Derik, 2026-11-10.*

- [x] A static `Log`; never writes on the game's thread (D-193).
- [x] Ctrl+F9 (D-194); left trigger + Y held 2 s (D-195).
- [x] Every channel on by default (D-196).
- [x] 10 minutes, 30 logs, 20 captures (D-197).
- [x] The design doc, both levels: [logging-and-telemetry](../docs/tech/logging-and-telemetry.md).

## B. The log

- [x] `Log`: events, channels, the ring buffer, the writer thread, the session file and its
  pruning; release builds log nothing. [4, 5]
- [x] Engine errors and warnings through a `Logger`. [5]
- [x] Tests: cost per call, ordering, buffer window, channel switches, pruning, the thread
  writes the file, release builds. [5]

## C. What's logged

- [x] moves: steps, level changes, `move_to` with cause and stack, unexplained jumps. [1, 5]
- [x] world and support: from the world's signals. [1, 5]
- [x] input: actions and device. [1, 5]
- [x] save: saves, loads, swaps, moved-if-stuck. [5]
- [x] perf: slow frames; generation times. [5]

## D. Capturing

- [x] Ctrl+F9 and the pad combo; Y skipped while the trigger is held. [1, 2]
- [x] The folder: log.jsonl, log.txt, world.save, screenshot.png, info.json; pruned to 20. [1]
- [x] F3: the channels, switchable. [3]
- [x] Tests for each. [5]

## E. Done

- [x] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
- [x] `python scripts/coverage.py` run; uncovered lines looked at.
- [ ] By hand: outcomes 1–4.
- [x] Claude reviews the slice.
- [x] Claude writes `log/013-what-just-happened.md`.
- [x] Claude re-sketches [NEXT.md](./NEXT.md).
