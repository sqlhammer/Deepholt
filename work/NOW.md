# Slice 001 — Dig one tile

> The smallest thing that is actually Deepholt. You face a wall, you remove it, and the world
> is different and stays different.

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
  - ~~Which ground and top kinds exist.~~ Decided — [D-051](../docs/design-decisions.md), amended by [D-052](../docs/design-decisions.md). Still
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

## What I'm not telling you

- There is a trap at the seam between *the world knows a tile changed* and *the screen knows a
  tile changed*. The cheapest thing that works for one level and one actor fails later in a
  specific and predictable way. Pick deliberately; you don't have to pick correctly.
- There is a second one where `WorldPos` meets the fact that Godot wants pixels. Two coordinate
  systems meeting is where off-by-ones live, and you now have both.
- `is_in_bounds` is radial. You have never looked at what that means at tile granularity. Look at
  a corner before you rely on it.

Ask directly and you get a straight answer on any of these. That's not a failure mode.
