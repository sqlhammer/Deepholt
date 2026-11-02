# 004 — A world you can hold

*Written by Claude, 2026-11-02.*

> Press F6 and the whole mountain is swapped for the saved one in a single move. A damaged save
> leaves the running world exactly as it was, and ids carry on from where the world left them.

**Result:** built in Agent mode in one session, in eight commits on `main`, at least one per
checklist section. The suite passes: 698 tests, no skipped files, no leak warning, and no orphan
reports (16 before the slice). Coverage is 95.7% (1805 of 1886 probed lines; 003 closed at
95.1%). **The by-hand outcomes, 1–4, haven't been walked yet.** Derik does that, so this log was
written before anyone ran the game by hand. The game was only run through the test suite's
scene tests. Claude never launched it, because a launch reads and writes the real save slot.

---

## What got decided

Seven decisions, D-124 to D-130, all settled on 2026-11-01 before any building. None were added
during the build:

- **Both autoloads are deleted, and `World` is the world node's class** (D-124). The recipes moved
  to `LevelRecipes.TABLE`. The stateless helpers moved to `DepthName.of` / `DepthName.to_depth`
  and `TileSpace.world_pos_at`.
- **The gatekeepers are the same signals as before, now on the world instance** (D-125). The two
  refusal enums are now `World.DIG_REFUSAL` and `World.FIXTURE_REFUSAL`. The placement rules
  are static functions on `FixturePlacement`.
- **A level knows its world** (D-126). `World.add_level` sets `level.world`, and everything else
  reaches the world through a level.
- **The generator and the save each build a whole `World`, outside the tree** (D-127).
- **The world sits at the origin inside `GameViewport`, and owns its actors** (D-128).
- **A swap happens at the end of the frame, and the view re-points everything that draws**
  (D-129).
- **`save_game(slot, world, session, saves_root)`, with both counters in the header** (D-130).

**Choices made while building, not recorded as decisions.** Derik may want to look at these:

- **Each counter is an `IdAllocator`** (`world.fixture_ids`, `world.actor_ids`). The existing
  class got `peek` and `restore`, and no new counter type was written.
- **Only F6 defers its swap.** `load_game(defer_swap)` builds the world at once in either case.
  F6 then calls `_swap_in_loaded_world` deferred, as D-129 says. A direct call (launch, and the
  tests) swaps immediately, since nothing is running inside a callback there. Launch and
  `--new-game` go through the same `_swap_world`.
- **The load result stays a dictionary.** `"levels"` and `"actors"` became one `"world"`, and
  `SlotLoad.world` reads it. A typed load result would have changed every load test a second
  time, so it was left.
- **Old input handlers stay in the tree until they're freed.** Each one is cut off from its actor
  and from input first. This is what ended the orphan reports.
- **A refused F6 mid-session now says the running world is unchanged.** The old message said
  "the game hasn't started", which is only true at launch.

---

## What surprised

**Two latent bugs surfaced only once the load built to a saved bound.**
`LevelGenerator.generate_level` ignored the recipe it was handed and took its bound from the
global table. Nothing noticed, because every recipe ever passed in had been the global table's
own row. A test for a partly saved level with a tuned radius failed on it. Separately, a save
that holds a level only in part makes the load generate that level, and the generated fixtures
drew ids from a fresh counter. Those ids could collide with saved ids on other levels. Before
this slice, the global counter happened to prevent that. The load now claims every saved
fixture id before it generates anything.

**The 16 orphan reports in the test run were the input handlers.** 003 took a handler out of
the tree and queued it for freeing, so for the rest of the frame it was an orphan. The test runs
had reported 16 orphans every time. Leaving the handler in the tree and switching it off ended
all 16. This is the same lesson as 003's leak warning: a number that's in every run has a cause.

**Two section items were finished a section early.** `Objects` couldn't go (section B) without its
counter finding a home, so both counters moved onto the world in B rather than C. The renderers
couldn't read levels from the world (B) without hearing which world is shown, so
`shown_world_changed` was built in B rather than E. The checklist notes both. The section order
was still right: the game ran at the end of each section.

**The rename-first commit worked as trap 1 intended.** The autoload went to `WorldAutoload` with
`project.godot` pointing at its path rather than its uid, since the uid cache still named the old
file. That commit changed names only, so section B's diff is about the change of shape alone.

**(Claude) `godot` isn't on the Bash tool's PATH, and the failure was silent.** Two re-imports run
from Bash printed nothing and did nothing. That went unnoticed until a new `class_name`
(`SaveSession`) wasn't found. Tests had passed earlier only because each new class happened to
be picked up some other way. Godot runs from PowerShell only.

**(Claude) Two of Claude's own mistakes were caught before they cost a run.** A patch script had
the loaded-world swap call `_swap_world`, which would have freed the world it had just attached.
It was caught on reading the script. A GUT call passed a message where
`assert_signal_emitted_with_parameters` takes an index, and the run caught that one.

---

## What to do differently

1. **(Claude) Run Godot from PowerShell, always.** Treat any re-import that prints nothing as not
   run.
2. **When a slice removes a global, expect its accidental guarantees to go too.** The global
   fixture counter was quietly preventing an id collision that nothing tested. Before deleting a
   global, list what it was guaranteeing.
3. **Write the test for each "built from X" claim with an X that differs from the default.**
   `generate_level` passed every test until a recipe that wasn't the table's own row was handed
   to it.
4. **Keep the rename-first commit.** It made section B's diff readable. It's worth doing whenever
   a name has to be freed.
5. **(Claude) Write patch scripts to files, and match whitespace tolerantly,** as 002 and 003 said.
   This time a small `wsrep.py` helper was written once and reused, and that made the rule easy
   to keep.

---

## Open, carried forward

- **By hand, for Derik:** outcomes 1–4 (checklist B, D, E and G). Outcome 2 needs both saves cut
  short, or the backup deleted. Otherwise F6 loads the backup, as D-111 says it should, and the
  world does change.
- **A save whose only actors are NPCs gives nobody control.** The view then never re-points, so
  the renderers keep drawing the replaced world's level data. F3 now reads a freed world as
  "none" rather than erroring. A view that can show a world with no followed actor would fix it.
  Nothing makes such a save today.
- **003's leftovers are still open,** because none of the code they touch was rewritten: slot
  order (R-P6), the dead tool-loading code (R-B5), comment tidy-ups (R-S4), save-files.md, and
  tests for the playtime clocks. save-files.md is now also behind D-130 (the counters and
  `SaveSession`).
- **The load time wasn't measured this slice.** It was about 100 ms at the end of 003. F3's
  "Last load" will show whether building a whole `World` changed that.

---

## Closed

*Added by Claude, 2026-11-02, when the slice was closed.*

Derik walked outcomes 1, 3 and 4 by hand on 2026-11-02, and nothing turned up. He skipped
outcome 2 by hand, because `test_f6_on_a_truncated_save_changes_nothing` already covers it. All
of the checklist is ticked (last at `c8e5d62`). The load time still wasn't measured, and that
moves to slice 005 along with the rest of "Open, carried forward".
