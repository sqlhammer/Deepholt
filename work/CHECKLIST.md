# Slice 003 checklist

Working list for [NOW.md](./NOW.md). Ordered so something is on screen early, not by code
dependency: one level's tiles survive a relaunch before fixtures, actors or versioning exist.
Every fork the brief raised was settled upfront on 2026-10-23 as
[D-109](../docs/design-decisions.md#d-109--a-save-is-one-store_var-file-per-slot-owned-by-a-static-class)
to [D-116](../docs/design-decisions.md#d-116--the-save-header-and-a-placeholder-tuning-profile-id),
except one that needs the running game. Items below build what was decided; each names the
decision it carries out. **Decide, by looking** items need the running game. Numbers in brackets
are the brief's by-hand outcomes.

The save system's rules, in one readable place:
[docs/tech/save-files.md](../docs/tech/save-files.md).

Slice 002's checklist is in git history (last at `f0681b2`).

---

## A. Decided upfront

*No mode: settled in conversation, 2026-10-23.*

- [x] A static `SaveGame` class encodes and decodes whatever levels and actors it's handed;
  `game.gd` decides when. `store_var` dictionaries, `allow_objects` off; one file per save; ZSTD
  per tile array; `user://saves/<slot>/world.save` (D-109).
- [x] Saves happen on quit, on every level change, on a timer, and on a debug key (D-110).
- [x] Launch continues if a save exists; `--new-game` starts fresh and moves the old save aside;
  every write keeps a `.bak`; a refused save is kept as `world.broken.<timestamp>.save` and the
  backup loads, loudly; both refused means the game refuses to start (D-111).
- [x] Tile layers saved by name, a byte layer per per-tile fact; the code's layout replaces
  world-runtime §3's; a saved bound wins over the recipe (D-112).
- [x] Loaded fixtures go straight in, then are checked and reported, never dropped (D-113).
- [x] Actors get int ids from a world counter, and save id, kind, name, depth, tile and facing
  (D-114).
- [x] The save names `local_actor_id`; an actor loaded onto an impassable tile goes to the world
  spawn, with a warning (D-115).
- [x] Header fields, `tuning_profile_id` written as `"none"`, no `game_time` (D-116).

Still open, small enough to pick while building: the slot folder's name, the autosave interval,
and the quicksave key (D-109, D-110).

## B. One level's tiles, round trip

*Mode: Educational Assistant (2026-10-23). Walkthrough in `work/lesson/003-B-tiles-round-trip.md`.*

The first thing on screen: a dug tile survives a relaunch.

*Staging (sequencing, not a design decision):* in B, launch still generates all eight levels,
then each level's saved layers replace its arrays. Fixtures, the spawn and the player come from
generation until C replaces "generate, then overlay" with "build from the save". A saved bound
that doesn't match the generated level is warned about and that level is skipped; the real
saved-bound-wins path is in C.

- [x] `SaveGame` exists as a static class in `src/persist/`, taking a path, with a save and a
  load function. Saves
  write `world.save.tmp` and rename it over `world.save` (trap 4; the `.bak` step arrives in E).
- [x] The file is read with `get_var` and `allow_objects` left off (trap 3).
- [x] Each tile layer is written by name and compressed with ZSTD; the decompressed size is
  checked against the saved bound's side squared before it's taken (D-109, D-112, trap 5).
- [x] `LevelTiles` gets a bulk load path that neither trips the warning setters nor emits a
  `tile_changed` per tile (trap 5). A layer missing from the save fills its default (D-112).
  *Its tests: Agent mode, at Derik's request (2026-10-24). So are the tests for
  `SaveGame.serialize`, `deserialize` and `save_game` (2026-10-25) The fix to `deserialize`'s
  layer sizing and radius check, its type checks, and the depth, typing and
  version cleanups, and `save_game`'s saves-root parameter: Agent mode
  (2026-10-25/26).*
- [x] Each level's bound is saved as plain ints, never as the `LevelBound` resource (an object
  can't go through a save with `allow_objects` off).
- [x] The game scene's save path can be set before `_ready`, so tests that load `game.tscn` never
  read or write the real save. *`game.gd`'s `saves_root`, passed to every `SaveGame` call;
  Agent mode, 2026-10-29/30 (R-P5).*
- [ ] Save on quit: window close, with `set_auto_accept_quit(false)`, save, then quit; and an
  `Esc` quit, which doesn't exist yet. Save on a debug quicksave key (D-110, trap 2).
- [ ] Launch loads the save if there is one, and generates otherwise (D-111). The load lands
  before `View` first shows a level, or the view is re-pointed after it; the renderers build from
  the loaded tiles, with no replay ([D-065](../docs/design-decisions.md)).
- [ ] world-runtime §3 gets a note: the tile table is replaced by byte layers per D-112.
- [x] Test: save a level, load it into a fresh `LevelTiles`, and every layer is byte-identical.
- [x] Test: a load emits no per-tile `tile_changed`.
- [ ] Test: a save file holding an object is not decoded as one (`allow_objects` off).
- [ ] By hand: dig on the Surface, quit, relaunch, still dug. [1]

## C. Every level, fixtures and ids

*Mode: ask before starting.*

*Trimmed 2026-10-30 (D-118):* building the world from the save, saved bounds and the id
counter's restore moved to slice 004, which reshapes them. They're listed under
[Moved to slice 004](#moved-to-slice-004-d-118) below. Until then, B's staging holds: launch
generates, then the save's layers and fixtures replace what was generated.

- [x] All eight levels are saved, including the untouched solid ones below −2 (save the result,
  not the recipe).
- [x] Each level's `level_seed` is saved as a number and set from the save on load, **after**
  `set_depth`, which re-hashes it (trap 7, D-116).
- [ ] A saved depth with no recipe row is refused, not clamped: `Level.clamp_depth` folds it onto
  the last level without a word.
- [ ] Each level's fixtures are saved as kind, tile and id; kind ids are numbers, and are forever
  ([D-104](../docs/design-decisions.md)).
- [ ] `LevelFixtures.add` refuses the same fixture twice (carried from 002, trap 6).
- [ ] After a load, `placement_problem` runs on every fixture and `ramp_problems` and
  `ladder_problems` on the world; each problem is a `push_warning`, F3 shows the count, nothing
  is dropped (D-113).
- [ ] The world spawn is a fixture, so it comes back like any other
  ([D-091](../docs/design-decisions.md)).
- [ ] Save on every level change, after the actor arrives (D-110).
- [x] Test: a world with digs on three depths round-trips, each depth only its own.
- [ ] Test: a fixture that breaks a placement rule loads, and is reported.
- [ ] By hand: dig on the Surface, −1 and −2, quit, relaunch, check each. [2]
- [ ] By hand: the ramp, the hole and the ladder still work, both ways. [3]

## D. Actors

*Mode: ask before starting.*

- [ ] Every actor gets an `actor_id` from a counter when it's created, and saves it (D-114).
  Where the counter lives, and saving and restoring it, are in slice 004 (D-118). Expect the
  counter's home here to be redone there.
- [ ] An actor saves id, kind (`"player"`), name, depth, tile and facing; it loads at the center
  of its tile. Not capabilities, not a dig in progress, not the equipped tool (D-114).
- [ ] `SaveGame` saves every actor it's handed and never picks one (trap 1,
  [D-045](../docs/design-decisions.md)).
- [ ] On load, `game.gd` grants capabilities and the players group by kind, not by "the first
  one".
- [ ] The save records `local_actor_id`, handed in by `game.gd`; on load, input, the view, the
  camera and F3 go to that actor, falling back to the lowest-id player with a warning (D-115).
- [ ] A loaded actor is not sent to the world spawn ([D-091](../docs/design-decisions.md)),
  unless its tile is impassable: then it goes there, with a warning naming it and the tile
  (D-115).
- [ ] Test: two actors on different depths round-trip, each to its own depth and tile.
- [ ] Test: with two players saved, the local one is the one `local_actor_id` names, whichever
  order they're saved in.
- [ ] Test: an actor saved on a tile made impassable loads at the spawn.
- [ ] By hand: quit on −2 facing west; relaunch on the same tile, facing west. [4]

## E. Versions, header and broken saves

*Mode: ask before starting.*

- [ ] `format_version` is an integer from the first save, with a migration function per step and
  a no-op first migration ([world-runtime §7](../docs/tech/world-runtime-and-persistence.md)).
- [ ] The header holds what D-116 lists: `world_seed`, `tuning_profile_id` (`"none"`),
  `local_actor_id`, `playtime_seconds`, `saved_at`, `game_version`. Keys are read by name; a
  missing key loads as its default. The two id counters join the header in slice 004 (D-118).
- [ ] `application/config/version` is set in the project, so `game_version` has a value.
- [ ] Playtime adds up across sessions: the loaded value plus this session's time.
- [x] Every write rotates: `world.save.tmp` → old `world.save` to `world.save.bak` →
  `world.save.tmp` to `world.save` (D-111).
- [ ] A save from a newer version, a truncated save and an unreadable save are each refused,
  renamed to `world.broken.<timestamp>.save` and kept; the backup loads instead, with a
  `push_error`, an on-screen message that stays up, and F3 saying so (D-111). [6]
- [ ] No `world.save` but a `world.save.bak` is a fallback, never a new game (D-111).
- [ ] If the backup is refused too, the game doesn't start: no world, no saving, both files left
  alone, and a message naming both reasons and paths (D-111). [6]
- [ ] Derived data isn't saved and is rebuilt on load: today, the renderers' textures and the
  view ([world-runtime §3](../docs/tech/world-runtime-and-persistence.md)).
- [ ] `F3` shows loaded, new or from the backup, and the format version. [7]
- [ ] Test: each refusal, and the fallback to the backup, without a running scene.
- [ ] Test: the missing-save-with-backup case loads the backup.
- [ ] Test: a save with a key missing loads it as its default.

## F. New game, the timer, and feel

*Mode: ask before starting.*

- [ ] `--new-game` (a user argument after `--`) moves an existing save aside to
  `world.<timestamp>.save` before anything is generated (D-111).
- [ ] The autosave timer runs while playing; its interval is a named constant, to move into the
  tuning profile when it's built (D-110, D-116).
- [ ] By hand: new game with a save present gives a fresh world, and the old save is beside it,
  intact. [5]
- [ ] Measure a full save and a full load at all eight levels.
- [ ] **Decide, by looking:** is the timer's save felt mid-play? Over about a frame, split it into
  a main-thread snapshot and a compress-and-write on a worker thread (D-110). Is the load felt at
  launch?

## R. Save/load code review (2026-10-29)

*Mode: ask before starting.* Review of B's F5/F6 save and load (commit `4b0243f`), re-checked
against the code on 2026-10-30. Ids match the review, so they can be referred to by number.
Items marked **→ 004** are part of slice 004's job
([Moved to slice 004](#moved-to-slice-004-d-118)); they stay here only so the list is complete.

**Bugs**
- [x] **R-B1. A test broke.** `test_create_player_stands_on_the_tile_given` passes again.
  `game.load_game()` has an end-to-end test now (`test_a_load_puts_the_player_on_a_level_in_the_tree`).
- [x] **R-B2. The type checks for a damaged save never got to run.** Levels and actors are now
  each checked in their loop, before the typed call.
- [ ] **R-B3. A load can leave the world with no levels and crash, or with some missing.**
  `_deserialize_levels` skips bad levels; if all fail, `game.gd` frees the running world and
  attaches nothing, and the actor has no level. The load has to be all or nothing.
  **→ 004** for the swap itself (build the new world to one side, check it, swap it in one move).
  A guard here meanwhile: refuse the load if any saved level didn't come back.
- [ ] **R-B4. A level whose radius was tuned disappears on load.** `_deserialize_level` builds
  from the recipe, not the saved bound, so a different radius fails the size check and the level
  is dropped (D-112 says the saved bound wins). **→ 004.** A saved depth with no recipe row still
  crashes in `generate_level`: that part is C's "refused, not clamped" item.
- [x] **R-B5. The saved tool's path was passed to `load()`,** which could run code from an edited
  save. `_load_tool` now only loads `ToolData` from inside `TOOL_DIR`. **Open:** D-114 decided
  the equipped tool is *not* saved. Saving it needs a D-nnn reversing that part of D-114, or the
  field comes out.
- [x] **R-B6. Actors were created against the old levels.** Fixed by D-117: actors are handed the
  levels the load built. The workaround `setup()` and its `# PROBLEM` comment are gone.
- [ ] **R-B7. Actors that aren't active are lost and leak.** `game.gd`'s load only calls
  `_create_player` for actors with `is_active`; the rest are never added to the tree or freed.
  Any actor flagged active gets `_create_player`, so an edited save with two gets two input
  handlers. Overlaps D's items on `kind` and `local_actor_id`.
- [ ] **R-B8. The input handler frees itself while it's running.** F6 → `InputHandler._input` →
  `game.load_game()` → `_free_inputhandlers()` → `free()` on the handler still on the stack. Use
  `queue_free()` after `remove_child`, or start the load with `call_deferred`.
- [ ] **R-B9. The fixture renderer keeps showing the old level when the depth doesn't change.**
  It rebuilds only on `shown_depth_changed`. A load onto the depth already shown leaves it
  listening to the old level's `LevelFixtures`, and its ladder tops reading the old tiles.
  `refresh_current_view` re-points tiles only. 004 re-points every listener on a swap; this can
  be fixed here first.
- [ ] **R-B10. Small ones.**
  - `_serialize_actors` calls `_serialize_actor` twice per actor.
  - `_get_file_data` copies the body's keys over the header, so the body's `format_version`
    replaces the header's.

**Pitfalls for the future**
- [ ] **R-P1. The code has drifted from D-114 and D-115.** Actors are keyed by `actor_name`, not
  `actor_id`, so two actors with one name overwrite each other. No `kind`. A per-actor
  `is_active` flag where D-115 has one `local_actor_id`. The equipped tool is saved (R-B5).
  These are D's items.
- [ ] **R-P2. Loaded levels run generation's side effects.** `generate_level` draws fixture ids
  from `Objects.next_id()` without a reset, so ids climb with every F6. It also places the world
  spawn from the re-hashed seed, not the saved one. **→ 004** (building from the save).
- [ ] **R-P3. No version check.** A save from a newer version loads; the migration function is
  a stub. E's items.
- [x] **R-P4. A failed load leaked nodes.** Every section is checked before any node is built,
  and `SaveGame.free_game_data()` frees what a refused load built. R-B7's inactive actors still
  leak.
- [x] **R-P5. Tests touched real saves.** `game.gd` has `saves_root`, set before `_ready`; scene
  tests use `user://test_saves/…` via `tests/save_dirs.gd`.
- [x] **R-P6. The slot regex wasn't anchored.** Now `^slot-\d{3}$`. **Still open:** the first slot
  is picked by `get_directories()` order, which nothing guarantees; sort the slots.
- [x] **R-P7. `Global.is_regex_match` printed on every call.** Gone; a bad pattern is a
  `push_error`.
- [ ] **R-P8. Layer names come from the `LAYER` enum.** `_serialize_tile_layers` turns each enum
  name into a property name (`level_tiles.get(_key)`). A `LAYER` entry with no property crashes
  the save on `null.compress`. Use the explicit `["ground", "top", "ore"]` list
  `_is_valid_level_entry` already has, in one shared place.
- [ ] **R-P9. No upper limit on a saved radius.** An edited save with a huge radius makes
  `array_size` and `decompress` try to allocate gigabytes. One line in `_is_valid_level_entry`.
- [ ] **R-P10. Save and load keys live in the per-actor `InputHandler`.** Two local actors would
  save twice, and the handler calls `game.save_game()` directly through an untyped `game: Node`,
  where the coding standards say signals over direct calls. Move the keys to `game.gd`, or emit
  `quick_save_requested` / `load_requested`.
- [x] **R-P11. Input handlers were found by name.** `game.gd` keeps `_input_handlers`.

**Suggestions**
- [ ] **R-S1. Do the load in phases:** validate, build levels from saved bounds, swap the world,
  build actors, re-point the view and renderers. **→ 004**; it is the shape D-118 gives a load.
- [ ] **R-S2. Missing tests.** Done: a String level key, a non-Dictionary level entry, actors on
  the loaded levels, an actor whose depth didn't load. Still to write: a non-Dictionary actor
  entry; a load where every level fails leaves the running world untouched (with R-B3); two
  actors round-tripping (D's test).
- [ ] **R-S3. `_get_levels_from_save_data`** only turns a Dictionary into an Array. It goes once
  `SaveGame` returns levels in depth order, or a world (004).
- [ ] **R-S4. Tidy-ups.** Pass `ALLOW_OBJECTS` to both `get_var` calls; "it's" → "its" in three
  comments in `save_game.gd`; several comments are over 70 characters; remove the `# Objects` /
  `# NPCs` placeholders or point them at checklist items.

**Found while fixing the review**
- [x] **R-F1. `test_save_game.gd` was silently skipped** (renamed `serialize`/`deserialize`, the
  old `save_game` signature). Rewritten for the current API; `test_save_game_load.gd` merged into
  it. Grep each run for `Ignoring` and `Parse Error` (trap 9).

## G. Done

- [ ] `scripts/test.ps1` passes, with no "Ignoring script" warnings.
- [ ] `python scripts/coverage.py` run; uncovered lines looked at. (002 closed at 98.9%.)
- [ ] By hand: outcomes 1–7 walked through in one sitting, launched outside the editor at least
  once (trap 2).
- [ ] Claude drafts `log/003-it-persists.md`; Derik corrects it.
- [ ] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Moved to slice 004 (D-118)

Taken out of C, D and E on 2026-10-30, because slice 004 changes what they're built on. Each is
listed in [NEXT.md](./NEXT.md)'s 004 entry.

- Continue builds the world from the save instead of generating and overlaying.
- A loaded `Level` is built from its **saved** bound (D-112). Until then, a level saved with
  another radius is skipped with a warning (review bug 4). A saved depth with no recipe row is
  still refused in C.
- `World.is_in_bounds` reads the level's own bound, not the recipe table (D-112).
- The next fixture id is saved and restored (trap 6), with its test: after a load, the next id is
  greater than every loaded fixture's. Safe to wait, because nothing places a fixture at runtime
  until slice 006.
- The actor id counter's home, and saving and restoring it (D-114).
- Both id counters in the save header (D-116).

### Not in this slice, worth knowing

- **`test_game.gd` is slow** (each test loads `game.tscn` and builds all eight levels). Save
  tests that need the whole game add to it; sharing one game in `before_all` for read-only tests
  is the carried-forward fix.
- **Generation on first descent** (world-runtime §8) isn't how the code works: all eight levels
  are built at launch. A save of a world where some levels don't exist yet is a missing key, and
  the load needs that case when generation changes.
- **Nothing prunes old saves.** Moved-aside and broken saves pile up in the slot folder.
