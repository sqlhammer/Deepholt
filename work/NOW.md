# Slice 012 — A world worth digging

> You wake on a meadow at the end of a dirt road. Trees stand around you; the road winds toward
> a mass of grey rock and through a cut in it, down to the ramp. You have an axe and no timber.
> Below, the rock hides caves nobody made, and further down, at the Greyseam, it is seamed with
> copper and tin.

*Proposed by Claude, 2026-11-09, for Derik's approval. Scope and every fork settled in planning
([D-179](../docs/design-decisions.md#d-179--slice-012-is-polish-a-surface-worth-walking-trees-ores-and-caves-below-gentler-supports)
to D-187; D-187 corrects D-183: ore on −2 only). Agent mode on a `slice-012` branch. **Approved
by Derik the same day, with the numbers below as proposed.** **Built, 1060 tests green;
waiting on the by-hand walk** ([log](./log/012-a-world-worth-digging.md)).*

## Where we are

Slice 011 is merged ([log](./log/011-tools-in-hand.md)). The Surface is solid rock around a small
open start; −1 and −2 are hand-made rooms in solid rock, with no ore on −1 and only the hand-made
room's few copper tiles on −2, and −2's landing comes with a ladder. Timber exists only as the
ten a new game starts with. The support rule fails a room 19 wide on −1.

**What 012 adds:**
- **The Surface** (D-180): open grass and dirt, a rock mass ~20 tiles around the ramp and one
  rock quarter, a seeded winding road that runs through a cut in the rock to the ramp, the spawn
  at its far end.
- **Trees** (D-181): a fixture on the meadow, chopped with the axe only, for timber.
- **The axe and the kit** (D-182): axe, pick, shovel; no timber.
- **Below:** copper and tin veins on −2 only (D-183, D-187); at least two sealed natural caves on
  each of −1 and −2 (D-184).
- **No preloaded ladders** (D-185), and **R halved** (D-186).

## What should be true when you stop

By hand, unless marked:

1. A new game starts on a meadow at the end of a dirt road, with trees around. The road winds to
   a mass of rock and through a cleared cut in it to the ramp. One quarter of the Surface is rock.
2. The hotbar holds the axe, pick and shovel; the pack has no timber. Facing a tree with the axe,
   holding the action fells it in about 3 s for 4 timber. With the pick: "Chopping needs an axe."
3. A new world (a new seed) has a different road, rock quarter and trees.
4. Digging on −1 finds no ore but sooner or later breaks into a cave. On −2, copper and tin in
   small veins, and caves too. No ladder stands below the hole on −1.
5. A room 11 wide on −1 goes red in the middle; 9 wide stays amber at most.
6. *Automated:* the road reaches the ramp and is open all the way; the spawn is on the road; no
   tree on the road or in rock; trees on open grass only; −2's ore shares near the profile's
   numbers; −1 has no ore; at least two caves per level, sealed, not overlapping the fixed
   placements; caves never judged; the same seed builds the same world; a save from 011 still
   loads.

## Mode

**Agent**, for the whole slice (Derik, 2026-11-09), on a `slice-012` branch with commits per
section, the suite green before each; Derik merges the PR. Claude stops for anything new with
long-term consequences.

## What you're deciding

Every fork was settled on 2026-11-09 (D-179 to D-187). **Still yours, as part of approving this
brief: the numbers.** All of them go in the tuning profile.

| What | Proposed | Why |
|---|---|---|
| Rock around the ramp | a disc of radius 20 | D-180's "about 20" |
| Rock quarter | one of four, by seed, of the 90-radius Surface | D-180 |
| Road | 2 tiles wide, from ~70 tiles out, winding (a seeded walk that bends every 6–12 tiles) | Reads as a road, not a corridor |
| Dirt on the meadow | the road, plus scattered patches (~10% of the meadow) | "Dirt and grass" |
| Trees | ~4% of open grass, not within 2 of the road or the spawn | Plenty to chop, room to walk |
| Chopping | tree work 48 at axe power 16: **3 s** | A deliberate act, shorter than a breach |
| Timber per tree | **4** | One ladder per tree, two props |
| Axe | flint, power 16, 2.5 kg; digs rock ×0.25, dirt ×0.5, rubble ×0.5 | Fells trees; a poor digger |
| Copper share of −2's rock | 3% | Ore when you dig, not in every wall |
| Tin share of −2's rock | 2% | Rarer than copper |
| Ore on −1 | none | D-187 |
| Vein size | 3–8 tiles | D-183's small veins |
| Tin ore | 5 kg, value 6 (as copper; tuning appendix §1) | Placeholder value, like 008's |
| Caves per level | 2–3 of 5 hand-made shapes, ≥ 12 tiles from the fixed rooms and each other | D-184 |
| R by depth | 0, 4, 4, 3, 3, 2, 2, 2 | D-186 |

## Already settled

- **What each stratum holds** ([world-and-generation §2](../docs/world-and-generation.md), the
  tier spine): −1 has no metal ore; −2 is copper, tin and coal (D-187).
- **Levels are generated from recipes, deterministically from the world seed** (D-084, slice
  002's trap 8): the same seed, the same world.
- **Ramps come in pairs, both under open tops** (D-095); a hole with no ladder is legal (D-089).
- **Only what players dig is judged** (D-164); the Surface has no ceiling (010).
- **Fixtures go through the gatekeeper; yields overflow to the ground** (D-159, D-160).
- **Every number in the profile** (D-135); **format v1 edited in place** (D-133).

## Traps

### 1. The Surface is generated now, not stamped

Today the Surface is one prefab on solid rock. The meadow, rock, road, trees and spawn become
generation steps in a fixed order, each drawing from the level's one generator (D-084). A step
that draws a different number of values shifts every step after it, so a change to the road
changes the trees: tests pin rules, not tile-for-tile layouts.

### 2. The road must reach the ramp, open all the way

A seeded walk can wander off or double back. The road is built from waypoints toward the ramp
and checked: every road tile is open, the last one touches the ramp's tile, and the spawn is on
the first.

### 3. Trees are many fixtures

~4% of the meadow is several hundred trees, each a fixture with a sprite and an id. The fixture
renderer, the save and the blocked set all take them; the generator must not place one on the
road, in rock, on the spawn, or where the gatekeeper would refuse it.

### 4. Ore and caves after the fixed rooms

Caves are stamped before ore, away from the fixed placements, and sealed (a rock margin all
round). Veins go only into minable rock on −2, never into a room's open tiles. −1 gets caves and
nothing else (D-187), and slice 006's "Rootshelf has no copper" test stays.

### 5. Saves from 011

An 011 save holds its levels whole, so it loads as it was: no trees, the old Surface. Only new
worlds get the new generation. A level generated later (−2 on first descent, D-143) uses the new
rules in an old world, which is fine.

### 6. Tests built on the hand-made levels

The climbing tests use −2's ladder; the support tests and others assume R = 8; tests assume ten
starting timber and the pick in slot 1. Each changes with its decision, and says which.

## Carried into this slice

- **By-hand walks of 008 to 011,** not reported item by item.
- **Deferred:** regrowing trees, coal and iron, −1's own resources (clay, flint, root fibre,
  fungus), caves below −2, crafting, the rate machine.
