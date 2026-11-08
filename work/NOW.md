# Slice 008 — What you carry

> Dig a tunnel and your pack fills: a stone from every wall, copper from every vein. Fill it and
> you feel it in your legs, and above half again over the limit, the ladder home won't take
> you. You start with ten timber, and every ladder you place costs four.

*Proposed by Claude, 2026-11-08, for Derik's approval. Scope set in planning
([D-156](../docs/design-decisions.md#d-156--slice-008-is-the-pack-yields-weight-the-load-curve-and-a-timber-cost)):
yields, a weight-limited pack, the load curve, the carry HUD, and a timber cost for ladders,
with no dropping or inventory screen. Agent mode on a `slice-008` branch. Nothing is built until
Derik approves this brief.*

## Where we are

Slice 007 is done and merged ([log](./log/007-dig-your-own-way-down.md)): a player can breach a
floor, place a ladder in build mode, and climb down. Digging a wall leaves nothing behind but
the open tile, and nothing in the game is an item.

**What exists to build on:**
- **The dig** goes through the world's tile gatekeeper: `dig_requested` → `tile_dug(actor,
  tile)`. The world knows who dug what, before the tile changes.
- **The tuning profile** holds every number, and `Digging` holds the digging rules (D-150).
- **Placement** goes through the world's fixture gatekeeper, and build mode's preview asks the
  same rule (D-154). A cost is one more rule in both.
- **An actor's save entry** holds its id, kind, name, depth, tile and facing (D-114). A pack
  would be one more field, editing format v1 in place (D-133).
- **Walk speed** comes from the profile through `Actor.speed` (D-135). Ladders are instant
  (D-108; the fade is presentation, D-142), so the appendix's climb-time multipliers have
  nothing to slow yet. Only the 150% rule applies to climbing.

**The numbers** ([tuning appendix §2–3](../docs/tuning-appendix.md)): a 60 kg pack; stone 3 kg,
copper ore 5 kg, timber 2 kg; walking 5.0 tiles/s up to 50% load, falling to 4.2 at 80%, 3.6 at
100%, 2.2 at 150%, and 1.6 beyond, where ladders are impossible.

## What should be true when you stop

By hand, unless marked:

1. `--new-game`: the HUD shows your carry weight, 20 of 60 kg, the ten timber you start with.
2. Dig a rock wall: the weight rises by 3 kg; a dirt wall adds nothing. Dig a copper vein (on −2, by Greyseam's brazier): it
   rises by 10 to 20 kg.
3. Past half full you walk slower, and slower again near and past full. At over 150%, interact
   on a ladder refuses, and says why.
4. Place a ladder: the preview shows its cost of 4 timber, and placing takes it. With fewer than
   4 left, the preview and the placement refuse, and say why.
5. Save and relaunch: the pack is as you left it.
6. *Automated:* yields, costs and the load curve are each player's own, never "the" player's, and
   an NPC's dig yields into its own pack (pillar [P5](../docs/game-overview.md)).
7. *Automated:* a dig with no actor (a test, or later a collapse) yields nothing and errors
   nothing.

## Mode

**Agent**, for the whole slice (Derik, 2026-11-08), on a `slice-008` branch with small commits,
one or more per section, the suite green before each; Derik merges the PR. Claude stops for
every design fork below, one at a time, and for anything else with long-term consequences.

## What you're deciding

Every fork was settled in planning on 2026-11-08, as D-157 to D-159. The list stays as the
record of what was weighed:

- **Items:** the full content-schema `Item` resource, one `.tres` each in `content/items/`, and
  an `ItemRegistry`
  ([D-157](../docs/design-decisions.md#d-157--items-are-schema-resources-with-a-registry-each-actor-carries-a-saved-pack)).
- **The pack:** on every actor, saved in its entry as item id → count; an older save loads an
  empty pack (D-157).
- **Yields:** the world puts them in the digger's pack, uncapped. Rock gives 1 stone, dirt
  nothing, ore veins 2–4 ore. The model ahead, not built in 008, is drops on the ground for
  what doesn't fit, picked up automatically from adjacent tiles up to 150%
  ([D-158](../docs/design-decisions.md#d-158--yields-go-into-the-diggers-pack-uncapped-drops-come-later)).
- **The cost:** one rule, used by the fixture gatekeeper and the preview; placing with no actor
  is free
  ([D-159](../docs/design-decisions.md#d-159--the-cost-is-the-gatekeepers-the-hud-bar-sits-bottom-center-the-ladder-rule-checks-load)).
- **The HUD:** a slim bar at the bottom center with "20 / 60 kg", marking the bands (D-159).
- **The 150% rule:** in `Ladder.target_for`, shown by `RefusalNotice` (D-159).

## Already settled

- **Weight-limited, no teleport**
  ([D-013](../docs/design-decisions.md#d-013--inventory-is-weight-limited-there-is-no-teleport)).
  The answer to tedium is cheaper logistics, never a bigger pack.
- **The load curve carries the whole feeling of weight, and above 150% you can't climb a
  ladder**
  ([D-030](../docs/design-decisions.md#d-030--stamina-exists-for-combat-only-the-load-curve-carries-weight)).
- **Overweight is a slowdown, not a block** ([ui-ux §5](../docs/ui-ux-and-controls.md)).
- **Items are `.tres` resources with stable `snake_case` ids, never reused or renamed**
  ([content-schema §1, §3](../docs/tech/content-schema.md)). Saves reference them.
- **Every number lives in the profile; the rules live beside what they're about**
  ([D-135](../docs/design-decisions.md#d-135--the-world-holds-its-tuning-profile-every-number-in-code-moves-into-it),
  [D-150](../docs/design-decisions.md#d-150--digging-rules-live-in-a-static-digging-class-that-takes-the-profile)).
- **Tiles and fixtures change only through the world's gatekeepers** (D-078, D-125).
- **Format v1 is edited in place** until the first playtest
  ([D-133](../docs/design-decisions.md#d-133--save-format-version-1-is-settled-when-the-first-build-goes-to-someone-else)).
- **The scope** ([D-156](../docs/design-decisions.md#d-156--slice-008-is-the-pack-yields-weight-the-load-curve-and-a-timber-cost)):
  1 stone per wall, 2–4 ore per vein, 10 starting timber, 4 per ladder; no shedding in 008.

## Traps

### 1. A pack nobody can empty

Without dropping or discarding, a full pack stays full, and with no cap (D-158) it keeps
filling. A player at 151% can't climb home. This is accepted for 008 (restart); shedding, and
drops for what doesn't fit, come later. Don't let a test or the by-hand walk
treat it as a bug, and don't quietly add a way out.

### 2. "The player's" pack

The pack belongs to whichever actor dug. A yield routed to the local player, the followed actor,
or the first player in the world would break with a second player or an NPC digging (P5). The
dig's request already names its actor: use that one.

### 3. Speed is read every physics tick

`Actor.speed` is read every tick for every actor. A load curve that sums the pack each time is a
loop per actor per tick. Keep the pack's total weight as a number that changes when the pack
changes.

### 4. A cost checked in two places can disagree

The preview and the gatekeeper must use one rule for "can this actor afford it", or the cursor
shows green and the placement refuses. Same lesson as 007's placement preview.

### 5. Saving a pack is saving ids

A pack saved as item ids must load against the items this build has. An unknown id (a renamed
item, an edited file) is reported like an unknown fixture kind (D-113), never silently dropped
or turned into nothing.

### 6. The new game's timber

The ten starting timber belong to a *new* player, not to every spawn, and not to a loaded one. A
load restores the saved pack; only a new game's first player gets the starting stack.

## Carried into this slice

- **007's by-hand outcomes** weren't reported walked.
- **Shedding weight** (drop or discard) is the next slice's, by Derik's choice (D-156).
- **The "dragon bag" yield randomizer** is deferred (D-156) until stone's volume needs managing.
