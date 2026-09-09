# Light & Sunlight

Two separate systems that share a visual language and pull in opposite directions:

| | **Exposure** (surface) | **Illumination** (underground) |
|---|---|---|
| Light is | a hazard to route around | a capability to spend on |
| Player goal | minimise | maximise, affordably |
| Failure | damage and blindness | inefficiency, not death |
| Pillar | P3 | P1, P4 |

The unifying idea: **a moleperson's relationship to light is always a routing problem.**
Below, you carve routes through solid rock. Above, you route through solid daylight.

---

## 1. Dark vision — the baseline

> Status: proposed, see [D-010](../design-decisions.md).

Molepeople see in the dark. Unlit space is rendered in **desaturated, low-detail monochrome**
at a radius of ~7 tiles. It is fully navigable. You will never die because you forgot a torch.

What darkness costs you:

- **Ore cannot be identified.** Every metal vein reads as the same grey lump. You cannot tell
  copper from tin from something rarer without light on the tile. *This is the load-bearing
  reason to carry light while mining.*
- **Fine detail is invisible.** Item quality, small hazards, tracks, inscriptions.
- **Crafting stations run at reduced speed** below a minimum tile light level, and some
  refuse to operate at all.
- **It doesn't feel like yours.** Colour and warmth are how the game says *this is your
  warren*. The grey is how it says *this is still the mountain's*.

Design intent: light is never a survival timer, so it never becomes a frustration. It is
*civilisation* — continuously desirable, never mandatory. This is the second inversion of
Core Keeper (there, light is required; here, light is what you build once you're safe).

---

## 2. Exposure — the surface system

Modelled on V Rising: direct sun is lethal over time, shade is safety, and because the sun
**moves**, safety moves with it. Surface travel is a route you solve, not a timer you beat.

### 2.1 The meter

`Exposure`, 0–100. Fills in sun, drains in shade. Drains fast underground/indoors.

| Band | State | Effect |
|---|---|---|
| 0–49 | **Squinting** | Screen desaturates and blooms. Cosmetic warning only. |
| 50–84 | **Searing** | Vision radius shrinks from glare. Ranged accuracy penalty. |
| 85–99 | **Blistering** | Light damage over time begins. Audio muffles. |
| 100 | **Sunstruck** | Heavy damage over time, near-total whiteout. You will die in the open. |

Asymmetric rates — *getting into shade is relief, not a reset*:

- Fill (bare, high sun): 0 → 100 in **~45s**
- Drain (full shade): 100 → 0 in **~90s**
- Drain (underground/roofed interior): 100 → 0 in **~15s**

### 2.2 Shade tiers

Every surface tile resolves to one of three shade states each frame:

- **Direct** — 100% fill rate.
- **Dappled** — 25% fill rate. Sparse canopy, collapsed roofs, lattice, ruin colonnades.
- **Occluded** — 0% fill, drain applies. Solid roof, dense canopy, cliff or wall shadow,
  the mountain's own shadow.

### 2.3 The sun moves — and this is the whole mechanic

Sun azimuth advances across the day, so cast shadows sweep and change length.

```
 DAWN  (long shadows, west)   NOON (short shadows)     DUSK (long shadows, east)
        \                            |                          /
     ####\                         ####                     /####
     #### \______                  ####|                ___/ ####
     ruin   shadow                 ruin                shadow  ruin
     <- safe corridor ->            <- barely anything ->   <- safe corridor ->
```

Consequences that come free with this:

- The same route is a different puzzle at 08:00 and at 15:00. A wall that shelters you on
  the way out does not shelter you on the way back.
- **Low sun is weak sun.** Dawn and dusk apply ~40% fill rate *and* cast the longest shadows.
  These two-minute bands are the golden hours, and expedition planning is built around them.
- **The mountain shades itself.** Its own shadow is enormous at low sun. The east face is
  sheltered in the evening; the west face in the morning. Therefore **which cave mouth you
  leave from is a strategic choice** — and this costs us nothing to implement.
- Weather is a global multiplier: overcast ×0.5, rain ×0.3, storm ×0.1. A storm is an
  opportunity, and the player will learn to drop everything and run for the surface.

### 2.4 Counterplay ladder — the surface progression curve

Surface access improves through **infrastructure and preparation**, not stats. This is the
above-ground mirror of tunnelling, and it is the intended shape of surface progression.

| Tier | Unlock | What it changes |
|---|---|---|
| 0 | *(start)* | Night trips only. Dawn/dusk dashes within sight of the cave mouth. |
| 1 | **Ash paste** (consumable) | −30% fill for ~3 min. One errand deeper than you could manage. |
| 2 | **Shade posts & awnings** (built) | Player-placed Occluded tiles. The first *road*. |
| 3 | **Woven cloak** (gear) | −35% fill, permanent. |
| 4 | **Smoked lenses** (gear) | Removes the vision penalties, not the damage. Legibility, not safety. |
| 5 | **Planted saplings** | Mature into canopy over in-game weeks. Long-horizon investment; a forest you grew becomes permanent road. |
| 6 | **Deep-stratum weave** | Near-immunity for a limited duration. Noon is finally yours — briefly. |

The target arc: *"I can't go out"* → *"I can go out at dawn"* → *"I built a road"* →
*"I have a network"* → *"I go where I like."* At no point does the player simply out-stat
the sun.

---

## 3. Illumination — the underground system

### 3.1 Portable light

| Source | Cost | Notes |
|---|---|---|
| **Torch** | Cheap, burns ~4 min | Droppable as a breadcrumb trail. The early-game answer. |
| **Oil lantern** | Refillable, fuel is a managed resource | The mid-game answer. This is the "light" survival pressure of [D-006](../design-decisions.md). |
| **Everburn crystal** | Deep-stratum find, no fuel | Retires the fuel meter permanently. |

Deliberate: one of the three survival pressures is **designed to be solved and removed**.
Reaching the crystal is a milestone the player feels as *relief*, and it rewards the descent
with quality of life rather than a bigger number.

### 3.2 Fixed light

Installed lights (braziers, wall lamps, later a powered lattice) are what convert a tunnel
into a *place*. They:

- restore colour and detail permanently in a radius,
- allow ore identification and full-speed crafting,
- **repel certain deep fauna**, making lighting a form of defence — lit corridors are safe
  corridors, which makes light infrastructure and tunnel infrastructure the same investment,
- let surface crops be farmed underground (see the survival/farming doc).

Some deep fungi require *darkness*, so a fully-lit warren is not optimal. There should
always be a room you deliberately leave dark.

---

## 4. Pre-alpha subset

Build only this for the first internal build:

- [ ] Dark vision: monochrome/low-detail render outside light radius
- [ ] Torch + oil lantern, with fuel
- [ ] Fixed brazier, radius light
- [ ] Ore-identification gated on tile light level
- [ ] Exposure meter with all four bands
- [ ] Three shade tiers as a per-tile flag
- [ ] Moving sun azimuth with cast shadows from walls, ruins, canopy and the mountain
- [ ] Dawn/dusk low-sun rate reduction
- [ ] Ash paste, shade posts/awnings (tiers 1–2 only)

Cut from pre-alpha: weather multipliers, cloak/lenses, saplings, deep-stratum weave,
everburn crystal, light-based fauna repulsion.
