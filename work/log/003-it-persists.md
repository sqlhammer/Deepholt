# 003 — It persists

*Written by Claude, 2026-11-01.*

> Save a dug world, quit, relaunch, and your corridor is still there, on every level, with the
> ladder and the spawn where they were, and you're standing where you stopped.

**Result:** outcomes 1–7 walked through by hand (Derik). The suite passes, 637 tests with no
skipped files and no leak warning; coverage 95.1% (1768 of 1860 probed lines; 002 closed at
98.9%), and the playtime clocks are the largest untested piece. The slice was trimmed halfway
through: the code review on 2026-10-29 traced every load bug to one assumption, that the tree
holds exactly one world, and fixing that became slice 004
([D-118](../../docs/design-decisions.md#d-118--the-world-is-a-node-that-owns-its-levels-and-id-counters-handed-by-reference)).

---

## What got decided

Fifteen decisions, D-109 to D-123. Grouped by the questions the slice ended up asking:

**What a save is, and when it's written.** One `store_var` file per slot, written by a static
`SaveGame` class that encodes whatever it's handed; `game.gd` decides when
([D-109](../../docs/design-decisions.md)). A save is written on quit, on every level change, on a
timer and on a debug key (D-110). Launch continues the save; `--new-game` starts fresh and moves
the old one aside; every write keeps one backup; a refused save is kept and the backup loads,
loudly; both refused and the game won't start (D-111).

**What's in it.** Tile layers by name, one byte layer per fact, compressed one by one; a saved
bound wins over the recipe (D-112). Loaded fixtures go straight in, then are checked and
reported, never dropped (D-113). Actors get int ids and save id, kind, name, depth, tile and
facing (D-114). The save names the local actor, and an actor on a tile that's no longer passable
goes to the spawn (D-115). The header (D-116) was refined late in the slice: playtime is two
clocks, active and total (D-120); three keys are required and the rest default (D-121), the save
time is a UTC Unix int and the writer's offset, also required (D-122); moved-aside saves are named
with a UTC time in ISO basic format (D-123).

**What a world is, and what an actor is handed.** An actor is handed the level it starts on
(D-117). The review led to the world becoming a node that owns its levels and its id counters,
handed by reference and never looked up (D-118), built in 004. `change_depth` became `move_to`,
the one way an actor is put somewhere else (D-119).

**Settled by Derik in conversation, not as a D-nnn:** save format version 1 isn't settled yet,
so until versions are tracked, a header change edits v1 in place, with no bump or migration.
Neither the timer's save nor the load is felt, so the save stays on the main thread.

---

## What surprised

**The review found one cause behind every load bug.** Ten bugs and eleven pitfalls, and most of
them came back to the tree holding exactly one world: a load built actors against the old levels,
left the world with no levels at all when every saved one failed, or kept listening to the
levels it had replaced. Rather than patch each, the slice was trimmed and the
fix became 004's whole job.

**A move during a load saved a half-built world.** Moving a stuck actor to the spawn crossed a
depth, which saves (D-110), while the load was still building. The fix was ordering: the move
happens before `game.gd` listens to the actor (D-119). A save after a freed actor also raised
"previously freed" errors until the active actor was cleared with the rest.

**A refactor's signature change broke tests three times.** `SaveGame.save_game` grew from five
positional parameters to nine across the slice, and each addition broke every call site in the
tests. Hand-written saves broke the same way each time a header key became required, until a
helper filled the required keys in.

**Godot prints engine errors for a truncated save that no code can catch.** `get_var` on a file
cut short logs errors and returns null. The reader now checks each value's length prefix before
decoding, so a truncated file is refused quietly.

**A leak warning was reported for days as "pre-existing".** Every full run ended with 9 leaked
objects and 5 resources. It was compared against `HEAD`, called a baseline and repeated in every
report, until running each test file alone found it in one test: a lambda that captured the
`LevelTiles` it was connected to, a reference cycle. A one-line change ended it.

**The load's cost wasn't where it was blamed.** A full load took about 470 ms, put down to
regenerating every level before the save replaced it. Building levels from the save removed the
regeneration and the time didn't move. The real cost was `LevelTiles.new` setting every tile of
every level in a GDScript loop. With `fill` instead, a load takes about 100 ms, and the test
suite dropped from about 66 s to about 15 s.

**Windows reports daylight saving in Godot's time zone bias.** It looked unverifiable in
November. Godot 4.7.2's source adds the daylight bias when daylight time is in effect, so the
saved offset is right all year.

**The tooling around Claude cost time again.** Heredocs broke on quotes, scripted edits missed on
tabs in blank lines and trailing spaces, and a standalone parse check can't see the autoloads.

---

## What to do differently

1. **Pass the save its world as one thing, not as a growing list of parameters.** Nine positional
   parameters meant every new header field broke every caller. 004's world node is the natural
   fix: `save_game(slot, world, …)`.
2. **Measure the parts before naming the cause.** Slice 002's lesson came round again: the load
   time was attributed without a breakdown, and the first fix aimed at the wrong thing.
3. **(Claude) Find the cause of a recurring warning; don't baseline it.** A warning that's in
   every run is either fixed or explained by its cause, never by "it was there before".
4. **(Claude) Read the test's signal of a cycle literally.** "Resource still in use: the test
   script" means something still holds the test; a captured variable in a connected lambda is the
   first place to look.
5. **Keep the review's ids.** R-B1 to R-S4 kept their numbers through two re-checks, so "do R-B8"
   needed no lookup. Worth repeating for 004's review.
6. **(Claude) Script edits from files, not heredocs,** as 002 already said. Applying it each time,
   not just once, is the change.

---

## Open, carried forward

- **To 004, from the review:** a level built from its saved bound (R-B4); one load in phases
  (R-S1); `_get_levels_from_save_data` goes when `SaveGame` returns a world (R-S3).
- **To 004, found at the end of 003:** after a load, the actor id counter isn't moved past the
  loaded actors' ids. `IdAllocator.claim` exists and nothing calls it, so a player created after
  a fresh launch's load can take an id a loaded actor has. The fixture counter has the same fix
  in place, until 004 saves both counters.
- **Small, unscheduled:** the slots are taken in `get_directories()` order, which nothing
  guarantees (R-P6); dead tool-loading code (`_load_tool`, `TOOL_DIR`, the `equipped` check,
  R-B5); "it's" → "its" in three comments and comments over 70 characters (R-S4).
- **[save-files.md](../../docs/tech/save-files.md) is behind the code:** it still lists
  `playtime_seconds`, says every missing key loads as its default (D-121 and D-122 changed that),
  and lists the timestamp format as undecided (D-123).
- **The autosave interval is a placeholder:** 300 s, since D-110 leaves the number open.
- **The playtime clocks have no tests** (D-120): the timer scripts, `Global.format_duration`,
  F3's playtime lines, and `stats` round-tripping through a save. Most of 003's coverage drop.
- **Nothing prunes old saves.** Moved-aside and broken saves pile up in the slot folder.
- **Outcome 3's wording** ("the ramp, the hole and the ladder") reads as one per level. The world
  has one of each, between the Surface, −1 and −2.
