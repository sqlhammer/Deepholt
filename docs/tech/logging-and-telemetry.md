# Logging and Telemetry

Two levels of record, built at different times for different readers.

| Level | For | Answers | Status |
|---|---|---|---|
| **1. Debug log** | Derik and Claude | "What just happened?" | Built in slice 013 (D-193 to D-197) |
| **2. Play-test telemetry** | The design, from other players | "How does the game play for real people?" | Planned as slice 014 (D-198 to D-207) |

Level 1's channels and event names are chosen so Level 2 can reuse them: one event shape, two
uses. Level 2 must not need Level 1 rewritten.

---

## 1. The debug log (Level 1)

### 1.1 The shape of an event

Every record is one event:

| Field | Meaning |
|---|---|
| `t` | Milliseconds since launch (`Time.get_ticks_msec()`) |
| `frame` | The physics frame it happened on (`Engine.get_physics_frames()`) |
| `channel` | One of the channels in §1.3 |
| `event` | A short snake_case name: `moved`, `move_to`, `jump`, `breached`, `refused` |
| `data` | A small dictionary: ids, tiles as `[x, y, depth]`, reasons as names |

Actors are always named by id, never as "the player": anything may log about any actor, and
nothing assumes there is one (rule [D-045](../design-decisions.md)).

### 1.2 How it's reached, and what it costs (D-193)

- **`Log` is a static class:** `Log.event(&"moves", &"move_to", {...})` from any file. There is
  no autoload, so it works in tests and in a world built outside the tree.
- **A call never touches the disk.** It appends the event to a ring buffer in memory and to a
  queue for the writer. A background thread formats the queue and appends it to the session
  file. The main thread pays a dictionary and two appends, behind a mutex, since the engine's
  own errors arrive from any thread.
- **Debug builds only.** In a release build `Log.event` returns at once.

### 1.3 Channels (D-196)

All are on by default in a debug build, and each can be switched off from F3.

| Channel | Records |
|---|---|
| `moves` | Each tile step; each level change; every `move_to` with its cause and caller; any jump of more than one tile in a frame, flagged when no `move_to` explains it |
| `world` | The world's answers: digs, breaches, fellings, placements, drops and takes done, and refusals with the reason by name. Not the requests: the world answers inside its own handler, before a later listener hears the request, and every request ends in one answer |
| `input` | Each action pressed or released, and the device scheme in use |
| `save` | Saves, loads and world swaps: what asked, the file, the time taken, problems |
| `support` | Regions starting to fail, collapses, actors moved clear |
| `perf` | Frames over budget, with process and physics time; level generation times |
| `errors` | Every engine error and warning, `push_error` and `push_warning` included, through a `Logger` |

### 1.4 Files on disk (D-197)

- **A session log:** `user://logs/session-<UTC time>.log`, one readable line per event. The 30
  newest are kept; Godot's own `godot.log` rotation keeps 30 too.
- **The ring buffer** holds the last 10 minutes, up to a fixed number of events.

### 1.5 Capturing a bug (D-194, D-195)

**Ctrl+F9**, or **left trigger + Y held for 2 seconds** on a pad, writes one folder,
`user://captures/<UTC time>/`, holding:

- `log.jsonl` — the last 10 minutes of events, one JSON object per line;
- `log.txt` — the same, readable;
- `world.save` — the running world, saved with the normal save code into the capture folder, so
  the player's own saves are untouched;
- `screenshot.png` — the screen as it was;
- `info.json` — build version, Godot version, OS, screen and window mode, input device, world
  seed, tuning profile, play time, and every actor's position.

The 20 newest captures are kept. Y does nothing while the left trigger is held, so the combo
doesn't toggle build mode in the state being captured.

---

## 2. Play-test telemetry (Level 2)

Planned as slice 014 (D-198 to D-207). For the pre-alpha's 5–8 unguided testers
([pre-alpha-scope §6](../pre-alpha-scope.md)): what they did, how the game ran, and whether it
crashed, without asking them.

### 2.1 Which builds record (D-201)

Only exported builds carrying the **`playtest`** feature tag, from the Windows and Linux export
presets (the Deck runs either). Development runs and any future store build record nothing.
Testers agree to the recording in a tester agreement before they get a build; the game shows no
prompt (D-200).

### 2.2 What's recorded (D-202)

The same event shape as the debug log (§1.1), on its own channel names:

| Group | Events | For |
|---|---|---|
| **Session** | `session_started` (build, OS, screen, GPU, tuning profile, world seed, new or loaded); `session_ended` (length, active play time); `crashed` (a session with no end, found at the next launch, with its length) | Length of play; stability |
| **Trips** | `trip_started` (depth left from); `trip_ended` (deepest level, time below, kilos carried home); `overloaded` time per trip | Pre-alpha criterion 5, backtracking fatigue |
| **Friction** | `refused` (verb and reason, counted); `climb_refused` for weight | What the game fails to teach |
| **Health** | frame-time percentiles (p50, p95, p99) per minute; save, load and generation times; error and warning counts with the first text of each | Performance on testers' machines |

**A trip** starts when a player goes below the depth they started the session on, and ends when
they come back up to it (a proposed definition, until there is a home; see the slice brief).

Each later slice adds the events for what it builds: the chute's first use (criterion 1), the
hoist (criterion 3), the smelter's site (criterion 4).

Nothing identifies the tester (D-204): no code, no install id, no names, no free text.

### 2.3 Files (D-199, D-205, D-206)

All in `user://telemetry/` on the tester's machine; nothing is sent by the game.

- **`session-<UTC>.jsonl`**: the session's events, appended as they happen, so a crash loses
  little.
- **`session-<UTC>.summary.json`**: written at session end: totals per group and the frame-time
  percentiles.
- **`crash-<UTC>.jsonl`**: after a crash, the last two minutes before it. In playtest builds the
  debug log's ring buffer runs, and its writer thread rewrites `user://logs/recent.jsonl` with
  the last two minutes every few seconds (D-203, D-207); the next launch, finding the crashed
  session's missing end, copies that file here.
- **`deepholt-telemetry.zip`**: the whole folder, refreshed at quit and at the next launch after
  a crash. Testers send this one file.

### 2.4 Reading it (D-206)

`scripts/telemetry_report.py` reads any number of zips and prints, per session and overall:
session lengths and crashes; trips (count, time below, deepest, kilos home, time overloaded);
refusals by reason; frame-time percentiles and slow saves; errors. Where the data reaches a
pre-alpha criterion it says so, and which it can't measure yet.

### 2.5 Not now

- **An upload** (a self-hosted endpoint, or a service): behind the same files, when sending by
  hand stops scaling (D-199).
- **Steam:** what Steam's terms ask of telemetry, when the game goes on Steam.
