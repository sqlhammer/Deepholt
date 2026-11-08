# Slice 006 checklist

Working list for [NOW.md](./NOW.md). **Educational Assistant mode for the whole slice** (Derik,
2026-11-02): Derik builds; Claude writes each section's walkthrough in the gitignored
`work/lesson/` before Derik starts it, and reviews the section once it's built. Forks are taken
one at a time, before the section that needs them, and each lands as a `D-nnn`. Numbers in
brackets are the brief's outcomes.

**Section B finished in Agent mode** (Derik, 2026-11-03): Derik built the generator's two entry
points (`e6e61a3`), and Claude built the rest of B on `main`. **C and D were built in Agent
mode too** (Derik, 2026-11-08), stopping for decisions: D-147 to D-149, and a second brazier on
−2. Derik had already added C's profile numbers.

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

Lesson: `work/lesson/006-B-first-descent.md`. *Derik built the first two items' generator side;
Claude the rest (Agent mode).*

- [x] The cross-level checks (`ladder_problems`, `ramp_problems`) skip a pair whose other level
  doesn't exist yet, and the pair is checked when that level is generated (trap 1). *Ramps
  skip a missing other level; ladders still report a missing level above, which top-down
  generation can't cause. `LevelGenerator.problems_between(upper, lower)` checks a new pair.*
- [x] `LevelGenerator` builds a new world with the Surface and −1 only, and can build one
  level into an existing world, drawing fixture ids from that world's counter (D-143, trap 3).
  *`generate_world(seed, tuning)` builds the profile's `levels_to_generate_on_new_game`;
  `generate_into(world, depth)` (Derik).*
- [x] The world generates the level below on any of its actors' arrival at a depth, once, and
  only where the recipe table has a row (D-143). *`World.generate_below(depth)`, called from
  each actor's `actor_worldpos_changed`; `level_added` on every level joining a world.*
- [x] Nothing generates while a load is building a world, or before it's swapped in. After the
  swap, each actor's level below is generated if missing (D-143, trap 2). *An actor's starting
  place isn't heard as an arrival, so the load can't generate; the swap calls
  `world.generate_below_actors()` after the stuck-actor moves.*
- [x] A save without some levels loads with no refusal and no problem reported for the levels
  that don't exist yet. [8]
- [x] F3 lists the generated depths, and how long the last generation took. [1]
- [x] The places that assume eight levels are found and fixed (trap 4). *Tests only. The fixture
  renderer also redraws ladder tops when the level below arrives late. Hand-built test worlds
  got a blank −2 so an arrival on −1 doesn't generate the real −2 under them.*
- [x] Tests: an arrival generates the level below once; an NPC's arrival does too; a world
  outside the game scene grows; two worlds grow independently; a load with missing levels
  generates after the swap, never during it. [7, 8]
- [ ] By hand: `--new-game`, F3 shows the Surface and −1; walk down to −2 and −3; save on −1
  and relaunch. [1, 2]

## C. Memory and the senses

Lesson: `work/lesson/006-C-memory-and-senses.md`. Forks settled 2026-11-03 as
[D-145](../docs/design-decisions.md#d-145--senses-flood-through-open-space-the-followed-actors-draw-every-players-remember)
and D-146.

- [x] *Decide:* whose senses draw the screen (the followed actor's, or every player's in the
  shown world). *The followed actor's (D-145).*
- [x] *Decide:* whose memory, and who writes it (any player or the local one; through the world
  or directly). *Every player's, set by the world directly (D-145).*
- [x] *Decide:* what "seen" means: the whole radius, or line of sight. *A flood through open
  space, with the rock faces it reaches (D-145).*
- [x] *Decide:* how the states reach the shader, and what Remembered looks like. *One state
  texture built in GDScript; Sensed grey, Remembered darker grey
  ([D-146](../docs/design-decisions.md#d-146--the-four-states-reach-the-shader-as-one-state-texture-sensed-is-grey-remembered-darker)).*
- [x] The sense radius is a `TuningProfile` number (about 7 tiles,
  [D-135](../docs/design-decisions.md#d-135--the-world-holds-its-tuning-profile-every-number-in-code-moves-into-it)).
- [x] A `memory` byte layer on `LevelTiles`, saved by name in `SaveGame.TILE_LAYERS`; a save
  without it loads with nothing remembered ([D-112](../docs/design-decisions.md)). [9] *Bit
  flags, bit 0 remembered; `SAVED_ONLY_LAYERS` keeps an old save "whole"
  ([D-147](../docs/design-decisions.md#d-147--memory-is-a-saved-only-layer-of-bit-flags)).*
- [x] Memory is marked as decided, per world, and never from "the" player in simulation
  (trap 8). *`Senses.flood` in `src/world/`; the world marks each player's flood on every tile
  step and when it's added, so a new game's first tiles are remembered at once.*
- [x] The renderer draws Unknown, Remembered and Sensed, follows `shown_world_changed`, and
  uploads memory without re-sending the whole layer every step (trap 5). [3, 4] *A
  presentation `Visibility` node owns the state bytes; the level renderer, fixture renderer
  and view read them. Measured on the largest level: flood 0.06 ms, state build 0.02 ms.
  Actors hidden and fixtures dimmed in the dark
  ([D-148](../docs/design-decisions.md#d-148--in-the-dark-other-actors-are-hidden-and-fixtures-are-dimmed-with-their-tile)).*
  *Retuned by eye after Derik's first look (2026-11-08): Sensed read like normal lighting,
  so `sensed_brightness` 1.0 → 0.5 and `remembered_brightness` 0.35 → 0.2. Fading toward the
  ring's edge, low detail and warmer light were offered and not taken for now.*
- [x] Tests: memory round-trips through a save, with a remembered tile the generator would
  never mark (trap 9); a second world's memory is its own. [9]
- [ ] By hand: underground is black past the radius and monochrome within it; walk away and
  your tunnel stays outlined; relaunch and it's still there. [3, 4]

## D. Light, the brazier and ore

*Built in Agent mode, so no lesson was written.*

- [x] *Decide:* how light spreads (a plain radius, or blocked by rock), and whether it has
  levels or is on/off per tile. *The sense flood, on/off
  ([D-149](../docs/design-decisions.md#d-149--light-floods-like-the-senses-and-a-tile-is-lit-or-not)).*
- [x] The brazier is a fixture kind: a new `ObjectKind` id, a prefab character, its texture in
  `FixtureRenderer`, and placed in `rootshelf_home`
  ([D-103](../docs/design-decisions.md#d-103--fixtures-names-signals-refusal-reasons-and-the-conflict-table)).
  *`BRAZIER: 3`, prefab `B`, conflicts with ladders, spawns and braziers. A second brazier on
  −2 (Greyseam) at (−7, 3) lights one copper vein; −1 stays copper-free (Derik).*
- [x] Its light radius is a `TuningProfile` number.
- [x] The light field is derived per level from its light fixtures: rebuilt after a load, a
  swap, and any light fixture's change; never saved (trap 7). [10]
- [x] Lit tiles draw in full color. Ore type shows only on Lit tiles; elsewhere a vein is a grey
  lump. The tile data and the dig are unchanged (trap 6). [5]
- [x] The Surface is lit throughout (D-144). [6]
- [x] Tests: light follows a swapped-in world; moving a brazier (D-138) moves its light; nothing
  about light is in a save. [10]
- [ ] By hand: copper by the brazier and copper in the dark (on −2, by Greyseam's brazier); the
  home cave's brazier on −1; the Surface; how a hole on −1 and the level-change fade read in
  the dark. [5, 6]

## E. Done

- [x] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
  *810 tests, 41 scripts.*
- [x] `python scripts/coverage.py` run; uncovered lines looked at (005 closed at 97.5%).
  *97.4%.*
- [ ] By hand: outcomes 1–6 walked in one sitting, launched outside the editor at least once.
- [x] Claude reviews the slice. *In the log, as "choices made while building" and "open".*
- [x] Claude writes `log/006-down-into-the-dark.md`.
- [x] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Not in this slice, worth knowing

- **Generation on a worker thread** (world-runtime §8). D-143 keeps it on the main thread until
  the timing in F3 says otherwise.
- **Exposure and the sun** ([light-and-sunlight §2](../docs/systems/light-and-sunlight.md)). The
  Surface is simply lit.
- **Portable light, fuel, and placing lights at runtime.** Placing waits for 007.
