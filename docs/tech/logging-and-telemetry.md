# Logging and Telemetry

Two levels of record, built at different times for different readers.

| Level | For | Answers | Status |
|---|---|---|---|
| **1. Debug log** | Derik and Claude | "What just happened?" | Built in slice 013 (D-193 to D-197) |
| **2. Play-test telemetry** | The design, from other players | "How does the game play for real people?" | Draft below; for later planning |

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
| `world` | Dig, breach, chop, build, drop and take requests, their results, and refusals with the reason by name |
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

## 2. Play-test telemetry (Level 2) — draft, for later planning

Nothing here is decided. It records the shape agreed in conversation (2026-11-10) so the
debug log's events grow into it.

### 2.1 What it would collect

- **Session:** build version, tuning profile id (already in the save, D-037), world seed,
  platform, resolution, input device, session length. A session with no recorded end is
  reported as a crash on the next launch.
- **The loop:** time to the first descent; deepest level and when; time overloaded; kilos
  hauled home; items mined and built; collapses, and whether the player was caught.
- **Friction:** refusal counts by reason. Many "Breaching needs a pick" means something isn't
  taught.
- **Tuning:** the low-confidence numbers in the [tuning appendix](../tuning-appendix.md) (level
  radii, hunger) are the ones "to instrument first in playtest".
- **Health:** frame-time percentiles; save, load and generation times; error and warning
  counts with the first text of each.

### 2.2 How it differs from Level 1

- **Few events, summarized,** not every step: counts and durations per session.
- **Nothing personal;** no free text from the player; the seed and positions only as the game
  knows them.
- **Opt-in,** with a consent screen and a privacy note.
- **In release builds,** where Level 1 is off.

### 2.3 Forks to settle when it's planned

1. **Where it goes:** a local file only (players send it), a small self-hosted endpoint, or a
   service (Sentry for crashes, GameAnalytics or similar for events).
2. **Consent:** when it's asked, what's said, how it's withdrawn.
3. **The event list:** which of §2.1, named how, summarized how often.
4. **Crash reports:** whether a crash sends the last minutes of the Level 1 buffer, which
   would mean keeping that buffer in release builds.
5. **Steam:** what Steam's terms and the Deck ask of telemetry.
