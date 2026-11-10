# 014 — How it plays for other people

*Written by Claude, 2026-11-10.*

> A tester plays for an hour on their own machine and quits. One zip is waiting for them to send.
> Back home, a script reads it: two trips below, the second one forty minutes and overloaded half
> of it; "Breaching needs a pick" refused eleven times; frame times fine; no crash. And when there
> is a crash, the two minutes before it.

**Result:** built in Agent mode on `slice-014` (from `slice-013`, itself on `fix-world-edge`).
1122 tests in 58 scripts, green, and **no warnings**, for the first time in several slices (see
below). Coverage 94.1%; `telemetry.gd` 98%. The report script has its own four Python tests. The
4.7.2 export templates are installed. Both playtest builds export, and the Windows one was run:
killed mid-play, then relaunched and quit cleanly; the report showed the crash with its last
minutes, and the clean session with its summary. **Derik's ten-minute walk with a trip hasn't
been done.**

---

## What got decided

All of Derik's, asked up front as he requested, D-198 to D-208:

- **Telemetry next** (D-198), "Getting it home" to 015.
- **Local files sent by hand** (D-199); **consent in a tester agreement, no prompt** (D-200),
  over my recommended first-launch notice.
- **Playtest builds only, with presets** (D-201); **session, trips, friction, health** (D-202).
- **A crash's flag and last two minutes** (D-203), **through a rolling file on disk** (D-207).
- **No identity** (D-204), over my recommended tester code; **events and a summary** (D-205);
  **a zip at quit and a report script** (D-206).
- **A trip** runs from going below the depth a player started on to coming back up to it
  (D-208), my proposal, accepted.

**D-207 corrects my own framing of fork 6.** I offered "the ring buffer in memory only, so the
last two minutes go into the tester's folder". A crash ends the process and its memory, so that
couldn't work. I caught it while writing the design, before any code, and asked again.

**Choices made while building, not put to Derik:**

- **Telemetry writes its own events on the game's thread,** appended and flushed at once. They're
  rare (a trip, a refusal, a minute's frame times), unlike the debug log's, so a background thread
  would add more than it saves. The rolling crash file is the debug log's thread's work, as
  D-207 says.
- **The open marker records the session's length every 10 s,** so a crash's length is known to
  within that.
- **Frame times go into 1 ms buckets up to 250 ms** (the last holds anything slower), one set per
  minute and one for the session. A "frames" event per minute; percentiles are the bucket's upper
  edge.
- **Refusals count players only,** keyed `verb:REASON`; a climb refused for weight is
  `climb:TOO_HEAVY`.
- **Kilos home** is the pack's whole weight on arriving back, tools included.
- **An exported build that isn't tagged `playtest` logs nothing at all,** as before; a tagged one
  runs the debug log's ring and rolling file, but not its session file, its bug capture or
  stack captures.
- **The presets leave `tests/` and the GUT add-on out of the build;** both target x86-64, and the
  PCK is embedded, so each build is one file. Output goes to `build/`, now in `.gitignore`.
- **The report's criterion 5 check** flags sessions that ended below, or whose last trip was
  overloaded for over two minutes: the ones to ask the tester about. It's a prompt for the
  interview, not a verdict.
- **Testing the exported build used Derik's real user folder,** since an exported build has no
  other. Its saves were backed up first and compared after: unchanged. The test telemetry and
  rolling file were deleted afterwards, so his own run starts clean.

---

## What surprised

- **The first real run zipped an empty summary.** The summary file was still open, unflushed, when
  the zip read it. The tests hadn't looked inside the zip; one now does. Found only by running the
  exported build and reading its report, the same lesson as 013's log.
- **I'd been calling the suite's one warning "already there" for several slices,** against
  Derik's standing rule to fix a recurring warning at its cause. It was a float-against-int
  comparison in 012's `test_the_road_winds`; my new telemetry test added a second of the same
  kind. Both fixed; the suite now reports none.
- **GutTest already has a `_summary` member,** so a helper by that name failed to parse.
- **Windows lists a file another process still holds open at 0 bytes;** the killed session's
  events were there when read.
- **Python bytecode got committed** with the report script; removed and ignored.

---

## What to do differently

1. **(Claude) Never report a warning as "already there."** Fix it, or say plainly it's being
   left and why.
2. **(Claude) Before offering an option, check that it can work:** fork 6's first wording
   couldn't.
3. **(Claude) Read inside what a test produces** (a zip's contents, not just its existence).

---

## By-hand walk (nothing here has been done)

From the brief: export the Windows playtest build (Project → Export, "Windows Playtest", or
`godot --headless --path game --export-release "Windows Playtest" ../build/windows/Deepholt.exe`),
play ten minutes with a trip below and back, quit; `telemetry/` in the game's user folder holds
the session, its summary and the zip; `python scripts/telemetry_report.py <the zip>` reads it.
End the build from Task Manager mid-play, relaunch, quit: the report shows the crash and its last
minutes. A run from the editor writes nothing to `telemetry/`.
