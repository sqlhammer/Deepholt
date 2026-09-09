# Deepholt — Game Overview

> Status: **pre-production**. Title: **Deepholt** ([D-027](./design-decisions.md)); the
> repository remains `Molepeople`. This document is the top of the design tree;
> everything else in [`/docs`](./) elaborates on a pillar established here.

---

## 1. One-line pitch

A survival-crafting game about digging a home *down* through a mountain — where the dark is
safe, the sun is a hazard, and every level you excavate has to be held up, supplied, and
connected to the ones above it.

## 2. The elevator pitch

You are a moleperson living one level beneath the summit of a mountain, with a single cave
mouth opening onto a surface you were not built for. Below you is the rest of the mountain:
strata of rock, root, ore, water and older things, each level wider than the last as the
cone opens toward its base.

You dig down. You haul what you find back up. You shore up what you've hollowed out so it
doesn't come down on your head. And slowly the tunnels stop being a mine and start being a
*warren* — halls, farms, workshops, and eventually neighbours.

## 3. Core fantasy

**"I made this mountain livable."**

Not conquest, not escape — *tenancy*. The satisfying moment is not killing the thing at the
bottom; it's standing in a lift shaft that runs eight levels, watching ore you didn't have to
carry come up past you, in a hall you had to design supports for.

Three feelings, in priority order:

1. **Excavation as authorship.** The world is not a level you traverse; it is material you
   remove. What's left behind is the building.
2. **Verticality as logistics.** Depth is not just difficulty. Depth is *distance from home*,
   measured in lifts, shafts, and the problem of getting a ton of rock uphill.
3. **The dark as home.** Every survival game teaches you to fear the dark. This one teaches
   you to fear the doorway.

## 4. Design pillars

These are load-bearing. A feature that contradicts a pillar is cut or the pillar changes —
no quiet exceptions.

### P1 — Stacked levels, top-down
The world is a stack of discrete top-down maps in Core Keeper's visual idiom. You occupy one
level at a time; ladders, stairs, shafts, chutes and lifts connect them. Vertical *logistics*
— moving goods, people, light and power between levels — is the game's signature system, and
gets first-class design attention, not the treatment of a fast-travel convenience.

### P2 — The mountain is a cone
Each level down is meaningfully **wider** than the one above. Level −1 is a pocket you can
fully know. Level −6 is a region. This delivers difficulty pacing, scope pacing, and a
built-in motive to descend ("we are out of room") without any artificial gate. Below the
mountain's footprint the widening stops — and the tone changes with it.

### P3 — Sunlight is the hazard
Direct sun applies a stacking debuff to molepeople. The surface is a **raid target**, not a
safe zone: you go at night, at dawn, or under gear and infrastructure you built for the
purpose. This inverts the genre's default light rule and is the single strongest expression
of "you are not human."

### P4 — Excavated space must be held up
Digging has a structural cost. Unsupported spans sag, then fail. Columns, beams, arches and
braced walls are the difference between a mine and architecture, and a great hall is an
engineering achievement rather than a large delete operation. (Forgiving in pre-alpha,
sharpened later.)

### P5 — Solo-complete, co-op-shaped
The pre-alpha and the shipped game are fully satisfying alone. But world state, base
ownership, save structure and the later moleperson-worker system are specified so that
drop-in co-op can be added **without a rewrite**. No system may assume exactly one actor.

## 5. Reference points, and what we take from each

| Reference | What we take | What we explicitly do **not** take |
|---|---|---|
| **Core Keeper** | Art idiom, top-down feel, mining-as-verb, crafting cadence, co-op sensibility, readable pixel lighting | Single infinite plane; darkness-as-threat; unbounded free excavation |
| **Romestead** | Built architecture that reads as *civilisation*, settlement/production sim texture, structured farming | Its surface-agrarian framing and camera |
| **Dwarf Fortress** (structural, not tonal) | Z-levels, supports and collapse, vertical hauling as a real problem | Its complexity, opacity, and UI philosophy |
| **Palworld** (deferred) | Assign-a-creature-to-a-station automation model, for the later moleperson-worker layer | Everything else |

## 6. Genre, camera, platform

- **Genre:** survival / crafting / base-building, with light action combat and a settlement layer arriving mid-development.
- **Camera:** top-down, one level rendered at a time. Open shafts and pits give a dimmed hint of the level below (see [world-and-generation.md](./world-and-generation.md)).
- **Art:** 2D pixel art in Core Keeper's register — high-contrast readable tiles, dynamic light as a primary visual, warm interiors against cold stone.
- **Engine:** Godot 4 ([`/game`](../game/)).
- **Session shape:** 30–90 minute sessions. Long-lived persistent world.

## 7. World structure at a glance

```
            .-'''''-.            SURFACE  — hostile daylight, timed excursions,
          .'  ~~~~~  '.                     wood/grain/sky resources, outsider NPCs
         /   cave mouth \
        |==== LEVEL -1 ===|      Home stratum. Small, safe, fully knowable.
       |===== LEVEL -2 =====|    First real dig. Structure & light pressure begin.
      |====== LEVEL -3 ======|
     |======= LEVEL -4 =======|  The cone opens. Regions, not rooms.
    |======== LEVEL -5 ========|
   |========= LEVEL -6 =========|
   |         ...  BASE  ...      |  Widening stops beneath the mountain's footprint.
        \____ THE DEEP ____/         The Deep Warren — molepeople cut off for generations.
              WARREN                 Reconnection, not conquest. (story-and-setting.md)
```

## 8. What this game is not

- Not a roguelike. The world persists; death is a setback, not a reset.
- Not a combat game with building attached. Combat serves excavation and defence.
- Not an open-world sandbox with no shape. The mountain has a top, a bottom, and a middle.
- Not a colony sim you watch. You are a moleperson with a shovel, first and always. Workers
  arrive to remove tedium, never to remove the player from the loop.

---

## Related documents

| Document | Covers |
|---|---|
| [world-and-generation.md](./world-and-generation.md) | The cone, strata, region gating, procgen pipeline, water |
| [story-and-setting.md](./story-and-setting.md) | Premise, the three-act disaster, the Deep Warren, tone |
| [core-loops.md](./core-loops.md) | Moment, expedition, session, progression and meta loops; pressure map |
| [systems/digging-and-structure.md](./systems/digging-and-structure.md) | Dig verbs, the support rule, collapse, the overlay |
| [systems/vertical-logistics-and-power.md](./systems/vertical-logistics-and-power.md) | The transport ladder, wind power, driveshafts, brownouts |
| [systems/light-and-sunlight.md](./systems/light-and-sunlight.md) | Dark vision, exposure, shade routing, lamps and fuel |
| [systems/base-building.md](./systems/base-building.md) | Build vocabulary, rooms and comfort, multi-level base design |
| [systems/crafting-and-progression.md](./systems/crafting-and-progression.md) | Materials vs techniques, the tier spine, stations, tools |
| [systems/survival-and-farming.md](./systems/survival-and-farming.md) | Hunger, cooking buffs, the two agricultures |
| [systems/combat-and-fauna.md](./systems/combat-and-fauna.md) | Combat verbs, fauna by stratum, guardians, death |
| [ui-ux-and-controls.md](./ui-ux-and-controls.md) | Gamepad-first control scheme, HUD, build mode, the multi-level map |
| [npcs-and-village.md](./npcs-and-village.md) | Traders, wanderers, outsiders, the deferred worker layer |
| [pre-alpha-scope.md](./pre-alpha-scope.md) | The thesis, in/out lists, first session, success criteria, milestones |
| [tech/world-runtime-and-persistence.md](./tech/world-runtime-and-persistence.md) | World representation, off-level simulation, entities, save format |
| [tech/art-and-camera.md](./tech/art-and-camera.md) | Tunnel memory, camera constants, lighting and shade pipelines |
| [tech/content-schema.md](./tech/content-schema.md) | Resource types, the TuningProfile, the content validator |
| [tuning-appendix.md](./tuning-appendix.md) | First-pass numbers, derived from stated feel targets |
| [design-decisions.md](./design-decisions.md) | Numbered decision log with rationale |
