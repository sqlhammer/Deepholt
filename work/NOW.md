# Slice 004 — A world you can hold

> Press F6 and the whole mountain is swapped for the saved one in a single move. A damaged save
> leaves the running world exactly as it was, and ids carry on from where the world left them.

*Proposed by Claude, 2026-11-01, from [NEXT.md](./NEXT.md)'s sketch. Derik accepts, edits or
replaces it.*

## Mode

**Agent**, for the whole slice (Derik, 2026-11-01). Its forks are walked through with Derik one
at a time before any building starts.

## Where we are

Slice 003 is done ([log](./log/003-it-persists.md)). A world survives a relaunch: tiles,
fixtures, actors, the header and the playtime clocks. A broken save is kept and the backup loads,
and with both refused the game won't start. `--new-game` moves the old world aside.

**The one assumption this slice removes:** that the tree holds exactly one world. The 003 review
traced every load bug to it, and its fix is already decided
([D-118](../docs/design-decisions.md#d-118--the-world-is-a-node-that-owns-its-levels-and-id-counters-handed-by-reference)):
the world becomes a node that owns its levels and its id counters, handed to whatever needs it
by reference, never looked up.

**What a world is made of, today:**
- **Levels** sit under `game.gd`'s `$Levels`, in the `levels` group. Anything that wants one
  calls `World.get_level_by_depth`, which searches that group. Seven files in `src/` do so,
  plus `game.gd`.
- **The `World` autoload** holds the world seed, the recipe table, the actor id allocator, the
  tile gatekeeper's signals (`dig_requested`, `tile_dug`, `dig_refused`) and `is_in_bounds`,
  which reads the recipe's bound, not the level's.
- **The `Objects` autoload** is the fixture gatekeeper and holds the fixture id counter.
- **A load** (`game.gd.load_game`) frees the running levels, actors and input handlers, attaches
  the loaded ones, and re-points the view and renderers by hand. 003 made it refuse a file
  before freeing anything, so a damaged save already leaves the world alone. The swap itself is
  still free-then-attach, in several steps.

**What 003 already did toward this slice:** a level the save holds whole is built from the save,
not generated (R-P2). After a load, the fixture counter moves past every loaded id. A file with
any level that won't load is refused (R-B3). The load key no longer frees its own handler
(R-B8), and the save and load keys are signals on the handler (R-P10).

## What should be true when you stop

By hand, unless marked:

1. Dig on two levels, F5, dig more, F6: the screen, F3 and every level show the saved world, and
   nothing of the replaced one.
2. F6 on a truncated save: nothing changes. Not the screen, not F3, not the ids.
3. F3 shows the running world, and its next fixture id and next actor id. Loading twice in a row
   shows the same numbers both times. They don't restart, and they don't climb.
4. The ramp between the Surface and −1, and the hole on −1 with its ladder on −2, still work
   both ways; digs stay on their own level.
5. *Automated:* two worlds in one process, at the same depths, each with an actor. A dig, a depth
   change and a fixture placed in one leave the other untouched.
6. *Automated:* generating a second world doesn't change the first world's counters.
7. *Automated:* freeing a world leaves no orphan nodes. No code in `src/` searches the tree for
   levels.

This slice is mostly a change of shape, so most of what can be checked by hand is how a load
behaves. That is its playable edge, stated plainly rather than padded out.

## What you're deciding

Every fork below was settled on 2026-11-01, before building, as
[D-124](../docs/design-decisions.md#d-124--the-world-and-objects-autoloads-are-deleted-world-is-the-world-nodes-class)
to [D-130](../docs/design-decisions.md#d-130--a-save-takes-the-world-and-a-typed-session-the-worlds-counters-go-in-the-header).
The list stays as the record of what was weighed:
- the autoloads are deleted, and `World` is the node's class (D-124);
- the gatekeepers are the same signals, on the world (D-125);
- a level knows its world, and everything else reaches it through a level (D-126);
- the generator and the save each build a whole `World`, outside the tree (D-127);
- the world sits at the origin inside the game viewport, and owns its actors (D-128);
- the swap happens at the end of the frame, and the view re-points everything that draws
  (D-129);
- a save takes the world and a typed `SaveSession`, and the counters go in the header (D-130).

The forks as they were put:

- **How each consumer gets the world.** A field set on the actor at setup, a reference on each
  level (`level.world`), through the view for the renderers, or a mix. Whatever is chosen
  replaces `World.get_level_by_depth` in the actor's depth changes
  ([D-117](../docs/design-decisions.md#d-117--an-actor-is-handed-the-level-it-starts-on-depth-changes-still-look-theirs-up)),
  the ladder rule, both renderers, `Objects` and F3.
- **What a gatekeeper is now.** Methods on the world node, signals on it, or child nodes under it
  (a tile gate and a fixture gate). And how a capability that emits today (`dig_requested`)
  reaches it.
- **What's left of the `World` and `Objects` autoloads.** Deleted, or reduced to the recipes and
  the static helpers, and under what names.
- **Who builds a world.** `LevelGenerator` returning a world, `SaveGame` returning a world, and
  who swaps it in and re-points the view, renderers, input and F3.
- **Where the world node sits in the scene,** and what that does to coordinates (trap 5).
- **What `SaveGame.save_game` takes.** Today it's nine positional parameters, and every new
  header field broke every caller in 003. A world, plus the few things that aren't the world's
  (the slot, the local actor, the playtime), would end that.

## Already settled

- **The world's shape:** a node that owns its levels and both id counters, gatekeepers on the
  instance, stateless helpers made static, recipes kept global, two worlds possible
  ([D-118](../docs/design-decisions.md#d-118--the-world-is-a-node-that-owns-its-levels-and-id-counters-handed-by-reference)).
- **One front door per kind of change:** tiles change only through the tile gatekeeper
  ([D-078](../docs/design-decisions.md#d-078--world-is-the-only-thing-that-changes-tiles-at-runtime)),
  fixtures only through their own
  ([D-090](../docs/design-decisions.md#d-090--objects-get-their-own-gatekeeper-separate-from-world)).
- **Simulation takes what it acts on as a parameter,** and nothing resolves to *the* player
  ([D-045](../docs/design-decisions.md#d-045--no-player-singleton-carves-out-the-presentation-layer)).
- **An actor is handed its starting level**
  ([D-117](../docs/design-decisions.md#d-117--an-actor-is-handed-the-level-it-starts-on-depth-changes-still-look-theirs-up)).
  This slice replaces its remaining lookup, on a depth change.
- **`move_to` is the one way an actor is put somewhere else**
  ([D-119](../docs/design-decisions.md#d-119--move_to-is-the-one-way-an-actor-is-put-somewhere-else)).
- **Every level stays resident**
  ([D-035](../docs/design-decisions.md#d-035--no-tile-streaming-system-the-whole-world-stays-resident)).
- **A saved bound wins over the recipe**
  ([D-112](../docs/design-decisions.md#d-112--tile-layers-are-saved-by-name-a-byte-layer-per-fact-a-saved-bound-wins)).
  Building from the save makes it real (review bug R-B4).
- **What a refused save does:** kept, the backup tried, loud; both refused and the game won't
  start
  ([D-111](../docs/design-decisions.md#d-111--continue-by-default-a-flag-for-a-new-game-backups-and-broken-saves)).
  A refused F6 mid-session leaves the running world and saving alone.
- **The header's required keys**
  ([D-121](../docs/design-decisions.md#d-121--three-header-keys-are-required-the-rest-load-as-their-defaults),
  [D-122](../docs/design-decisions.md#d-122--the-save-time-is-a-utc-unix-int-and-the-writers-offset-both-required)).
  Format version 1 isn't settled, so the two id counters join the header with no version bump.

## Traps

### 1. The name `World` is taken

An autoload's name shadows a `class_name` of the same name, so a world node class called `World`
can't coexist with the autoload. Rename one first, on purpose, and in its own commit, so the
rename and the change of shape aren't tangled in one diff.

### 2. Lookups creep back in

`get_parent()`, `owner`, `get_first_node_in_group`, `get_tree().get_nodes_in_group`: each is a
tree search in disguise, and each works fine until there are two worlds. Outcome 7's "no code in
`src/` searches the tree for levels" is a grep; run it at the end of every section, not once.

### 3. Signals on a replaced world

Godot drops a node's connections when it's freed, so anything connected to the old world's
gatekeepers goes silent after a swap, with no error. A swap has to re-point every listener, and
a test has to prove each one hears the new world. 003 found one already: the fixture renderer
kept the old level's fixtures when the depth didn't change (R-B9).

### 4. Freeing during a callback

F6 starts the load from inside an input handler's `_input`. 003 made the handlers go at the end
of the frame instead of at once (R-B8). A whole-world swap started from input should be deferred
the same way: build the new world now, swap it in at the end of the frame.

### 5. Coordinates only line up by accident

`$Levels` sits under the game root, and actors sit inside `GameViewport`. `actor.position` is
passed as a global position into `level.to_local`, which is only correct because every transform
between them is the identity. Moving the levels under a world node keeps that true only if the
world node is at the origin too.

### 6. The actor id counter isn't moved on load

Found at the end of 003: `IdAllocator.claim` exists and nothing calls it. After a fresh launch's
load, a player created next can take an id a loaded actor already has. 003 fixed the fixture
counter by moving it past the highest loaded id; the actor counter has no fix yet. Saving both
counters in the header, and restoring them last, after anything that could reset them, ends it
for both (save-files §7).

### 7. Test churn

Most tests put levels in the tree and rely on the lookup. Expect a large, mechanical change.
Grep each run for `Ignoring` and `Parse Error`: GUT skips a file that fails to parse, and the
suite still passes. Run each test file on its own once if a leak warning appears; 003's came
from one test.

### 8. From the 002 and 003 logs

- **Measure the parts before naming the cause.** Both slices blamed a slow path on the wrong
  thing until it was broken down. A load takes about 100 ms now; F3 shows "Last save" and
  "Last load".
- **Script edits from files, not heredocs,** and match whitespace-tolerantly.
- **Run the game by hand per section,** not only at the end.

## Carried into this slice

From the 003 checklist ("Moved to slice 004" and the review, in git history at `466f939`),
still to do, each now an item in [CHECKLIST.md](./CHECKLIST.md):
- A loaded level is built from its **saved** bound, so a level whose radius was tuned isn't lost
  (R-B4).
- `World.is_in_bounds` reads the level's own bound, not the recipe table (D-112).
- Both id counters saved, restored last and in the header; the fixture counter's stopgap
  (`Objects.reserve_ids_through`) goes.
- The actor id counter gets its real home (D-114, trap 6).
- The load in phases: validate, build the world to one side, swap it in, re-point everything
  (R-S1).
- `_get_levels_from_save_data` goes once `SaveGame` returns a world (R-S3).
