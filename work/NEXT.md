# Next

Sketches, not commitments. Slice 002 is the one I'd argue for; past that the order should fall
out of what slice 001 teaches. Cheap to throw away — expect them to change.

---

## 002 — Go down

Two hand-made levels, a ladder between them, and level −2 visibly wider than −1. You descend
and the world changes around you while your `(x, y)` does not.

This is where the shared coordinate origin stops being a claim and starts being load-bearing —
the thing the old M0 said was expensive to retrofit, finally under weight. It also forces the
question of what "current depth" means when nothing is allowed to own *the* player, and whether
levels are resident, loaded, or something else. Expect some of slice 001's answers to be wrong
here; that's the value.

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

Still unplaced and eventually required: the support rule — excavated space has to be held up or it
fails (pillar [P4](../docs/game-overview.md)) — the rate machine that lets a hoist
haul while you are three levels away, procgen. None of them are next.

---

## Carry-forward from 001

Found during slice 001, not recorded anywhere else. Bring into planning; none of it is decided.

- **Dirt is only half added.** `MINABLE_DIRT` is diggable and has a hardness (D-081), but the
  renderer has no art cell for it (it draws the magenta MISSING cell), the F3 overlay has no
  character for it (it shows `?`), and there is no grid character to place it in a prefab.
- **For 002 (Go down): the renderer's `QuadMesh` is a shared resource.** `show_level` resizes it
  in place. With one renderer that's fine; a second `LevelRenderer` created from the same scene
  would share it, and showing a level on one would resize the other. Fix when it arrives: tick
  *Local to Scene* on the mesh, or give each renderer `QuadMesh.new()`.
- **For 002: changing depth already has its pieces.** Setting `actor.depth` looks up the level
  (levels must be in the tree first, D-068); the renderer disconnects from the old level and
  connects to the new one in `show_level`. Rebuilding a level's textures costs about 92 ms at
  Surface and 580 ms at the Crush (D-065), a hitch that will be felt on each depth change.
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
