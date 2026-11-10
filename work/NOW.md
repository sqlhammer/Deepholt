# Slice 011 — Tools in hand

> Press 2 and the pick in your hands becomes a shovel: dirt flies, rock barely scratches. Open
> the pack with the pad alone, move the shovel to slot 5, see what the stone at your feet would
> weigh before you take it. Drop your pick, and you're digging with your hands.

*Proposed by Claude, 2026-11-09, for Derik's approval. Scope and every fork settled in planning
([D-167](../docs/design-decisions.md#d-167--pad-a-takes-from-the-ground-when-theres-nothing-to-interact-with)
to D-174). Agent mode on a `slice-011` branch. **Approved by Derik the same day, with the numbers
and bindings below as proposed** (the pick at 0.8 s on rubble, the wheel included). **Built, 1008 tests green; waiting on the
by-hand walk** ([log](./log/011-tools-in-hand.md)). One binding changed while building: the
inventory's sections switch with the arrow keys and D-pad ←/→, not Tab and LB/RB, because Tab
closes the inventory; the log says why.*

## Where we are

Slice 010 is merged ([log](./log/010-holding-it-up.md)); **no by-hand walk of 008, 009 or 010 has
been reported.** A player carries a weighted pack, drops and takes, builds ladders and props, and
digs with one fixed tool, a flint pick (`Actor.equipped`, D-077). Build mode picks its item with
`1` / `2` and pad RB; the inventory (Tab / Start) is a minimal list.

**What 011 adds:**
- **Tools are pack items** with a weight; only the player drops one, never an overflow (D-169).
- **A shovel** beside the pick, and **bare hands** for an empty slot (D-171). Speed is power times
  a multiplier for the tool's class and the tile's kind (D-168). **Only a selected pick breaches**
  (D-174).
- **One eight-slot hotbar** at the bottom center: tools outside build mode, buildables inside it
  (D-170). `1`–`8`, a click, the mouse wheel, pad LB/RB.
- **An inventory screen** with a focus highlight for the pad and keys, assigning to slots, a weight
  bar, every row's weight, and the take-this preview (D-172).
- **Pad A takes** when there's nothing to interact with (D-167); LB/RB go to the hotbar.

## What should be true when you stop

By hand, unless marked:

1. A new game shows the hotbar with the pick in 1 and the shovel in 2. `2` (or a click on slot 2,
   or the wheel, or pad RB) selects the shovel: dirt digs about twice as fast, rock much slower.
2. With the shovel selected, `R` / pad X refuses: "Breaching needs a pick." Select the pick and
   it breaches.
3. Press `B`: the bar shows ladder and prop, selected the same way. Press `B` again: the tools
   come back, with the same one selected.
4. Open the inventory with the pad alone: the D-pad moves a highlight; every row shows its weight;
   a weight bar heads the screen. Move the shovel to slot 5, and the ladder to build slot 3.
5. Stand on drops: the inventory's preview shows the load after taking them. Pad A (away from a
   ladder) takes them, with a notice saying so.
6. Drop the pick from the inventory: its slot empties, and digging with it selected is bare hands
   (slow, no breach). Walk back over it: it returns to the first empty slot.
7. Fill the pack past full with stone: the overflow drops stone, never a tool.
8. Save and relaunch: the slots, the selection and the build slots are kept.
9. *Automated:* the multiplier table for every class and kind; an NPC digs with its own selected
   tool (no player singleton, D-045); an old save with no hotbar loads with the starting layout.

## Mode

**Agent**, for the whole slice (Derik, 2026-11-09), on a `slice-011` branch with small commits,
**one or more per section** (010's log: stage by section, even when files overlap), the suite
green before each; Derik merges the PR. Claude stops for anything new with long-term consequences.

## What you're deciding

Every fork was settled on 2026-11-09 (D-167 to D-174). **The numbers and the bindings below were
approved with the brief,** each put to Derik as its own question.

**Proposed numbers** (all in the profile, D-135):

| | Rock | Dirt | Rubble | Notes |
|---|---|---|---|---|
| Pick, power 16 | ×1 (0.375 s) | ×1 (0.25 s) | **×0.5 (0.8 s)** | Today's speeds, except rubble |
| Shovel, power 16 | ×0.4 (0.94 s) | ×2 (0.125 s) | ×1 (0.4 s) | Can't breach |
| Bare hands, power 8 | ×1 (0.75 s) | ×1 (0.5 s) | ×1 (0.8 s) | Can't breach |

Ore takes 1.5× its rock's time, as today. **Rubble gets slower with the pick** (0.4 s today, set
in 010): the tuning appendix says 0.4 s *with a shovel*, so the shovel takes that number and the
pick earns its "wrong tool" penalty. Say if you'd rather keep the pick at 0.4 s.

Weights: **pick 3 kg, shovel 2.5 kg** (5.5 of the 60 kg pack). Trade value 1 each, a placeholder
like 008's.

**Proposed bindings, checked against `project.godot`:**

| Action | Keyboard / mouse | Pad | Note |
|---|---|---|---|
| Select slot | `1`–`8`, click a slot, wheel | LB / RB (previous / next) | Replaces 010's build-item keys and RB |
| Take | `T` (stays) | **A**, when nothing to interact with | Moves off LB (D-167) |
| Breach | `R` | X | Settled for good (D-171) |
| Inventory focus | arrow keys, hover | D-pad | |
| Assign focused item to a slot | `1`–`8` while focused | Y, then LB / RB to choose, A to confirm, B to cancel | Y is build mode outside the inventory; inside it's free |
| Drop one / drop stack | `X` / `Z` (stay) | A / X (stay) | Inside the inventory, A drops; outside, A interacts or takes |
| Build-slot section | Tab between "Tools" and "Build" in the inventory | LB / RB switch section while not assigning | Where build slots are rearranged (D-174) |

## Already settled

- **The weight pillar:** a weight bar, every item's weight visible, sort by value per kilo, the
  preview ([ui-ux §5](../docs/ui-ux-and-controls.md), [D-013](../docs/design-decisions.md)).
- **Tool classes and power** ([content-schema](../docs/tech/content-schema.md),
  [tuning appendix](../docs/tuning-appendix.md), D-081's bare hands at 8).
- **The pick is the one hard gate on descent** ([crafting-and-progression §4](../docs/systems/crafting-and-progression.md)).
- **Mouse parity:** no reach, precision or information the pad lacks (ui-ux §3).
- **No player singleton** (D-045): the hotbar belongs to an actor.
- **Every number in the profile** (D-135); **format v1 edited in place** (D-133).

## Traps

### 1. `Actor.equipped` is read in many places

Dig, breach, the action signals and the save all read one preloaded `ToolData`. Replacing it with
"the selected slot's tool, or bare hands" has to reach every reader at once, and the tests that
assume a flint pick have to say which tool they hold. A grep for `equipped` is the checklist.

### 2. `ToolData` and `Item` are two resources today

A tool must be an item (weight, stack, registry) *and* have a class and power. Either `Item`
grows tool fields or a tool item points at its tool data. One owner, not a copy of power in two
places.

### 3. Overflow must never take a tool

009's yield path drops what doesn't fit. Tools never arrive as yields today, but a picked-up
tool that doesn't fit (take past 100%) is the same path. The rule belongs in one place.

### 4. A hotbar slot points at an item, and items move

Dropping the selected tool empties its slot; taking it back puts it in the first empty slot, not
necessarily its old one (D-171). A slot must never point at an item the pack no longer has, and
two identical tools must each have a slot.

### 5. Pad A now does two things

Outside the inventory A interacts, then takes; inside it, it drops one. The input handler's order
decides which, and a wrong order (take before a ladder) changes how climbing feels. The notice
says which happened.

### 6. Old saves

A save from 010 has an equipped path and no hotbar. It loads with the starting layout (pick in 1,
shovel in 2, and the tools added to the pack), and the problems list says so.

### 7. Two meanings of a slot key

`1`–`8` select a slot, but inside the inventory they assign the focused item. The handler must
check the inventory first, or pressing 3 to assign also switches tools.

## Carried into this slice

- **008's, 009's and 010's by-hand walks**, not reported.
- **010's open numbers:** "18 wide goes red" is 19 under the rule; countdowns tick only on levels
  a player is on.
- **Deferred:** the radial menu, the hammer, the lantern, tiers, crafting, durability, blueprints.
