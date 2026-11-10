# Slice 014 — How it plays for other people

> A tester plays for an hour on their own machine and quits. One zip is waiting for them to send.
> Back home, a script reads it: two trips below, the second one forty minutes and overloaded half
> of it; "Breaching needs a pick" refused eleven times; frame times fine; no crash. And when there
> is a crash, the two minutes before it.

*Proposed by Claude, 2026-11-10, after Derik accepted slice 013 and asked for the telemetry slice
to be planned with every fork asked up front. Forks settled as
[D-198](../docs/design-decisions.md#d-198--slice-014-is-play-test-telemetry-getting-it-home-moves-to-015)
to D-207 (D-207 corrects how D-203 keeps a crash's last minutes). Design:
[logging-and-telemetry §2](../docs/tech/logging-and-telemetry.md#2-play-test-telemetry-level-2).
Planned on a `slice-014` branch from `slice-013` (PR #10, itself on #9). **Agent mode** (Derik,
2026-11-10). **Built, 1122 tests green; waiting on the by-hand walk**
([log](./log/014-how-it-plays-for-other-people.md)).*

## Where we are

Slice 013 is accepted ([log](./log/013-what-just-happened.md)): a debug log in debug builds, a
bug capture, a session file. Nothing records anything in an exported build, and there are no
export presets, so there is no build a tester could run. The pre-alpha's success criteria
([pre-alpha-scope §6](../docs/pre-alpha-scope.md)) are judged on 5–8 unguided testers; criterion
5, nobody quitting from backtracking fatigue, is the kill switch.

## What should be true when you stop

By hand, unless marked:

1. Export a Windows playtest build from the new preset and play it for ten minutes, including a
   trip below and back. Quit. `telemetry/` holds the session's events, its summary and
   `deepholt-telemetry.zip`.
2. `python scripts/telemetry_report.py <the zip>` prints the session: its length, the trip (time
   below, deepest level, kilos home, time overloaded), refusals by reason, frame-time
   percentiles, save and load times, errors; and which pre-alpha criteria it can and can't speak
   to yet.
3. End the playtest build's process from Task Manager mid-play, then launch it again: the report
   shows a crash, its session's length, and the last two minutes before it.
4. A development run (from the editor, or an export without the `playtest` tag) writes nothing to
   `telemetry/`.
5. *Automated:* trips start and end by the definition below; each group's events and summary
   totals; percentiles; the crash flag and the rolling file's handover; the zip's contents; no
   identity anywhere in the data; recording only with the tag; the report script against a
   fixture zip.

## Mode

**Agent** (Derik, 2026-11-10), on `slice-014`, including installing the 4.7.2 export
templates; Derik merges the PR.

## What you're deciding

Settled in planning (2026-11-10):

- **Next, before "Getting it home"** (D-198).
- **Local files, sent by hand** (D-199); **a tester agreement, no prompt** (D-200).
- **Playtest builds only, with Windows and Linux presets and a `playtest` tag** (D-201).
- **Session, trips, friction, health** (D-202).
- **A crash's flag and its last two minutes** (D-203), **through a rolling file on disk**
  (D-207).
- **No identity** (D-204); **events and a summary per session** (D-205); **a zip at quit and a
  report script** (D-206).

- **What a trip is** (D-208). There is no home yet (no bed until M6), so: a trip starts when a player goes
  below the depth they started the session on, and ends when they come back up to it. A session
  that ends below counts its trip as unfinished.

## Already settled

- **One event shape for both levels** ([logging-and-telemetry §1.1](../docs/tech/logging-and-telemetry.md)):
  telemetry reuses the debug log's `{t, frame, channel, event, data}`.
- **The debug log's writer never blocks the game** (D-193): the rolling crash file is its work,
  on its thread.
- **No system assumes one player** (rule [D-045](../docs/design-decisions.md)): trips are per
  actor, for every player.
- **The save records its tuning profile** (D-037, D-116): telemetry names it too, so a session's
  numbers can be traced.
- **Signals over direct calls** ([coding-standards](../docs/coding-standards.md)): trips and
  friction are heard from the world's and the actors' signals, as the debug log's are.

## Traps

### 1. Export templates

Only Godot 4.5.1's export templates are installed; the game runs on 4.7.2. No build can be made
until the 4.7.2 templates are installed (Editor → Manage Export Templates, about 1 GB). A by-hand
step for Derik unless the mode is Agent and he says to download them.

### 2. "Debug builds only" changes

The debug log is off in release builds (D-193); playtest builds are release builds that need its
ring and the rolling file (D-203, D-207), but not its session file, its stack captures or F3's
switches. `Log.enabled` becomes "debug build or playtest tag", with the session file still
debug-only.

### 3. A crash can't be seen from inside

Nothing runs when the process dies. A session marks itself open on disk at start and closed at a
clean end; the next launch finding it open is the crash. Ending through the window's close
button, Alt+F4 or the save-and-quit key is a clean end; Task Manager, a power cut or a Deck
suspend that never resumes is a crash.

### 4. The zip at quit

Quit must write the summary, close the event file, stop the log's thread and then zip, in that
order, before the process ends. A crash skips all of it, which is why the next launch zips too.

### 5. Percentiles without keeping every frame

An hour is ~200,000 frames. Frame times go into fixed buckets (a histogram) per minute;
percentiles are read from the buckets.

### 6. Tests can't export

`OS.has_feature("playtest")` is false in the editor and in tests. Recording is switched on by the
tag in a build and by a flag in tests; one test checks the presets carry the tag.

### 7. Nothing identifying

No tester code, install id or names (D-204); but the OS, GPU and screen are recorded. Those
describe the machine, not the person; the tester agreement (D-200) should say they're collected.

## Carried into this slice

- **By-hand walks of 008 to 013,** not reported item by item.
- **The jump on −1** stays open until the debug log catches it.
