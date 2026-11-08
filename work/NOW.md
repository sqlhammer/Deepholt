# Slice 009 — Letting go

> Dig until your pack is full and the stone you can't carry falls at your feet. Walk past it
> later with room to spare and it comes back into your pack. Open the inventory, drop the stone
> you don't want, and take the ore you do, even past full, if you're willing to walk home slowly.

*Proposed by Claude, 2026-11-08, for Derik's approval. Scope set in planning
([D-160](../docs/design-decisions.md#d-160--slice-009-is-letting-go-drops-dropping-pickup-to-100-a-take-key-an-inventory-overlay)
to D-162). Agent mode on a `slice-009` branch. Nothing is built until Derik approves this brief.*

## Where we are

Slice 008 is merged ([log](./log/008-what-you-carry.md)), **not yet walked by hand.** Every actor
carries a saved `Pack`; digging yields into the digger's pack with no cap; the load curve slows
walking and past 150% a ladder refuses; ladders cost four timber. Nothing can leave a pack except
a ladder's cost.

**What 009 changes:**
- **Drops** exist: item stacks lying on tiles, a saved per-level store, like fixtures.
- **Yields fill the pack to 100%,** and the rest drops at the dug tile (amends D-158's no cap).
- **Auto-pickup:** a player takes drops from its own and the eight adjacent tiles, up to 100%.
- **A take key** takes everything in that reach, whatever the load: the deliberate way past
  100%.
- **An inventory overlay** lists the pack, sorted by value density, with each item's weight, and
  drops one or a stack onto your tile.

## What should be true when you stop

By hand, unless marked:

1. Dig with a full pack: the stone appears on the dug tile instead of in your pack.
2. Walk up to a drop with room in your pack: it comes in, up to 100%, and the rest stays.
3. Press the take key beside a drop: you take all of it, past 100%, and slow down accordingly.
4. Open the inventory: your items, heaviest value per kilo first, each with its weight. Drop one
   stone, then a whole stack: they appear on your tile, and the HUD's weight falls.
5. In the dark, a drop shows only where you can sense it or it's lit.
6. Save and relaunch: the drops are where you left them.
7. *Automated:* drops, pickup and the take key go through the world, for any player, and an
   NPC never picks up (pillar [P5](../docs/game-overview.md)).
8. *Automated:* a yield that only partly fits is split: what fits goes in, the rest drops.

## Mode

**Agent**, for the whole slice (Derik, 2026-11-08), on a `slice-009` branch with small commits,
one or more per section, the suite green before each; Derik merges the PR. Every fork was settled
in planning; Claude stops for anything new with long-term consequences.

## What you're deciding

Every fork was settled in planning on 2026-11-08. The list stays as the record:

- **The scope**, and **fill to 100%, ladders past 150%** (D-160): digging and auto-pickup stop at
  100%; only the take key goes beyond, so the slow band and the ladder rule are reached on
  purpose.
- **Drops through the world, per level, saved, never decaying**
  ([D-161](../docs/design-decisions.md#d-161--drops-change-through-the-world-and-are-drawn-like-actors)).
- **Drops drawn like actors in the dark:** Sensed or Lit only (D-161).
- **The inventory is an overlay; nothing pauses**
  ([D-162](../docs/design-decisions.md#d-162--the-inventory-is-an-overlay-nothing-pauses)).

**Proposed bindings, checked against `project.godot`** (part of approving this brief):

| Action | Keyboard | Pad | Note |
|---|---|---|---|
| Open / close the inventory | `Tab` | Menu (Start) | As ui-ux §4 has them |
| Pick an item in it | ↑ / ↓ | D-pad ↑ / ↓ | The existing `ui_up` / `ui_down` |
| Drop one | `X` | A | A is interact; it drops while the inventory is open |
| Drop the stack | `Z` | X | X is breach; breaching is off while it's open |
| Take everything in reach | `T` | LB | ui-ux reserves LB for the hotbar, which doesn't exist yet; the hotbar's slice decides between them, as D-155 did for X |

## Already settled

- **Weight-limited, no teleport; overweight is a slowdown, not a block**
  ([D-013](../docs/design-decisions.md#d-013--inventory-is-weight-limited-there-is-no-teleport),
  [ui-ux §5](../docs/ui-ux-and-controls.md)).
- **Above 150%, no ladders** ([D-030](../docs/design-decisions.md#d-030--stamina-exists-for-combat-only-the-load-curve-carries-weight),
  D-159).
- **The inventory's job is deciding what to leave behind:** per-item weight always visible, sort
  by value density, a take-this preview (ui-ux §5).
- **Items are `.tres` with stable ids; packs are saved per actor, unknown items kept and
  reported** ([D-157](../docs/design-decisions.md#d-157--items-are-schema-resources-with-a-registry-each-actor-carries-a-saved-pack)).
- **World state changes through the world's gatekeepers** (D-078, D-125).
- **In the dark, entities show only on Sensed or Lit tiles** (D-148).
- **Format v1 is edited in place** (D-133).

## Traps

### 1. Every limit on the pack has to agree

Yields fill to 100%, auto-pickup to 100%, the take key ignores it, and the ladder stops past 150%.
One rule (`Carrying`, from the profile) should answer "how much of this fits", so the dig, the
pickup and the HUD can't disagree.

### 2. Auto-pickup runs every step

A player checks nine tiles of drops every tile step. That's cheap only if a level's drops are
filed by tile, as fixtures are, not scanned whole.

### 3. Drop and pick up in the same frame

Drop a stone on your own tile, and auto-pickup takes it straight back, since it's in reach and
fits. A dropped stack has to stay down until the player steps off and back, or never be
auto-picked by the one who dropped it, until they move.

### 4. A load needs drops before actors

A drop under a loaded player could be picked up while the load is still building. The load
must restore drops without anyone picking them up, as D-143 kept generation out of loads.

### 5. Drops on a level that doesn't exist

A yield drops on the dug tile, always on an existing level. A drop's save entry names its tile,
and a load reports a drop outside its level or with an unknown item, never silently drops it.

### 6. The new bindings meet old ones

`X` / pad A and `Z` / pad X only mean drop while the inventory is open, and must not also
interact or breach. Test each in both states.

## Carried into this slice

- **008's by-hand walk**, not yet done.
- **The "dragon bag" yield randomizer** (D-156) stays deferred.
- **A `Worlds.with_levels` that adds a blank level below** (008's log) is worth doing if a test
  here needs it.
