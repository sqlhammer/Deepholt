# Next

Sketches, not commitments. Slice 002 is done ([log](./log/002-go-down.md)); 003 is the one I'd
argue for next, and the order past it should fall out of what 003 teaches. Cheap to throw away —
expect them to change.

---

## 003 — It persists

Save a dug world, quit, reload, and your corridor is still there, on every level, with the ladder
and the spawn where they were.

Moved ahead of the dark, which was 003 in the last sketch. Slice 002 roughly doubled the state a
save has to hold: fixtures and their ids, the id counter, the world spawn, each level's shape. The
dark would add a persistent "remembered" bit per tile ([D-033](../docs/design-decisions.md)).
Every slice that adds state before saves exist adds a retrofit, and the save notes below have
been piling up since slice 002's generation discussion. Better to settle the format while there
is still little to put in it. It's also the first time excavation survives a session, which is
the first time it feels like tenancy rather than a sandbox.

## 004 — The dark

Dark vision, a light radius, and rock you cannot see past. The first half of *the dark is home,
the sun is the hazard* (pillar [P3](../docs/game-overview.md)) — inverted from the genre default.

Changes what "readable" means: slice 001 made rock and floor distinguishable, slice 002 added
holes, ramps and ladder tops that have to read at a glance, and this one takes most of the screen
away and asks again. Tunnel memory's remembered bit is persistent, so it lands in a save format
that already exists. Likely the first slice where the render route from 001 (D-046) either holds
up or gets replaced.

## 005 — Dig your own way down

Breach a floor to make a hole, and build a ladder in it. The first runtime use of the `Objects`
gatekeeper (it has only ever placed things during generation), and the first of the vertical
logistics ladder you build rather than find ([vertical-logistics §2](../docs/systems/vertical-logistics-and-power.md)).
Breaching is the M1 verb and the one hard tool gate on descent
([digging-and-structure §1](../docs/systems/digging-and-structure.md)); building needs at least a
placement mode. Probably too big as one slice; the split should fall out of 003 and 004.

---

### Save notes (for 003)

From slice 002's level-generation discussion (2026-10-11) and what 002 built:

- **Save the result, not the recipe.** Store the tiles (about 3 MB uncompressed for the whole
  mountain, world-runtime §1). Regenerating from seed + recipe and replaying digs means any later
  change to a recipe or prefab silently changes old worlds. Recipes matter only at new-game time.
- **Save each level's `LevelBound` with it,** so loading never needs a recipe (D-085).
- **Tile kind ids and fixture kind ids are forever;** a save is numbers of both (trap 8, D-104).
- **Save the fixtures, their ids, and `Objects`' id counter,** so ids stay unique after a load
  (D-104). The world spawn is a fixture, so it is saved like any other.
- **Save seeds as numbers, not strings.** `hash()` isn't promised stable across Godot versions.
- **Version the format from the first save,** and record `tuning_profile_id`
  ([D-037](../docs/design-decisions.md): one swappable resource for every tuning number, named in
  each save so playtest feedback is traceable). Not built yet; decide in 003 whether to build it.
- **Don't save derived data** — support, light, chambers are recomputed on load
  ([world-runtime §3](../docs/tech/world-runtime-and-persistence.md)).
- **Where actors are is saved;** where they *spawn* is only used for new players and deaths
  (D-091).

---

Still unplaced and eventually required: the support rule — excavated space has to be held up or it
fails (pillar [P4](../docs/game-overview.md)) — the rate machine that lets a hoist
haul while you are three levels away, procgen beyond the recipe's fixed placements (D-084's rules
and tags). None of them are next.

---

## Deferred from 002

- **Level-change transitions** ([D-108](../docs/design-decisions.md)). Ramps and ladders are
  instant for now; a transition time and visual effects are wanted later. It goes between the
  request and `Actor.change_depth`, not into the `Ramp` or `Ladder` rules, and must say what a held
  dig does during it.
- **Moving a fixture** (a bed, M6). Discussed in 002, not recorded: make `Fixture.tile` read-only,
  move through the store and the gatekeeper, and decide whether a move is announced as a removal
  plus a placement or as its own event.
- **Up or down when both apply on a ladder** (D-106, not decided). Needs side-by-side shafts and
  −3.

## Carry-forward

Found during slices 001 and 002, not recorded anywhere else. Bring into planning; none of it is
decided.

- **Hardness is still called `density` in code** (`TileKind.MINABLE_DENSITY`). Renaming it to
  match the tuning appendix is an optional tidy-up (D-081).
- **The appendix's own numbers miss the 0.5–0.7 s band at −5 and −7** (D-081, open). The content
  validator that would catch this ([content-schema §5](../docs/tech/content-schema.md)) isn't
  built.
- **`dig_refused` and `Objects.request_refused` carry reasons that nothing reads yet.** They're
  there for feedback (sound, UI) when that arrives.
- **The test suite is slow because of `test_game.gd`.** Each of its tests loads `game.tscn`, which
  builds all eight levels; the read-only tests could share one game in `before_all`.
- **`LevelFixtures.add` accepts the same fixture twice.** A one-line guard would make it an error.
- **`F3`'s tile window prints a hole as `.`** (the readout names it).
- **The temporary hole at (0, 2) in `surface_start`** is kept on purpose; take it out when it has
  served its purpose.
- **Coverage at the end of slice 002: 98.9%** (`python scripts/coverage.py`).
- **Finished lessons in `work/lesson/`** (`E-open-a-dug-tile.md`, and `D-00` to `E-01` from 002)
  can be deleted; they're gitignored, so nothing else tracks them.
