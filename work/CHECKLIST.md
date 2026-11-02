# Slice 004 checklist

Working list for [NOW.md](./NOW.md). **Agent mode for the whole slice** (Derik, 2026-11-01):
Claude builds, Derik verifies by hand. Every fork the brief raised was settled upfront on
2026-11-01 as
[D-124](../docs/design-decisions.md#d-124--the-world-and-objects-autoloads-are-deleted-world-is-the-world-nodes-class)
to [D-130](../docs/design-decisions.md#d-130--a-save-takes-the-world-and-a-typed-session-the-worlds-counters-go-in-the-header);
items below carry them out, and each names the decision. Numbers in brackets are the brief's
outcomes.

Ordered so the game runs at the end of every section: the world node first, then its counters,
then saving and loading a world, then the swap. The game is launched by hand at the end of each
section, not only at the end of the slice (002's log).

Slice 003's checklist is in git history (last at `466f939`).

---

## A. Decided upfront

*No mode: settled in conversation, 2026-11-01.*

- [x] The `World` and `Objects` autoloads are deleted; `class_name World` is the world node; the
  recipes and stateless helpers move onto static classes (D-124).
- [x] The gatekeepers are the same request and outcome signals, on the world instance, with
  distinct names for the two refusal enums (D-125).
- [x] `World` sets `level.world` when it takes a level in; everything else reaches the world
  through a level (D-126).
- [x] `LevelGenerator` and `SaveGame` each return a whole `World`, built outside the tree (D-127).
- [x] The world sits at the origin inside `GameViewport` and owns `Levels` and `Actors` (D-128).
- [x] A swap happens at the end of the frame; the view announces a new world and the
  renderers and F3 re-point on it (D-129).
- [x] `save_game(slot, world, session, saves_root)`, with a typed `SaveSession`; both id
  counters in the header, restored last, then moved past every loaded id (D-130).

## B. The world node, generated

The game runs on one `World` node, built by the generator, with no autoload holding world state
and nothing searching the tree for levels or actors.

- [x] Rename first, in its own commit: the `World` autoload goes, its recipes become a static
  class's preloaded constant, and its stateless helpers (depth display names, position to tile)
  become static functions. Nothing else changes in that commit (trap 1, D-124).
- [x] `class_name World`, a `Node2D` with `Levels` and `Actors` (`Players`, `NPCs`) children,
  holding its seed and its levels by depth. `add_level` sets `level.world`; `level_at(depth)`
  replaces `get_level_by_depth` (D-124, D-126, D-128).
- [x] `LevelGenerator` returns a `World` for a seed, outside the tree (D-127).
- [x] `game.gd` puts the generated world at the origin inside `GameViewport`, replacing
  `$Levels` and `GameViewport/Actors`. Actors are added to the world's `Actors` (D-128, trap 5).
- [x] The tile gatekeeper's signals and handling move onto `World` (D-125). The dig capability
  emits on `actor.current_level.world` and listens there (D-126).
- [x] The fixture gatekeeper's signals and handling move onto `World`, and the `Objects`
  autoload goes. The placement rules become static functions (D-125). *The fixture
  counter had to move with it, so both counters became `IdAllocator`s on the world here
  (most of C's first item).*
- [x] The two refusal enums get distinct names (D-125).
- [x] The actor's depth change, `move_to` and the Ladder rule ask `current_level.world` for the
  level at a depth ([D-117](../docs/design-decisions.md), D-126).
- [x] The renderers and F3 get levels from the followed actor's world, through the view
  (D-126, D-129). *Done with `shown_world_changed` itself (E's second item), since the
  renderers need a world as soon as the lookup goes.*
- [x] `is_in_bounds` reads the level's own bound, not the recipe table
  ([D-112](../docs/design-decisions.md)).
- [x] No `get_nodes_in_group`, `get_first_node_in_group`, `get_parent()` or `owner` lookup of
  levels or actors left in `src/` or `scenes/` (trap 2). Grep it at the end of the section.
- [x] Tests follow the new shape. Grep the run for `Ignoring` and `Parse Error` (trap 7).
- [ ] By hand: dig on two levels, the ramp and the ladder both ways, F3 reads. [4]

## C. The world's id counters

- [x] The next fixture id and the next actor id live on the world (D-118). `Objects`' counter
  and `World.id_allocator` are gone; the generator and actor creation draw from the world they
  build into.
- [x] A new world starts its own counters; generating a second world leaves the first world's
  untouched. [6]
- [x] F3 shows the running world's next fixture id and next actor id. [3]
- [x] Test: a second generated world doesn't change the first's counters. [6]

## D. Saving and loading a `World`

- [ ] `SaveSession`, a typed class with the local actor's id, the tuning profile id and the two
  playtime clocks; `save_game(slot, world, session, saves_root)` (D-130).
- [ ] Both counters written to the header from the world, with no format version bump (D-130,
  [D-116](../docs/design-decisions.md)).
- [ ] `SaveGame`'s load returns a `World` in the slot result, outside the tree, with its
  levels, seed and actors (D-127). A refused load frees that one world and nothing else.
- [ ] A loaded level is built from its **saved** bound, so a level whose radius was tuned isn't
  lost ([D-112](../docs/design-decisions.md); 003's review, R-B4).
- [ ] The counters are restored last, then moved past every id the load brought back; a save
  with no counters gets them from the ids alone. `Objects.reserve_ids_through` goes, and the
  actor counter is moved too (D-130, trap 6).
- [ ] `_get_levels_from_save_data` goes (003's review, R-S3).
- [ ] Test: after a load, the next fixture id and the next actor id are each past every loaded
  one; a player created after a fresh launch's load gets a new id (trap 6).
- [ ] Test: a level saved with another radius loads with that radius.
- [ ] Test: a refused load leaves no orphan nodes. [7]
- [ ] By hand: dig, quit, relaunch: the world comes back, and F3's next ids carry on. [3]

## E. The swap

- [ ] `game.gd` swaps a built world in at the end of the frame: the old world freed, the new one
  added, control given to its local player (D-129, trap 4). Launch, `--new-game` and F6 all go
  through it.
- [ ] `view.follow` announces `shown_world_changed` (world and depth) when the followed actor's
  world isn't the one shown, even at the same depth (D-129).
- [ ] The level renderer, the fixture renderer and F3 re-point on `shown_world_changed`, and stop
  listening to the old world (trap 3).
- [ ] The load runs in phases: validate, build the world to one side, swap it in, re-point
  (003's review, R-S1).
- [ ] Test: after a swap, each renderer and F3 hears a change made in the new world, and nothing
  made in the old one (trap 3).
- [ ] Test: F6 on a truncated save leaves the screen, F3 and the ids as they were. [2]
- [ ] By hand: dig on two levels, F5, dig more, F6: every level shows the saved world. [1]
- [ ] By hand: F6 on a truncated save changes nothing. [2]
- [ ] By hand: F6 twice in a row: F3's next ids are the same both times. [3]

## F. Two worlds

- [ ] Test: two worlds in one process, at the same depths, each with an actor. A dig, a depth
  change and a fixture placed in one leave the other untouched. [5]
- [ ] Test: freeing a world leaves no orphan nodes. [7]
- [ ] Test (or a grep in a test): no code in `src/` searches the tree for levels. [7]

## G. Done

- [ ] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
- [ ] `python scripts/coverage.py` run; uncovered lines looked at. (003 closed at 95.1%.)
- [ ] By hand: outcomes 1–4 walked through in one sitting, launched outside the editor at least
  once.
- [ ] Claude writes `log/004-a-world-you-can-hold.md`.
- [ ] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Not in this slice, worth knowing

- **Generation on first descent** (world-runtime §8) isn't how the code works: all eight levels
  are built at launch. A save of a world where some levels don't exist yet is a missing key, and
  the load needs that case when generation changes.
- **Nothing prunes old saves.** Moved-aside and broken saves pile up in the slot folder.
- **003's small leftovers** are in [NEXT.md](./NEXT.md)'s "Deferred from 003": slot sorting,
  dead tool-loading code, comment tidy-ups, save-files.md, untested playtime clocks. Fold any
  into 004 only if the code they touch is being rewritten anyway.
