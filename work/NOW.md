# Slice 003 — It persists

> Save a dug world, quit, relaunch, and your corridor is still there, on every level, with the
> ladder and the spawn where they were, and you're standing where you stopped.

## Mode

Asked before each checklist section starts, and recorded there. Not carried over from
slice 002.

## Where we are

Slice 002 is done ([log](./log/002-go-down.md)). Three hand-made levels, joined by a ramp and a
ladder; every level keeps its own digs for as long as the game runs, and a relaunch puts all of
it back to hand-made. That last part was outcome 8 of slice 002, and this slice reverses it.

**What a world is made of, today:**
- **Tiles.** Each `Level` has a `LevelTiles`: three `PackedByteArray`s (ground, top, ore), each
  the square around the level's radius, plus the `LevelBound` it was sized from. All eight levels
  are built at launch by `LevelGenerator` from `level_recipes.tres`, and stay resident.
- **Fixtures.** Each `Level` has a `LevelFixtures` of `Fixture`s (kind, tile, id). Ladders and
  the world spawn are the only kinds. Ids come from `Objects._next_fixture_id`, which the
  generator resets to the first id before it builds anything.
- **Seeds.** `World.world_seed` is `hash("Default Seed")`; each `Level.level_seed` is `hash()` of
  a string built from it and the depth. Nothing draws randomness except the world spawn's
  placement.
- **Actors.** One player, created by `game.gd` at the world spawn. Its state is a pixel
  position, a depth, a facing, a name and an equipped tool. It has no id.
- **Nothing else.** No game clock, no `TuningProfile`, no menu, no file I/O anywhere in `src/`.

**What reads it:** `LevelRenderer` and `FixtureRenderer` build from the shown level's data
whenever the view moves, and `F3` reads the actor. None of them keep history, so none of them
need to be told what happened before a load.

**Trimmed 2026-10-30.** The save/load review showed every load bug coming from one assumption:
that the tree holds exactly one world. Fixing it became slice 004
([D-118](../docs/design-decisions.md#d-118--the-world-is-a-node-that-owns-its-levels-and-id-counters-handed-by-reference)).
The parts of this slice that 004 reshapes (building the world from the save, saved bounds, the
id counters' restore) moved there; the [checklist](./CHECKLIST.md#moved-to-slice-004-d-118) lists
them. The outcomes below still hold, on B's staging: launch generates, then the save replaces
what was generated.

## What should be true when you stop

By hand, in a running game:

1. Dig on the Surface, quit, relaunch: the tile is still dug.
2. Dig on the Surface, −1 and −2, quit, relaunch: each level has its own digs, and only its own.
3. The ramp, the hole and the ladder are where they were, and still work, both ways.
4. Quit standing on −2, facing west: relaunch on −2, on the same tile in `F3`, facing west.
   Not at the world spawn. (Actors save their tile, not their pixel:
   [D-114](../docs/design-decisions.md#d-114--actors-get-int-ids-from-a-world-counter-what-an-actor-saves).)
5. Start a new game (`--new-game`) while a save exists: a fresh, hand-made world, and the old
   save moved aside beside it, intact. Never half of each
   ([D-111](../docs/design-decisions.md#d-111--continue-by-default-a-flag-for-a-new-game-backups-and-broken-saves)).
6. Break a save on purpose (truncate it, or bump its version past the game's): it's kept as a
   broken save, the backup loads instead, and the game says so loudly. Break the backup too, and
   the game refuses to start and says why. Never a crash, and never a silent new game over the
   top of it (D-111).
7. `F3` says whether this session was loaded, new or from the backup, and from which format
   version.

Outcomes 1–7 are walked through at least once with the game launched **outside the editor**
(trap 2).

Separately, automated, without a running scene where possible:
- a level's tiles round-trip byte-identical, every layer;
- a load emits no per-tile `tile_changed`;
- a world with digs on three depths round-trips, each depth only its own;
- *(moved to slice 004, D-118)* after a load, the next fixture id is greater than every loaded
  fixture's;
- two actors on different depths round-trip, each to its own depth and tile;
- a save from a newer format version, and a truncated save, are each refused, kept, and the
  backup loaded in their place.

## What you're deciding

Every fork below was settled on 2026-10-23, before building, as
[D-109](../docs/design-decisions.md#d-109--a-save-is-one-store_var-file-per-slot-owned-by-a-static-class)
to [D-116](../docs/design-decisions.md#d-116--the-save-header-and-a-placeholder-tuning-profile-id).
The list stays as the record of what was weighed. The one fork left is whether the timer's save
is felt mid-play, which needs the running game (checklist F).

- **What owns saving and loading.** An autoload beside `World` and `Objects`, or a node in the
  game scene. An autoload is reachable from anywhere, which is convenient and is also how
  things become globals; a node in the game scene has to be handed what it saves. Either way it
  is simulation: it takes levels and actors and saves all of them (trap 1).
- **The file's encoding.** Each option, and what it costs:
  - `FileAccess.store_var` of plain dictionaries and `PackedByteArray`s: least code, Godot's own
    binary format, safe with `allow_objects` off. Opaque to a text editor.
  - A hand-written byte layout: total control and the smallest file, and every field is
    yours to read and write in order, forever.
  - JSON with the arrays base64'd: readable header, diffable, slower and larger; numbers come
    back as floats, so every int has to be cast on the way in.
  - A Godot `Resource` (`.tres`/`.res`): the least code of all, and it can run code on load
    (trap 3).
- **One file or several.** One file for the world is atomic and simple. A header plus a file per
  level writes less per save once levels get big, and makes "not generated yet" a missing file
  rather than a flag. The whole mountain is about 3 MB uncompressed
  ([world-runtime §1](../docs/tech/world-runtime-and-persistence.md)).
- **Compression.** Per array (`PackedByteArray.compress`) or the whole file
  (`FileAccess.open_compressed`). Mostly-solid rock compresses to almost nothing either way;
  per array keeps the header readable without decompressing.
- **Where it lives, and slots.** `user://saves/…`. One slot is enough for this slice; the path
  and file name are what later slots inherit.
- **When a save happens.** On quit, on a key, on a timer, on a level change, or a mix. Quit-only
  loses everything on a crash; a timer or level change is where "autosave" lives later. Decide
  too what counts as a quit: closing the window, `Esc`, the editor's stop button (trap 2).
- **When a load happens, with no menu.** Always continue if a save exists, with a key or a
  command-line flag for a new game; or a minimal title screen. The first is quickest to test by
  hand; the second is the first piece of UI that isn't debug.
- **What a new game does to an existing save.** Overwrite it at the first save, move it aside,
  or refuse until it's deleted. Overwriting is the one that loses a playtest world by accident.
- **How tile arrays are laid out in the save.** Three arrays in a fixed order, or layers by
  name. By name lets the dark's `remembered` bit (tunnel memory, one persistent bit per tile,
  [D-033](../docs/design-decisions.md)) arrive in slice 004 as a new layer rather than a
  migration. Either way, the code's three byte layers aren't the layout world-runtime §3
  describes (`terrain_id` u16, `flags` u16, `region_id`, `ore_id`); say which one is now the
  plan.
- **What happens when a saved level's radius doesn't match its recipe.** It will, the first time
  a radius is tuned. The save is the truth (below), so the saved bound probably wins. Then
  `World.is_in_bounds`, which reads the recipe table, disagrees with the level's own
  `LevelTiles`, which reads its own bound.
- **Whether loaded fixtures go through `Objects`' placement rules.** Re-checking catches a
  corrupt save. Skipping it means a rule tightened in a later build can't refuse an old world's
  ladder. Likewise whether `ramp_problems` and `ladder_problems` run on a loaded world.
- **Whether actors get a stable `actor_id` now.** world-runtime §6 wants one (structures record
  `builder_id`); nothing has one. Saving N actors without ids works until something refers to an
  actor, and that something is the next slice that builds.
- **What an actor's saved state is.** Name, depth, position (pixels or tile), facing, equipped
  tool. Not capabilities, which `game.gd` grants; not a dig in progress, which resets on any
  interruption ([D-072](../docs/design-decisions.md)).
- **Which loaded actor the local player controls.** Attaching input, the view, the camera and
  `F3` is presentation's job. With one saved actor the answer is obvious, which is trap 1.
- **What a loaded actor standing somewhere impassable does.** Nothing between save and load can
  cause it today; a passability change in a later build can.
- **`tuning_profile_id`.** One swappable resource holding every tuning number, named in each
  save so playtest feedback stays traceable to the numbers it was played under
  ([D-037](../docs/design-decisions.md)). It isn't built. Build a minimal one now, write a
  placeholder id, or leave the field out until it exists (and pay a version bump then).
- **Which header fields exist yet.** world-runtime §7 lists `game_time` and `playtime`; there's
  no game clock. Leave them out, or save what there is.

## Already settled

- **Save the result, not the recipe.** Full tile arrays, compressed; never seed plus a replay of
  digs, because regeneration would have to stay bit-identical across every future change to a
  recipe or prefab ([world-runtime §7](../docs/tech/world-runtime-and-persistence.md)).
  **Binds** the encoding question: tiles are in the file. It also means all eight levels are
  saved, the untouched ones too.
- **A level's bounds are saved with it,** so loading never needs a recipe: a recipe contains its
  level's bounds, and bounds stay their own type for exactly this reason
  ([D-085](../docs/design-decisions.md)). **Binds** the radius-mismatch question toward the
  save.
- **Tile and fixture kind ids are forever.** A save stores numbers, not names; every existing id
  is pinned by a test ([D-104](../docs/design-decisions.md), slice 002's trap 8).
- **`format_version` is an integer with explicit migration functions,** and the first migration
  is written before it's needed (world-runtime §7; M0 acceptance, §10, asks for one no-op
  migration).
- **Derived data is never saved.** Support, light and chambers are recomputed on load
  ([world-runtime §3](../docs/tech/world-runtime-and-persistence.md)). Today the only derived
  things are the renderers' textures and the view, and they already rebuild from the truth
  ([D-065](../docs/design-decisions.md)).
- **Where actors are is saved; where they spawn is for new players and deaths**
  ([D-091](../docs/design-decisions.md)). **Binds** outcome 4: a loaded actor doesn't go to the
  world spawn.
- **No player singleton.** Simulation takes an actor, or a set of them, as a parameter;
  presentation may hold the locally controlled one ([D-045](../docs/design-decisions.md)).
  **Binds** what owns saving: it saves N actors, and it doesn't pick the local one.
- **No streaming.** Every level stays resident for the session
  ([D-035](../docs/design-decisions.md)). A load fills all eight before play starts.
- [Source layout, naming, tabs, signals over direct calls](../docs/coding-standards.md).

## Traps

### 1. Saving "the player"

**The trap.** The shortest save writes `game.gd`'s player: one position, one depth, one facing.
It works, because there's one actor. Then a second actor exists (a worker, a co-op partner, a
test actor) and the save silently drops it, or the load hands the local player's controls to
whichever actor was written first. The save row of world-runtime §6's table is **N** actors.

**What holds it.** Save every actor under `Actors`, and let presentation decide afterwards which
one input, the view and the camera follow. The automated check is two actors on different
depths coming back to their own places.

### 2. The editor's stop button isn't a quit

**The trap.** Stopping the game from the editor kills the process: no
`NOTIFICATION_WM_CLOSE_REQUEST`, no `_exit_tree`, no save. A save-on-quit that only runs on that
notification looks broken in every by-hand test run from the editor, and works fine for
players. Catching a real window close also needs `get_tree().set_auto_accept_quit(false)`, and
then quitting yourself after the save. Whatever "quit" ends up meaning, test it outside the
editor at least once.

### 3. A `Resource` save can run code

**The trap.** A `.tres` or `.res` can carry an embedded script, and `ResourceLoader.load` runs
it. Harmless for files the game wrote itself, but a save is the one file players pass around,
and this is the kind of choice made for convenience now and expensive to unpick once saves
exist. `store_var`/`get_var` with `allow_objects` left off can't do it, nor can JSON or a
hand-written layout.

### 4. A save written in place can be half a save

**The trap.** A crash or kill partway through writing leaves a truncated file where the good one
was, and the next launch either fails or starts a new game over it. Write to a temporary file
and rename it over the old one; `DirAccess.rename` replaces within the same directory.

### 5. Loading tiles through the tile setters

**The trap.** `LevelTiles`' public `ground`, `top` and `ore` setters `push_warning`, on purpose,
so assigning a loaded array trips them. The per-tile `set_*` functions emit `tile_changed` once
per tile: about 25,000 signals at the Surface and 135,000 at the Crush, each one reaching the
renderer if it's listening. Load needs its own bulk path that replaces the arrays without either.
Check the array size against the saved bound before taking it.

### 6. The id counter reset

**The trap.** `LevelGenerator.generate_levels` calls `Objects.reset_ids()` first. If a load
restores the counter and then anything generates (a level, a test fixture), ids restart from the
first one and collide with saved fixtures. `LevelFixtures.add` also accepts the same fixture
twice (carried from slice 002), so a load that runs twice doubles every ladder without a word.
Restore the counter last, and add the guard.

### 7. Seeds hashed from strings

**The trap.** `World.set_world_seed` and `Level._set_level_seed` both call `hash()` on a string.
Godot doesn't promise `hash()` gives the same answer across versions. Nothing uses the level
seed for randomness yet, so it's invisible, which is the reason to fix it now: save the numbers,
and on load read them back rather than re-hashing anything.

### 8. JSON numbers are floats

**The trap.** Only if the encoding is JSON. `JSON.parse_string` returns every number as a
`float`. A tile kind, a fixture id or a depth assigned from it into a typed `int` variable is
converted, but one passed through an untyped `Variant` and compared with `==` or used as a
dictionary key is not the same value. Cast every number on the way in, in one place.

### 9. From the 001 and 002 logs

GUT silently skips a test file that fails to parse; treat an "Ignoring script" warning as a
failure. Measure after changing anything on the tile read path, since the 002 hitch numbers are
the baseline (Surface ≈ 90 ms, −1 ≈ 47 ms, −2 ≈ 76 ms, the Crush ≈ 490 ms). Run the game by hand
per section, not per slice.
