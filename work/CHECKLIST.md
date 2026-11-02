# Slice 006 checklist

Working list for [NOW.md](./NOW.md). **Educational Assistant mode for the whole slice** (Derik,
2026-11-02): Derik builds; Claude writes each section's walkthrough in the gitignored
`work/lesson/` before Derik starts it, and reviews the section once it's built. Forks are taken
one at a time, before the section that needs them, and each lands as a `D-nnn`. Numbers in
brackets are the brief's outcomes.

Ordered as Derik chose in planning: generation on first descent first, so the save's shape
changes once before the dark adds a layer to it. Then memory and the senses, then light. The
game runs at the end of every section, and is launched by hand there (002's log).

Slice 005's checklist is in git history (last at `ca1ac7b`).

---

## A. Decided in planning

*Settled with Derik, 2026-11-02.*

- [x] Generation one level ahead of any actor's arrival, by the world, on the main thread,
  timed in F3. A load builds what the save holds, and generates each actor's level below after
  the swap
  ([D-143](../docs/design-decisions.md#d-143--levels-are-generated-one-ahead-of-arrival-by-the-world-on-the-main-thread)).
- [x] The dark's scope: all four states, ore legible only when Lit, the Remembered bit saved, a
  brazier in the home cave, the Surface lit
  ([D-144](../docs/design-decisions.md#d-144--slice-006s-dark-all-four-render-states-and-light-from-a-brazier)).
- [x] Placeholder brazier art: `game/src/render/brazier.png`, 16 x 24 (Claude).

## B. Generation on first descent

Lesson: `work/lesson/006-B-first-descent.md`.

- [ ] The cross-level checks (`ladder_problems`, `ramp_problems`) skip a pair whose other level
  doesn't exist yet, and the pair is checked when that level is generated (trap 1).
- [ ] `LevelGenerator` builds a new world with the Surface and −1 only, and can build one
  level into an existing world, drawing fixture ids from that world's counter (D-143, trap 3).
- [ ] The world generates the level below on any of its actors' arrival at a depth, once, and
  only where the recipe table has a row (D-143).
- [ ] Nothing generates while a load is building a world, or before it's swapped in. After the
  swap, each actor's level below is generated if missing (D-143, trap 2).
- [ ] A save without some levels loads with no refusal and no problem reported for the levels
  that don't exist yet. [8]
- [ ] F3 lists the generated depths, and how long the last generation took. [1]
- [ ] The places that assume eight levels are found and fixed (trap 4).
- [ ] Tests: an arrival generates the level below once; an NPC's arrival does too; a world
  outside the game scene grows; two worlds grow independently; a load with missing levels
  generates after the swap, never during it. [7, 8]
- [ ] By hand: `--new-game`, F3 shows the Surface and −1; walk down to −2 and −3; save on −1
  and relaunch. [1, 2]

## C. Memory and the senses

Lesson: `work/lesson/006-C-memory-and-senses.md`, written once C's forks are settled.

- [ ] *Decide:* whose senses draw the screen (the followed actor's, or every player's in the
  shown world).
- [ ] *Decide:* whose memory, and who writes it (any player or the local one; through the world
  or directly).
- [ ] *Decide:* what "seen" means: the whole radius, or line of sight.
- [ ] *Decide:* how the states reach the shader, and what Remembered looks like.
- [ ] The sense radius is a `TuningProfile` number (about 7 tiles,
  [D-135](../docs/design-decisions.md#d-135--the-world-holds-its-tuning-profile-every-number-in-code-moves-into-it)).
- [ ] A `memory` byte layer on `LevelTiles`, saved by name in `SaveGame.TILE_LAYERS`; a save
  without it loads with nothing remembered ([D-112](../docs/design-decisions.md)). [9]
- [ ] Memory is marked as decided, per world, and never from "the" player in simulation
  (trap 8).
- [ ] The renderer draws Unknown, Remembered and Sensed, follows `shown_world_changed`, and
  uploads memory without re-sending the whole layer every step (trap 5). [3, 4]
- [ ] Tests: memory round-trips through a save, with a remembered tile the generator would
  never mark (trap 9); a second world's memory is its own. [9]
- [ ] By hand: underground is black past the radius and monochrome within it; walk away and
  your tunnel stays outlined; relaunch and it's still there. [3, 4]

## D. Light, the brazier and ore

Lesson: `work/lesson/006-D-light.md`, written once D's forks are settled.

- [ ] *Decide:* how light spreads (a plain radius, or blocked by rock), and whether it has
  levels or is on/off per tile.
- [ ] The brazier is a fixture kind: a new `ObjectKind` id, a prefab character, its texture in
  `FixtureRenderer`, and placed in `rootshelf_home`
  ([D-103](../docs/design-decisions.md#d-103--fixtures-names-signals-refusal-reasons-and-the-conflict-table)).
- [ ] Its light radius is a `TuningProfile` number.
- [ ] The light field is derived per level from its light fixtures: rebuilt after a load, a
  swap, and any light fixture's change; never saved (trap 7). [10]
- [ ] Lit tiles draw in full color. Ore type shows only on Lit tiles; elsewhere a vein is a grey
  lump. The tile data and the dig are unchanged (trap 6). [5]
- [ ] The Surface is lit throughout (D-144). [6]
- [ ] Tests: light follows a swapped-in world; moving a brazier (D-138) moves its light; nothing
  about light is in a save. [10]
- [ ] By hand: copper by the brazier and copper in the dark; the Surface; how a hole on −1 and
  the level-change fade read in the dark. [5, 6]

## E. Done

- [ ] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
- [ ] `python scripts/coverage.py` run; uncovered lines looked at (005 closed at 97.5%).
- [ ] By hand: outcomes 1–6 walked in one sitting, launched outside the editor at least once.
- [ ] Claude reviews the slice.
- [ ] Claude writes `log/006-down-into-the-dark.md`.
- [ ] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Not in this slice, worth knowing

- **Generation on a worker thread** (world-runtime §8). D-143 keeps it on the main thread until
  the timing in F3 says otherwise.
- **Exposure and the sun** ([light-and-sunlight §2](../docs/systems/light-and-sunlight.md)). The
  Surface is simply lit.
- **Portable light, fuel, and placing lights at runtime.** Placing waits for 007.
