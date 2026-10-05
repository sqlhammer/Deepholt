# Slice 001 — Dig one tile

> The smallest thing that is actually Deepholt. You face a wall, you remove it, and the world
> is different and stays different.

## Mode

Sections A–C ran under the old agreement. Each remaining section's mode is asked before it
starts, and recorded in the checklist.

## Where we are

The project boots. `game.tscn` renders a 512 × 320 `SubViewport` through the pixel-upscale
shader into a full-window `TextureRect`, and `DebugOverlay` toggles on `F3`, fed by the
`Global.debug_event` signal. `scripts/test.ps1` runs GUT headless.

`World` and `Global` are autoloads. `World` holds the seed, preloads `level_bounds.tres`
(eight rows, Surface through −7, named and with radii), maps internal depth to display, and
answers a radial `is_in_bounds`. `WorldPos` is a hashable value type. All of it has tests.

**None of it has ever been asked for anything.** Nothing has been drawn to that viewport.
`src/entity/`, `src/sim/` and `src/persist/` are empty directories. The coordinate work was
built against a specification rather than against a need, which is exactly the problem this
slice starts correcting: everything below either gets used, gets changed, or gets deleted.

## What should be true when you stop

By hand, in a running game:

1. Launch, and you are looking at a level — a hand-made one — where solid rock and open floor
   are immediately distinguishable at the intended pixel scale. Placeholder art is fine; being
   unable to tell at a glance what you can walk into is not.
2. A moleperson is in the open space. Keyboard and gamepad both move them. They do not walk
   through rock.
3. Face a rock tile, press dig, and that tile becomes open floor. You see it change.
4. Dig a corridor four or five tiles long and walk down it. The tiles you removed stay removed.
5. Walk to the edge of the level. Something deliberate happens. Not a crash, and not a silent
   walk into undefined space.
6. `F3` tells you what the world believes — at minimum where the actor is and what depth it
   calls that. Enough that when something looks wrong you can tell whether the world is wrong
   or the screen is.
7. Quit, relaunch. The level is back to its hand-made starting state and your corridor is gone.
   Nothing persists yet, and that is correct for this slice.

Separately, automated: the mutation path is covered by tests that do not need a running scene —
changing a tile and reading it back, and whatever you decide the rules are for digging something
that cannot be dug. Loading a level grid with no origin marker, or with two, fails and is
tested ([D-050](../docs/design-decisions.md)).

## What you're deciding

- **What a tile is**, at this stage, and how a level's worth of them is stored.
  *Partly decided:* a cell has a ground and a top, at minimum
  ([D-047](../docs/design-decisions.md)). Still open, before building:
  - ~~Where tile data lives, and in what shape.~~ Decided — [D-048](../docs/design-decisions.md).
  - ~~Which ground and top kinds exist.~~ Decided — [D-051](../docs/design-decisions.md), amended by [D-052](../docs/design-decisions.md).
    Out-of-data reads decided — [D-057](../docs/design-decisions.md), [D-059](../docs/design-decisions.md). Ore storage decided — [D-054](../docs/design-decisions.md).
  - ~~How the hand-made level is authored.~~ Decided — [D-049](../docs/design-decisions.md).
- **How the world reaches the screen.** Godot offers several routes here with very different
  ceilings. The one that gets pixels up fastest is not obviously the one that survives eight
  resident levels and a culling camera later — and you do not have to solve for that yet, but
  you should know which you're choosing.
  *Decided:* a data texture read by a shader, not `TileMapLayer`
  ([D-046](../docs/design-decisions.md)). Still open, before building:
  - How tile data is encoded into textures — format, and whether the layers share a texture.
  - How an id becomes pixels — finding its atlas region, and combining ground and top.
  - How much of a level one quad covers.
- **Who is allowed to change a tile, and how anything else learns that it changed.** This is the
  decision in this slice with the longest tail. It also settles how a changed tile reaches the
  GPU, so it is needed before the dig verb exists, though not before a static level is drawn.
- **What an actor is** — the thinnest thing that can be one, given that no system may assume there
  is exactly one of them (pillar [P5](../docs/game-overview.md), rule [D-045](../docs/design-decisions.md)).
- **How input reaches an actor.** The standards permit presentation code to hold a reference to
  the locally controlled actor. They do not say where that reference lives or who sets it. That
  gap is yours.
- **Whether digging is instant.** A feel question. You can only answer it by looking at it, which
  is the point of stopping here rather than three systems later.

## Already settled

- **The world is a stack of top-down levels, and it is material you remove — what's left behind is
  the building.** (Pillars P1 and P2, [game-overview.md](../docs/game-overview.md).)
- **No player singleton** — simulation code takes an actor, or a set of actors, as a parameter;
  nothing global resolves to *the* character ([coding-standards.md](../docs/coding-standards.md),
  rationale in [D-045](../docs/design-decisions.md)). This slice is the first real pressure on that
  rule, and the sim/presentation split in **Source layout** is how it's enforced.
- [Source layout, naming, tabs, signals over direct calls](../docs/coding-standards.md).
- [art-and-camera](../docs/tech/art-and-camera.md) — §3's viewport constants are already
  built. **§2 binds how the world reaches the screen, and probably what a tile is.** You would
  not guess it from this slice and it is not cheap to retrofit, so read it before you commit to
  a render route.
- [digging-and-structure.md](../docs/systems/digging-and-structure.md) — read its **pre-alpha
  subset** for what the dig verb is and is not.
- [pre-alpha-scope §4](../docs/pre-alpha-scope.md) — deferred systems get no stubs. No support
  rule, no light, no tool durability, no procgen. Hand-made level throughout.

## Traps

Rewritten 2026-10-04 under the revised [working agreement](./WORKING-AGREEMENT.md): each trap is
explained in full, along with what's already been dealt with and what's still live.

### 1. The seam between *the world knows a tile changed* and *the screen knows*

**The trap.** The cheapest working version is for the dig verb to write the tile and then
poke the renderer itself. It works with one actor on the one level being drawn. It fails
silently the first time a tile changes some other way: another actor (no system may assume
there's exactly one, pillar [P5](../docs/game-overview.md), rule
[D-045](../docs/design-decisions.md)), a resident level that isn't being drawn, or any later
system that rewrites tiles. The screen then shows a world that no longer exists.

**Already dealt with.** [D-065](../docs/design-decisions.md) puts the notification on the
tile data. Whatever changes a tile, the level's tile data announces it, naming the tile and
nothing about who changed it, and the renderer rewrites that texel. Changes in one frame
are batched into one upload.

**Still live, for section E:**
- **The arrays are public.** `LevelTiles.ground`, `.top` and `.ore` are plain `var`s, so
  `tiles.top[i] = x` compiles and skips the notification entirely. The guarantee only holds
  if the setters are the *only* way in. In GDScript that's convention plus review, since
  there's no `private`. An underscore prefix and a test are how you make it visible.
- **One dig is several writes.** Opening a tile sets `top` and has to clear `ore` (painting
  in order means ore would otherwise draw over open floor, per
  [D-066](../docs/design-decisions.md)). That's two notifications for one change. The
  per-frame batching in D-065 absorbs that, but only if the renderer actually batches
  instead of uploading once per signal.
- **Setters fail silently.** `set_top` outside the bounds just returns. That's fine for
  the data, but the dig verb needs to know it was refused, or "the rules for digging
  something that cannot be dug" get decided by accident, as a no-op.
- **Who may change a tile** is still open, and it's a different question from how others
  learn about it. Keep them apart when you decide it.

### 2. Where `WorldPos` meets pixels

**The trap.** Two coordinate systems meet, and off-by-ones live where they meet.

**Already dealt with.** [D-067](../docs/design-decisions.md) fixes the convention. Tile
`(x, y)` covers pixels `16x` to `16x + 16` and the same down, with +y down the screen, and
world `(0, 0)`'s top-left corner on the level node's origin.
`LevelRenderer.tile_center` goes from tile to pixel.

**Still live, for section D** (the actor is the first thing that goes from pixel back to
tile):
- **Negative coordinates.** The pixel-to-tile conversion must floor. GDScript's integer `/`
  truncates toward zero, so `int(-5 / 16)` is `0`, but the tile is `-1`. Use
  `floori(px / 16.0)`, or `Vector2i((pos / 16.0).floor())`. Truncating puts a row and a
  column of tiles in the wrong place: everything in `-1` gets reported as `0`. Half of every
  level has negative coordinates, so you'll see it, but only if you test on that side of
  the origin.
- **Which space the position is in.** The conversion is only valid in the level node's own
  space. If the actor isn't a child of the level, or the level node ever moves, go through
  `to_local()` first, or the answer will be off by however far the level moved.
- **A point is not a body.** "They do not walk through rock" checked only against the tile
  under the actor's center lets half the sprite overlap rock before it's blocked. Blocking
  has to account for the actor's extent (for example, check the tiles under the corners of
  its box at the position it's moving *to*), and it's answered from tile data, not physics
  bodies ([D-046](../docs/design-decisions.md)).

### 3. `is_in_bounds` is radial, and tiles are square

**The trap.** `World.is_in_bounds` is `distance((0, 0), (x, y)) <= radius` on tile
coordinates. At tile granularity that disc isn't a smooth circle. Here it is at radius 6
(`#` in bounds):

```
......#......
...#######...
..#########..
.###########.
.###########.
.###########.
#############
.###########.
...
```

- **A single-tile spike at each cardinal extreme.** `(r, 0)` is in bounds, but
  `(r, ±1)` are not, because `r² + 1 > r²`. That's true at every radius, so each level has
  four one-tile-wide nubs at north, south, east and west. Walking along the edge snags on
  them, and an actor wider than a tile can't fit into them.
- **Staircases on the diagonals.** The edge is stair-stepped, so "walk to the edge" looks
  different depending on direction, and a box-shaped actor touches several tiles at once
  there.
- **What's past the edge reads as 254, not as rock.** Outside the disc, `get_top` returns
  `SENTINEL_OUT_OF_BOUNDS`, which is neither `OPEN` nor `MINABLE_ROCK`. Passability written
  as a blacklist ("blocked if minable rock") lets the actor walk straight out into 254.
  Written as an allowlist ("passable only if open") it blocks correctly. The same goes for
  digging, which must refuse 254 and 255.
- **The outermost ring is diggable.** The default is minable rock right up to the edge, so
  once you dig the last ring, the only thing between the actor and the void is whatever
  passability decides about 254. Section D's edge decision should take that into account,
  not just the undug edge.

Run the game and look at a cardinal extreme and a diagonal at the Surface radius (90) before
you decide what happens at the edge. The hatched outside-level art (D-066) makes both visible.
