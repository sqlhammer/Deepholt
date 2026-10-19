# Slice 003 checklist

Working list for [NOW.md](./NOW.md). Ordered so something is on screen early, not by code
dependency: one level's tiles survive a relaunch before fixtures, actors or versioning exist, so *how a save is shaped and when it happens* is settled and
visible before *everything that goes in it*. **Decide** items are forks to talk through before
building past them; each outcome becomes a `D-nnn`. **Decide, by looking** items need the
running game. Numbers in brackets are the brief's by-hand outcomes.

Slice 002's checklist is in git history (last at `f0681b2`).

---

## A. The shape of a save

*Mode: ask before starting.*

- [ ] **Decide:** what owns saving and loading. An autoload beside `World` and `Objects`, or a
  node in the game scene. Either way it is simulation, so it takes levels and actors as
  parameters and saves **N** actors, never *the* player (rule
  [D-045](../docs/design-decisions.md); the save row of world-runtime §6's table).
- [ ] **Decide:** the file's encoding. Options: `FileAccess.store_var` of plain dictionaries and
  `PackedByteArray`s; a hand-written byte layout; JSON with the tile arrays base64'd; a Godot
  `Resource` (`.tres`/`.res`). Trap 3 in the brief.
- [ ] **Decide:** one file for the world, or a header plus a file per level. One is atomic and
  simple; per level writes less on a save once levels get big. About 3 MB uncompressed for the
  whole mountain either way ([world-runtime §1](../docs/tech/world-runtime-and-persistence.md)).
- [ ] **Decide:** compression. `PackedByteArray.compress` per array, or
  `FileAccess.open_compressed` for the whole file. Mostly-solid rock compresses very well.
- [ ] **Decide:** where it lives (`user://saves/…`), and whether there are slots. One slot is
  enough for this slice; the path is the part worth deciding.
- [ ] **Decide:** when a save happens: on quit, on a key, on a timer, on level change, or some
  mix. Name what a quit is (window close, `Esc`, the editor's stop button).
- [ ] **Decide:** when a load happens, with no menu. Options: always continue if a save exists;
  a command-line flag or a key for a new game; a minimal title screen. Feeds outcome 5.
- [ ] **Decide:** what a new game does to an existing save: overwrite at the first save, move it
  aside, or refuse until it's deleted.

Traps 2, 3 and 4 in the brief apply here: the editor's stop button isn't a quit, a
`Resource` save can run code, and a save written in place can be half a save.

## B. One level's tiles, round trip

*Mode: ask before starting.*

The first thing on screen: a dug tile survives a relaunch.

- [ ] **Decide:** how tile arrays are saved. The code has three byte layers (ground, top, ore);
  world-runtime §3 describes a different layout (`terrain_id` u16, `flags` u16, `region_id`,
  `ore_id`). Save layers by name, so the dark's `remembered` bit (tunnel memory,
  [D-033](../docs/design-decisions.md)) can arrive as a new layer rather than a migration; or
  save the three arrays positionally. Whichever, note which document is now out of date.
- [ ] `LevelTiles` gets a bulk load path that neither trips the warning setters nor emits a
  `tile_changed` per tile (trap 5).
- [ ] Each level's `LevelBound` is saved with its tiles, so loading never needs a recipe
  ([D-085](../docs/design-decisions.md)).
- [ ] **Decide:** what happens when a saved level's radius doesn't match the recipe's. It will,
  the first time a radius is tuned. The save is the truth (save the result, not the recipe), so
  probably the saved bound wins; say what `World.is_in_bounds`, which reads the recipe table,
  does then.
- [ ] The renderer builds from the loaded tiles, with no replay of digs (a built renderer learns
  from the truth, [D-065](../docs/design-decisions.md)). Check the load lands before
  `View` first shows a level, or that the view is re-pointed after it.
- [ ] Test: save a level, load it into a fresh `LevelTiles`, and every layer is byte-identical.
- [ ] Test: a load emits no per-tile `tile_changed`.
- [ ] By hand: dig on the Surface, quit, relaunch, still dug. [1]

## C. Every level, fixtures and ids

*Mode: ask before starting.*

- [ ] All eight levels are saved, including the untouched solid ones below −2. (Save the result:
  a save that skips them depends on the generator staying the same.)
- [ ] Each level's fixtures are saved as kind, tile and id; kind ids are numbers, and are forever
  (trap 8 of slice 002, [D-104](../docs/design-decisions.md)).
- [ ] `Objects`' id counter is saved, and restored **after** anything that calls
  `Objects.reset_ids()` (trap 6).
- [ ] **Decide:** whether loaded fixtures go through the `Objects` gatekeeper's placement rules,
  or straight into `LevelFixtures`. Re-checking catches a corrupt save; skipping it means a rule
  tightened later can't refuse an old world's ladder.
- [ ] **Decide:** whether `ramp_problems` and `ladder_problems` run on a loaded world as they do
  on a generated one.
- [ ] `LevelFixtures.add` refuses the same fixture twice (carried from 002). A load that runs
  twice, or a fixture that's also stamped by generation, would otherwise double up silently.
- [ ] The world spawn is a fixture, so it comes back like any other
  ([D-091](../docs/design-decisions.md)).
- [ ] Test: after a load, the next id is greater than every loaded fixture's id.
- [ ] Test: a world with digs on three depths round-trips, each depth only its own.
- [ ] By hand: dig on the Surface, −1 and −2, quit, relaunch, check each. [2]
- [ ] By hand: the ramp, the hole and the ladder still work, both ways. [3]

## D. Actors

*Mode: ask before starting.*

- [ ] **Decide:** whether actors get a stable `actor_id` in this slice. world-runtime §6 wants one
  ("built structures record `builder_id`"); nothing has one yet. A save of N actors with no ids
  works until something refers to an actor.
- [ ] **Decide:** what an actor's saved state is. Candidates: name, depth, position (pixels or
  tile), facing, equipped tool. Not capabilities, which the game grants; not a dig in progress
  (it resets on any interruption, [D-072](../docs/design-decisions.md)).
- [ ] **Decide:** which loaded actor the local player takes control of. The save holds actors;
  attaching input, the view and the camera to one of them is presentation's job
  (the carve-out in world-runtime §6). With one actor it's obvious, which is trap 1: write it so a
  second saved actor doesn't change the answer by accident.
- [ ] Where actors are is saved; the spawn is used only for new players and deaths
  ([D-091](../docs/design-decisions.md)). A loaded actor is not sent to the world spawn.
- [ ] **Decide:** what a loaded actor standing somewhere no longer passable does. Today nothing
  could change it between save and load, but a tile kind's passability can change in a later
  build.
- [ ] Test: two actors on different depths round-trip, each to its own depth and `(x, y)`.
- [ ] By hand: quit on −2 facing west; relaunch there, facing west. [4]

## E. Versions, seeds and the header

*Mode: ask before starting.*

- [ ] `format_version` is an integer from the first save, with a migration function per step
  ([world-runtime §7](../docs/tech/world-runtime-and-persistence.md)). Write a no-op migration
  now (M0 acceptance, §10), so the path exists before it's needed.
- [ ] Seeds are saved as numbers, and load reads them back without re-hashing (trap 7).
- [ ] **Decide:** `tuning_profile_id`. One swappable resource for every tuning number, named in
  each save so playtest feedback is traceable ([D-037](../docs/design-decisions.md)). It isn't
  built. Build a minimal one now, write a placeholder id, or leave the field out until it
  exists.
- [ ] **Decide:** which header fields exist yet. §7 lists `game_time` and `playtime`; there's no
  game clock. Leave them out, or save what there is.
- [ ] Derived data isn't saved, and is rebuilt on load: today that's the renderers' textures and
  the view; later support, light and chambers
  ([world-runtime §3](../docs/tech/world-runtime-and-persistence.md)).
- [ ] A save from a newer version than the game is refused, loudly, and not overwritten. [6]
- [ ] A truncated or unreadable save is refused, loudly, and not overwritten. [6]
- [ ] Test: each refusal, without a running scene.
- [ ] `F3` shows loaded or new, and the format version. [7]

## F. New game and continue

*Mode: ask before starting.*

- [ ] Whatever A decided for new game versus continue, wired up.
- [ ] By hand: new game with a save present behaves as decided, never half of each. [5]
- [ ] **Decide, by looking:** is the save or the load felt (a hitch on quit, or on launch)?
  Measure both at the full eight levels first.

## G. Done

- [ ] `scripts/test.ps1` passes, with no "Ignoring script" warnings.
- [ ] `python scripts/coverage.py` run; uncovered lines looked at. (002 closed at 98.9%.)
- [ ] By hand: outcomes 1–7 walked through in one sitting, launched outside the editor at least
  once (trap 2).
- [ ] Claude drafts `log/003-it-persists.md`; Derik corrects it.
- [ ] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Not in this slice, worth knowing

- **`test_game.gd` is slow** (each test loads `game.tscn` and builds all eight levels). Save
  tests that need the whole game add to it; sharing one game in `before_all` for read-only tests
  is the carried-forward fix.
- **Generation on first descent** (world-runtime §8) isn't how the code works: all eight levels
  are built at launch. It doesn't block saves, but a save format that assumes every level exists
  will need a "not yet generated" case when that changes.
