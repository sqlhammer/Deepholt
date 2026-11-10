# Slice 013 — What just happened

> You breach a floor and find yourself forty tiles back, where you came into the level. Nothing
> said why. Next time, Ctrl+F9 puts the last ten minutes in a folder: every step, every key, every
> request the world answered, and a save of the moment.

*Proposed by Claude, 2026-11-10, after Derik asked for a debug log ahead of "Getting it home"
and approved planning and building it in Agent mode. Forks settled as
[D-193](../docs/design-decisions.md#d-193--slice-013-is-a-debug-log-the-log-is-a-static-class-that-never-writes-on-the-games-thread)
to D-197. Design: [logging-and-telemetry §1](../docs/tech/logging-and-telemetry.md). Built on a
`slice-013` branch from `fix-world-edge` (PR #9), so it carries D-192. **Built, 1106 tests
green; waiting on the by-hand walk** ([log](./log/013-what-just-happened.md)).*

## Where we are

Slice 012 is merged ([log](./log/012-a-world-worth-digging.md)). The game logs only its 76
errors and warnings, through Godot's own file, which keeps five sessions. On 2026-11-10 Derik's
actor was moved from (46, 1) on −1 back to where it entered the level, right after a breach; the
hole stayed, so it wasn't a load. A breach from his save, replayed in the real game scene, moved
nothing, and the session's log had been rotated away.

## What should be true when you stop

By hand, unless marked:

1. Play a minute, press **Ctrl+F9**: a notice names a folder under `captures/`, holding a
   readable log of that minute (your steps, keys, digs and breaches by actor id), a save that
   loads, a screenshot and an `info.json`.
2. On a pad, **left trigger + Y held for 2 s** does the same, once per hold, and Y doesn't toggle
   build mode while the trigger is held.
3. F3 lists the log's channels, on or off, and switching one off stops its lines in the session
   log.
4. The session log is in `logs/`, written while you play, and the game doesn't stutter for it.
5. *Automated:* a call costs microseconds and never writes on the game's thread; every
   `move_to` is logged with its cause; a jump of more than one tile with no `move_to` is logged
   as unexplained; world requests and refusals, saves and loads, collapses, input and engine
   errors reach the log; captures and session logs are pruned to 20 and 30; nothing logs in a
   release build.

## Mode

**Agent** (Derik, 2026-11-10), on `slice-013`; Derik merges the PR.

## What you're deciding

All settled in planning:

- **The log's form** (D-193): a static class; a call appends to memory, a thread writes.
- **Capture keys** (D-194, D-195): Ctrl+F9; left trigger + Y held 2 s.
- **Defaults** (D-196): every channel on.
- **Retention** (D-197): 10 minutes in a capture, 30 session logs, 20 captures.

## Already settled

- **No system assumes one player** (rule [D-045](../docs/design-decisions.md)): events name
  actors by id; nothing logs "the player".
- **Signals over direct calls** ([coding-standards](../docs/coding-standards.md)): the world's
  requests, answers, collapses and level additions are logged by listening to its signals.
- **A save may only be written inside its saves root** (D-109's static class): the capture's
  save goes through the normal save code, with the capture folder as its root.

## Traps

### 1. Threads

The writer thread and the engine's `Logger` callbacks run off the main thread. Everything they
share (the ring buffer, the queue) goes behind one mutex; the thread touches nothing else in the
game. The thread is joined at quit, or the last lines are lost.

### 2. Logging the logger

An engine warning raised while logging would log itself. The `Logger` hook ignores anything
raised from inside `Log`.

### 3. Tests

GUT's expected `push_error`s will reach the errors channel; tests start from a cleared log and
never start the writer thread unless they test it.

### 4. The jump detector needs a cause to compare against

A jump is only "unexplained" if no `move_to` ran for that actor in the same frame. `move_to`
takes a cause from every caller (ramp, ladder, collapse, spawn, load), and records the call
stack in debug builds.

## Carried into this slice

- **By-hand walks of 008 to 012,** not reported item by item.
- **The jump bug itself** stays open: this slice is how it gets caught.
