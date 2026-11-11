# Slice 014 checklist

Working list for [NOW.md](./NOW.md). **Agent mode** (Derik, 2026-11-10), on `slice-014`. Numbers in brackets are the
brief's outcomes.

Slice 013's checklist is in git history (last at the 013 acceptance).

---

## A. Decided in planning

*Settled with Derik, 2026-11-10.*

- [x] Next, before "Getting it home" (D-198).
- [x] Local files, sent by hand (D-199); a tester agreement, no prompt (D-200).
- [x] Playtest builds only, with presets and a `playtest` tag (D-201).
- [x] Session, trips, friction, health (D-202).
- [x] A crash's flag and last two minutes (D-203), through a rolling file (D-207).
- [x] No identity (D-204); events and a summary (D-205); a zip and a report script (D-206).
- [x] What a trip is (D-208).

## B. Builds

- [x] The 4.7.2 export templates installed (trap 1).
- [x] Windows and Linux export presets with the `playtest` feature tag. [1, 4]
- [x] `Log.enabled` for playtest builds: the ring and the rolling file, no session file (trap 2).

## C. Recording

- [x] A `Telemetry` recorder: the session file, events as they happen, recording only with the
  tag or the test flag. [1, 4]
- [x] Session events; the open marker and the crash found at the next launch (trap 3). [3]
- [x] Trips per player, by the agreed definition; time overloaded; kilos home. [1, 2]
- [x] Friction: refusals by reason, climbs refused. [2]
- [x] Health: frame-time histograms and percentiles (trap 5); save, load and generation times;
  error counts. [2]
- [x] The summary at session end; the zip at quit and after a crash (trap 4). [1, 3]

## D. Reading

- [x] `scripts/telemetry_report.py`: per session and overall, and the pre-alpha criteria it can
  speak to. [2]
- [x] A fixture zip for its test. [5]

## E. Done

- [x] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
- [x] `python scripts/coverage.py` run; uncovered lines looked at.
- [x] By hand: outcomes 1–4, from an exported build (Derik, 2026-11-10; A4, the Linux build on
  the Deck, not run).
- [x] Claude reviews the slice.
- [x] Claude writes `log/014-how-it-plays-for-other-people.md`.
- [x] Claude re-sketches [NEXT.md](./NEXT.md).
