# Slice 006 — Down into the dark

> Start a new game and only the Surface and −1 exist; each level appears as someone first
> reaches the one above it. Underground, the screen is black past what you can sense, your own
> tunnels stay drawn where you've been, and a brazier in the home cave shows what light is for.

*Proposed by Claude, 2026-11-02, from [NEXT.md](./NEXT.md)'s sketch, with Derik's scope from
planning: generation on first descent first, then all four render states of the dark, with a
brazier as the light. Derik accepts, edits or replaces it.*

## Where we are

Slice 005 is done and merged ([log](./log/005-clearing-the-backlog.md)). The world is a node
that owns its levels, its actors, its id counters and its `TuningProfile`. A load returns a
typed `LoadedGame`, and every swap shows the new world at its spawn's depth. A level change
fades through black in the view, and the move itself is instant. Fixtures can move through the
gatekeeper, and a ladder faced down wins.

**What 006 changes, in two parts:**

1. **Generation on first descent.** Today `LevelGenerator.generate_world` builds all eight
   levels at launch. The design ([world-runtime §8](../docs/tech/world-runtime-and-persistence.md#8-generation-threading))
   says only the Surface and −1 exist at a new game, and the rest come as they're reached.
2. **The dark.** Today every tile is drawn in full color, everywhere. Pillar
   [P3](../docs/game-overview.md) asks for the dark as home: four render states per tile
   ([D-033](../docs/design-decisions.md#d-033--tunnel-memory-four-render-states-per-tile)), with
   ore identity needing light
   ([D-010](../docs/design-decisions.md#d-010--dark-vision-light-is-capability-not-survival)).

**What a level and its drawing are made of, today:**
- `LevelTiles` holds three byte layers (`ground`, `top`, `ore`). `SaveGame.TILE_LAYERS` names
  the ones saved, and a missing layer loads as its default (D-112).
- `LevelRenderer` turns each layer into a one-texel-per-tile data texture, and
  `level_tiles.gdshader` picks atlas cells from them
  ([D-046](../docs/design-decisions.md#d-046--levels-reach-the-screen-through-a-data-texture-and-a-shader-not-tilemaplayer)).
  A change to a layer marks it dirty, and only dirty layers are uploaded.
- Fixtures are drawn by `FixtureRenderer` from each level's `LevelFixtures`. A fixture's kind
  needs an entry in `ObjectKind`, a texture, and a prefab character to be placed by a grid.
- `LevelGenerator.ladder_problems` and `ramp_problems` check pairs across levels, and assume
  every level exists.

## What should be true when you stop

By hand, unless marked:

1. `--new-game`: F3 lists only the Surface and −1 as generated. Walk down to −1, and −2 is
   listed, with how long it took. Take the way down to −2: it works, and −3 appears.
2. Save on −1, relaunch: the world comes back with the same levels, no more and no fewer, and
   the way down from −1 still works.
3. Underground, the screen is black past your dark-vision radius, and monochrome within it.
4. Walk away from a tunnel you've seen: it stays drawn as a dim outline. Relaunch, and it's
   still there. Rock you've never seen stays black.
5. In the home cave, the tiles around the brazier are in full color. Copper in that light shows
   as copper; the same vein in the dark is a grey lump.
6. The Surface is lit throughout.
7. *Automated:* any actor's arrival generates the level below, once, in a world outside the
   game scene too. Two worlds generate independently.
8. *Automated:* a save missing a level loads without a refusal, and the level below each actor
   is generated after the swap, never during the load.
9. *Automated:* the memory layer round-trips through a save; a save without it loads with
   nothing remembered.
10. *Automated:* light is derived: it's recomputed after a load and when a light fixture
    changes, and nothing about it is saved.

## Mode

**Educational Assistant**, for the whole slice (Derik, 2026-11-02). Derik builds. Claude writes
a walkthrough per checklist section in the gitignored `work/lesson/`, before Derik starts that
section and after its forks are settled. Each covers the decisions, the reasons, the trade-offs,
how the pieces work and the traps, with small snippets only, never the complete work. Claude
answers questions straight and in full, and reviews each section once it's built.

**Section B was finished in Agent mode** (Derik, 2026-11-03), on `main`, and **C and D were
built in Agent mode** too (Derik, 2026-11-08), with every decision put to him first.

## What you're deciding

Generation on first descent is settled
([D-143](../docs/design-decisions.md#d-143--levels-are-generated-one-ahead-of-arrival-by-the-world-on-the-main-thread)),
and so is the dark's scope
([D-144](../docs/design-decisions.md#d-144--slice-006s-dark-all-four-render-states-and-light-from-a-brazier)).
The forks left are the dark's, taken before section C and D:

- **Whose senses draw the screen.** Sensed comes from the followed actor only (presentation, as
  [D-045](../docs/design-decisions.md#d-045--no-player-singleton-carves-out-the-presentation-layer)
  allows), or from every player in the shown world.
- **Whose memory, and who writes it.** Remembered is one bit per tile per world (D-033). Is it
  set by any player's senses, or only the local player's? Is writing it a world-level change
  through the world, like a dig
  ([D-078](../docs/design-decisions.md#d-078--world-is-the-only-thing-that-changes-tiles-at-runtime)),
  or a layer anything can set, since it's perception rather than terrain?
- **What "seen" means for memory.** Every tile within the sense radius, or only tiles with a
  line of sight (rock you can't see past, as NEXT.md's sketch says)? Line of sight changes what
  a dug tunnel reveals of the rock around it.
- **How the four states reach the shader.** One derived "visibility" texture with a state per
  tile, built on the CPU; or the memory layer plus the actor's position and the light field as
  shader inputs, with the state worked out per pixel.
- **What Remembered looks like.** An outline of the open tiles' edges, the tiles darkened, or
  the monochrome look dimmed further.
- **How light spreads.** A plain radius from each brazier, or blocked by rock (light that stops
  at walls). And whether light has levels (bright near the flame, dimmer at the edge) or is
  on/off per tile.

## Already settled

- **Generation:** one level ahead of any actor's arrival, by the world, on the main thread,
  timed in F3; a load builds only what the save holds, then generates each actor's level below
  after the swap (D-143).
- **The dark's scope:** all four states; ore legible only when Lit; the Remembered bit saved,
  light and Sensed derived; a brazier placed by the home cave's prefab, its radius in the
  tuning profile; the Surface lit by daylight (D-144).
- **Four render states, one persistent bit per tile** (D-033). **Light is capability, not
  survival:** unlit space is fully navigable (D-010).
- **Levels are drawn through data textures and a shader** (D-046). A new per-tile fact reaching
  the screen is one more texture or one more shader input.
- **A new tile layer is saved by name, and a missing one loads as its default**
  ([D-112](../docs/design-decisions.md#d-112--tile-layers-are-saved-by-name-a-byte-layer-per-fact-a-saved-bound-wins)),
  and format v1 is edited in place until the first playtest
  ([D-133](../docs/design-decisions.md#d-133--save-format-version-1-is-settled-when-the-first-build-goes-to-someone-else)).
- **Tunable numbers go in the world's profile, not in code:** the sense radius and the brazier's
  light radius
  ([D-135](../docs/design-decisions.md#d-135--the-world-holds-its-tuning-profile-every-number-in-code-moves-into-it)).
- **Anything that draws follows `shown_world_changed`**
  ([D-129](../docs/design-decisions.md#d-129--a-swap-happens-at-the-end-of-the-frame-and-the-view-re-points-everything-that-draws),
  [D-132](../docs/design-decisions.md#d-132--every-swap-shows-the-new-world-at-its-spawns-depth-following-an-actor-moves-only-the-depth)).
- **No system assumes exactly one actor** (pillar [P5](../docs/game-overview.md)), and nothing
  in simulation resolves to *the* player (D-045).
- **A new fixture kind gets a new, never-reused `ObjectKind` id,** a prefab character and art
  ([D-103](../docs/design-decisions.md#d-103--fixtures-names-signals-refusal-reasons-and-the-conflict-table),
  [D-105](../docs/design-decisions.md)). The brazier's placeholder art is already in
  `game/src/render/brazier.png`, 16 x 24.

## Traps

### 1. The cross-level checks assume every level exists

`ladder_problems` reports a ladder with "no level above it", and `ramp_problems` reports a ramp
end whose other level is missing. With only some levels generated, the deepest one's way down
leads to a level that doesn't exist yet. `generate_world` turns each problem into a
`push_error`, and GUT fails a test on any `push_error`. Decide what a check does when the other
level isn't there (skip the pair, and check it when that level arrives), before writing the
generation.

### 2. Generating during a load, or during a swap

A load moves a stuck actor to the spawn (D-115) before the game listens to it, and that's a
depth change. If the world generates on every arrival, a load can generate mid-build: drawing
fixture ids before the counters are restored, or building a level into a world that's about to
be refused. D-143 says after the swap; make sure the world's listener can't fire before then.

### 3. Fixture ids now depend on the order levels are reached

Today the generator draws fixture ids in depth order at launch. Generated on arrival, a level's
fixture ids depend on when it was reached, and the generator's own counter is the world's.
Tiles stay deterministic (each level's seed is `hash(world_seed, depth)`), but any test that
expects a particular fixture id from a generated world may change.

### 4. A world with eight levels is assumed in more places than generation

Tests check "ready spawns each depth once", F3 lists levels, `world.levels()` is iterated by
the load checks, and a renderer asked to show a depth with no level is an error. Grep for
eight, for `levels().size()`, and for `level_at(` callers that don't handle null, before the
first test run.

### 5. Memory changes constantly, and the shader upload must keep up

Every step can mark a ring of tiles remembered. If each change marks the whole memory layer
dirty and uploads it, a large level re-uploads a texture every step. The dirty-layer mechanism
exists already; measure the upload before and after. Slices 002 and 003 both blamed slowness on
the wrong thing until it was broken down.

### 6. Hiding ore is presentation; removing it would be a bug

Ore identity is gated on light in the *renderer*. The tile data keeps its ore, the dig still
takes ore's 1.5x hardness in the dark, and a save keeps the ore. If anything in `src/world/`
starts checking light to decide what a tile *is*, that's simulation depending on presentation,
which the source layout forbids.

### 7. Light is derived, so a load and a swap have to rebuild it

Nothing about light is saved (D-144). After a load, a swap or a fixture change (a brazier
placed or moved, later), the light field must be recomputed. That's the same trap as 004's
renderers that kept listening to a freed world (trap 3 there): test that light follows a new
world.

### 8. "The" viewer creeps in

Sensed is per viewer, and memory is per world. It's easy to compute both from the local player
inside the world's code. Settle the two forks above first, and keep the local player in
`src/render/` or `src/debug/` only (D-045).

### 9. From the 004 and 005 logs

- **When removing an assumption, list what it was quietly guaranteeing.** "All eight levels
  exist" guarantees every cross-level check, every ladder's hole, and every renderer's depth.
- **Write the test for each "built from X" claim with an X that differs from the default.** For
  memory: a save with a remembered tile the generator would never mark.
- **Run the game by hand per section,** not only at the end.

## Carried into this slice

From [NEXT.md](./NEXT.md) at the 005 close:
- **Generation on first descent** (Derik, 2026-11-02).
- **The level-change fade is a black overlay** (D-142). A dark that's already near black may
  want it restyled; that's a judgment for the by-hand walk, not a checklist item.
- **The dead Surface hole** (D-140) is kept for judging how a hole reads in the dark; but the
  Surface is lit (D-144), so −1's holes are where that's judged.
- **Still open from 005, for Derik by hand:** F3's hole as `h`, pruning after several
  `--new-game` launches, the load time, and the fade with a held dig.
