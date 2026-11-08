# Slice 007 — Dig your own way down

> Stand beside the floor, breach it into a hole, switch to build mode, and set a ladder in it.
> Climb down to a level nobody built a way into. Your flint can break the Surface's floor and
> −1's, but not −2's.

*Proposed by Claude, 2026-11-08, for Derik's approval. Scope set in planning: breach a floor and
place a ladder, free of cost for now; Agent mode on a `slice-007` branch. Nothing is built until
Derik approves this brief.*

## Where we are

Slice 006 is done ([log](./log/006-down-into-the-dark.md)): levels are generated one ahead of
arrival, and underground is dark: Sensed, Remembered, and Lit by braziers. Derik walked it, and
the Sensed and Remembered greys were retuned after his first look (0.5 and 0.2).

**What a player can do today:** walk, dig walls (the dig capability, through the world's tile
gatekeeper), and take the ramps and ladders the generator placed. Nothing makes a hole or
places a fixture at runtime. The world's fixture gatekeeper (`place_requested`,
`move_requested`) has only ever been called by tests.

**What 007 adds, per the design:**
- **Breach**, the floor verb: "slower, deliberate, requires a tool of that stratum's tier. This is
  the *only* remaining hard tool gate on descent"
  ([digging-and-structure §1](../docs/systems/digging-and-structure.md)). The tuning appendix
  gives `breach_seconds = (hardness × 8) / tool_power` and `breach requires tool_power ≥
  hardness × 1.2` ([tuning appendix §4](../docs/tuning-appendix.md)). With flint (16): the
  Surface's floor in 3.0 s, −1's in 5.0 s, −2's refused (it needs bronze).
- **A build mode with the anchored cursor**: a grid cursor clamped to about 5 tiles around the
  character, the same reach and rules for mouse and stick
  ([ui-ux §2.1, §7](../docs/ui-ux-and-controls.md)). The ladder is its only item for now.
- **Placing a ladder**, free for now. The cost (wood) arrives with items and inventory, and the
  build mode is shaped so a cost slots in without rebuilding it.

## What should be true when you stop

By hand, unless marked:

1. On −1, face the floor beside you and breach it. It takes about 5 seconds with flint, and the
   tile becomes a hole. On −2 the same breach is refused, and the game says why.
2. Toggle build mode. A cursor appears on the grid within about 5 tiles of you, moved by the
   mouse or the right stick, and the screen shows whether a ladder can go where it points.
3. Point at your hole and place a ladder. Its top shows in the hole, and interact takes you down
   to −2, then back up.
4. Save, relaunch: the hole and the ladder are still there, and the ladder still works.
5. The temporary Surface hole is gone on a `--new-game` (D-140).
6. *Automated:* a breach goes through the world's tile gatekeeper and is refused under-tier,
   out of bounds, on the deepest level, and on a tile that isn't floor.
7. *Automated:* a ladder placed at runtime takes the world's next fixture id, survives a save,
   relights nothing, and is drawn, including its top, on both levels.
8. *Automated:* every rule holds for an NPC and in a second world (pillar
   [P5](../docs/game-overview.md)).

## Mode

**Agent**, for the whole slice (Derik, 2026-11-08), on a `slice-007` branch with small commits,
one or more per section, the suite green before each; Derik merges the PR. Claude stops for
every design fork below, one at a time, and for anything else with long-term consequences.

## What you're deciding

Every fork was settled in planning on 2026-11-08, as D-150 to D-154. The list stays as the
record of what was weighed:

- **Where the digging rules live:** a static `Digging` class in `src/world/`, taking the profile
  for its numbers; the profile holds only numbers
  ([D-150](../docs/design-decisions.md#d-150--digging-rules-live-in-a-static-digging-class-that-takes-the-profile)).
- **A floor's hardness:** its level's, from the appendix's stratum table, in the profile, with
  the appendix's breach formula
  ([D-151](../docs/design-decisions.md#d-151--a-floors-hardness-is-its-levels)).
- **What's beneath a breach:** the breach clears the landing below, both levels in one request,
  whole or not at all. Only plain open floor with both ends clear can be breached; nobody falls
  ([D-152](../docs/design-decisions.md#d-152--a-breach-opens-a-hole-and-clears-its-landing-only-plain-floor-with-both-ends-clear)).
- **How you breach:** its own input, held while facing the floor (`R` / pad `X`)
  ([D-153](../docs/design-decisions.md#d-153--breaching-has-its-own-input-held-while-facing-the-floor)).
- **Build mode:** `E` / `Y` toggles it; the mouse or right stick moves the cursor; primary
  places. A ladder is aimed at a hole on your own level, and the cursor acts only on Sensed or
  Lit tiles
  ([D-154](../docs/design-decisions.md#d-154--build-mode-follows-ui-ux-a-ladder-is-aimed-at-a-hole-you-can-see)).

## Already settled

- **A ladder is a fixture on the lower level, under a hole on the level above**
  ([D-089](../docs/design-decisions.md#d-089--a-ladder-is-an-object-on-the-lower-level-a-hole-is-a-ground-kind-a-ramp-is-a-tile-kind)).
  The ladder rule, both ways, and the tie (facing a usable hole goes down,
  [D-139](../docs/design-decisions.md#d-139--on-a-ladder-facing-a-usable-hole-interact-goes-down))
  already work.
- **Tiles change only through the world's tile gatekeeper, and fixtures only through its fixture
  gatekeeper**, as requests answered on the actor's own world
  ([D-078](../docs/design-decisions.md#d-078--world-is-the-only-thing-that-changes-tiles-at-runtime),
  [D-125](../docs/design-decisions.md#d-125--the-gatekeepers-are-the-same-request-and-outcome-signals-on-the-world-instance),
  [D-126](../docs/design-decisions.md#d-126--a-level-knows-its-world-everything-else-reaches-the-world-through-a-level)).
- **Hardness belongs to tile kinds; the one tool is flint, power 16**
  ([D-081](../docs/design-decisions.md#d-081--hardness-belongs-to-tile-kinds-the-pre-alpha-tool-is-a-flint-pickaxe)).
  Tuning numbers live in the world's profile
  ([D-135](../docs/design-decisions.md#d-135--the-world-holds-its-tuning-profile-every-number-in-code-moves-into-it)).
- **No pixel precision, no click-drag; every placement snaps to a character-anchored cursor;
  mouse and stick have the same reach** ([ui-ux §1, §2.1](../docs/ui-ux-and-controls.md)).
- **Valid and invalid placement show by shape and icon as well as color**
  ([ui-ux §7](../docs/ui-ux-and-controls.md)).
- **Levels exist one ahead of arrival** (D-143), so the level below a breach always exists,
  except below the deepest.
- **The temporary Surface hole comes out in this slice**
  ([D-140](../docs/design-decisions.md#d-140--the-temporary-surface-hole-stays-until-slice-007)).
- **Light and memory follow tile and fixture changes already** (D-145, D-149): a breach and a
  placed ladder update the dark without new wiring.
- **No system assumes one actor** (pillar [P5](../docs/game-overview.md)); the build cursor is
  presentation and may know the local player
  ([D-045](../docs/design-decisions.md#d-045--no-player-singleton-carves-out-the-presentation-layer)).

## Traps

### 1. The tile gatekeeper only knows one change

`World._on_dig_requested` sets a tile's top to open. A breach changes the *ground* to a hole,
and may change the level below (the landing). It needs its own request, refusal reasons and
outcome, and two levels changing in one request must not be half-applied if the second
refuses.

### 2. A hole under someone

An actor standing on a tile that becomes a hole is standing on something impassable. Refuse
breaching your own tile, and decide what happens to anyone else standing there (an NPC, a
second player): refuse, or move them.

### 3. The fixture gatekeeper's first real caller

Placement has only run in tests. The first runtime placement draws a fixture id from the
world's counter, the renderer draws it, and the next save writes it, so check the counter
carries on across a save and load (D-130). And a ladder placed under a hole on the *upper*
level has to redraw the ladder top there, through the fixture renderer's `_below` listener.

### 4. Ladder rules check the shape, not the story

`FixturePlacement` requires a hole above and passable ground for a ladder. If the landing below
is rock, placement is refused with `TILE_NOT_PASSABLE`. That's correct, but the player needs to
know why, and the "what's beneath" fork decides whether it ever happens.

### 5. Input modes multiply

Build mode turns primary action into "place". A held dig, a held breach, the level-change fade
(input paused, D-142) and F5/F6 all meet here. Decide what each does when build mode toggles
mid-action.

### 6. The dark hides the target

Underground, most tiles are Unknown or Remembered. The cursor has to be readable on black, and
the rules must not let you breach or place on a tile you can't sense. Or they should let you,
and that's a decision.

### 7. Removing the Surface hole changes `surface_start`

Existing saves keep their hole (a saved level wins over the recipe). Tests that read
`surface_start`'s hole (the F3 readout's `h`, D-107's dead hole) move to a hole that exists
elsewhere, or build one.

## Carried into this slice

- **005's by-hand items**, never reported.
- **`hardness_of` and `dig_hardness` on the tuning profile** (Derik's question): settled by
  D-150, and moved in section B.
- **The temporary Surface hole** (D-140).
