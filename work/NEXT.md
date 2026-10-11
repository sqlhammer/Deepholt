# Next

Sketches, not commitments. Slice 002 is now in [NOW.md](./NOW.md); past that the order should
fall out of what slices 001 and 002 teach. Cheap to throw away — expect them to change.

---

## 002 — Go down

In flight: see [NOW.md](./NOW.md).

## 003 — The dark

Dark vision, a light radius, and rock you cannot see past. The first half of *the dark is home,
the sun is the hazard* (pillar [P3](../docs/game-overview.md)) — inverted from the genre default.

Changes what "readable" means: slice 001 asks you to make rock and floor distinguishable, and
this one takes most of the screen away and asks again. Likely also the first slice where the
render decision from 001 either holds up or gets replaced.

## 004 — It persists

Save a dug world, quit, reload, and your corridor is still there.

The first time excavation survives a session, which is the first time it feels like tenancy
rather than a sandbox. Brings in the questions the old M0-09 was circling — format versioning,
what is stored versus recomputed on load — but arriving because a dug corridor deserves to
survive, rather than because a checklist said persistence goes here.

---

### Save notes, from the slice 002 level-generation discussion (2026-10-11)

- **Save the result, not the recipe.** Store the tiles (about 3 MB uncompressed for the whole
  mountain, world-runtime §1). Regenerating from seed + recipe and replaying digs means any later
  change to a recipe or prefab silently changes old worlds. Recipes matter only at new-game time.
- **Save each level's `LevelBound` with it,** so loading never needs a recipe (D-085).
- **Tile kind ids are forever;** a save is bytes of them (slice 002 brief, trap 8).
- **Save seeds as numbers, not strings.** `hash()` isn't promised stable across Godot versions.
- **Version the format from the first save,** and record `tuning_profile_id`
  ([D-037](../docs/design-decisions.md): one swappable resource for every tuning number, named in
  each save so playtest feedback is traceable). Not built yet; decide here whether to build it.
- **Don't save derived data** — support, light, chambers are recomputed on load
  ([world-runtime §3](../docs/tech/world-runtime-and-persistence.md)).

---

Still unplaced and eventually required: the support rule — excavated space has to be held up or it
fails (pillar [P4](../docs/game-overview.md)) — the rate machine that lets a hoist
haul while you are three levels away, procgen. None of them are next.

---

## Carry-forward from 001

Found during slice 001, not recorded anywhere else. Bring into planning; none of it is decided.

- *(Dirt: finished in slice 002, D-087.)*
- *(The two "for 002" items, the shared `QuadMesh` and the depth-change pieces, moved into
  [NOW.md](./NOW.md) and the checklist.)*
- **Hardness is still called `density` in code** (`TileKind.MINABLE_DENSITY`). Renaming it to
  match the tuning appendix is an optional tidy-up (D-081).
- **The appendix's own numbers miss the 0.5–0.7 s band at −5 and −7** (D-081, open). The content
  validator that would catch this ([content-schema §5](../docs/tech/content-schema.md)) isn't
  built.
- **`dig_refused` carries a reason that nothing reads yet.** It's there for feedback (sound, UI)
  when that arrives.
- **The test suite is slow because of `test_game.gd`.** Each of its tests loads `game.tscn`, which
  builds all eight levels; the read-only tests could share one game in `before_all`.
- **Coverage is measured with `python scripts/coverage.py`.** It instruments a temporary copy (a
  probe before every executable line in `src/`, `scenes/`, `singletons/`) and runs GUT. At the
  end of slice 001: 98.9%. Still uncovered: the two array-replacement warnings in `LevelTiles`
  (ground and ore), the renderer's `_process` upload call and its fallback read, and `_draw`.
- **`work/lesson/E-open-a-dug-tile.md`** is finished teaching content and can be deleted.
