# Tuning Appendix — First-Pass Numbers

Every value here is **derived from a stated feel target**, not chosen. Where a number is
arbitrary, it says so. Where it is load-bearing, it says that too.

> **How to use this document:** when something feels wrong in playtest, find the feel target it
> came from in §1, change *that*, and let the numbers fall out again. Do not tune leaf values in
> isolation — that is how a coherent system becomes a pile of magic constants.

---

## 1. The anchors

Two targets. Everything else is downstream.

### A1 — One in-game day = 24 real minutes
1 game hour = 1 real minute. Sunrise 06:00, sunset 18:00.

| Band | Game time | Real time |
|---|---|---|
| Night | 19:00–05:00 | 10 min |
| Dawn | 05:00–07:00 | 2 min |
| Day | 07:00–17:00 | 10 min |
| Dusk | 17:00–19:00 | 2 min |

The sun sweeps 180° across 12 real minutes = **15° per real minute**. A shadow visibly rotates
during a two-minute errand, but a route planned at the start of a trip is still valid at the end.
This is the number to change if shade routing feels either static or unfair.

### A2 — ~15 minutes of cumulative hauling before infrastructure
5–6 loaded round trips, totalling roughly 15 minutes, before the hand winch is both affordable
and *wanted*.

**This does not come from a fixed trip length.** It comes from geometry:

```
  trip 1   ~90s   face is 15 tiles from the shaft — you just breached here
  trip 2  ~110s
  trip 3  ~150s   you've followed the seam
  trip 4  ~190s
  trip 5  ~230s
  trip 6  ~250s   the face is now 90+ tiles out and you are sick of this
  ─────────────
  total   ~17 min, and the winch has been affordable since trip 4
```

The pressure curve is **self-generating**: the mine face recedes from the shaft as the player
works it, so trips get longer without anyone tuning them. If hauling feels wrong, the levers in
order of preference are (1) winch cost, (2) ore yield per tile, (3) carry capacity — **and the
kill-switch remedy for tedium is always cheaper chutes and winches, never a bigger pack**
([D-013](./design-decisions.md)).

---

## 2. Movement & load

**There is one movement speed.** No sprint, no movement stamina
([D-032](./design-decisions.md)). Stamina exists only for combat actions.

Base walk **5.0 tiles/s** — brisk, because it is the only gear there is. Load is the *sole*
input to movement speed, which means **every speed change the player ever feels is information
about their pack**:

| Load | Walk | Climb |
|---|---|---|
| 0–50% | 5.0 | normal |
| 50–80% | decays 5.0 → 4.2 | normal |
| 80–100% | decays 4.2 → 3.6 | ×1.6 time |
| 100–150% | decays 3.6 → 2.2 | ×2.0 time |
| >150% | 1.6 | **ladders impossible** |

Empty-to-full is a **28% speed penalty**, and grossly overloaded is punishing. The base speed of
5.0 is set higher than it would be with a sprint available, so that the *empty return leg* — the
least interesting part of a haul — does not become dead time.

The ladder rule at >150% is deliberate: a legible, physical, thematic limit rather than a UI
error. It is not a block on progress — stairs, chutes and lifts all still work, and you can
always drop something.

### Vertical transit times

| Method | Unloaded | Full pack | Notes |
|---|---|---|---|
| Ladder | 5.0 s | 8.0 s | Cheapest, worst |
| Stair | 3.0 s | 4.0 s | Needs a 2×3 footprint |
| Chute (items) | instant | — | **Down only** |
| Hand winch | 25 s of *player time* per 120 kg crate | | You stand and crank |
| Powered hoist | 30 s per 120 kg crate | | **Not faster — it just isn't your time** |
| Lift car | 4 s per level + call time | | Player *and* cargo |

The hoist being no faster than the winch is the point. What it buys is your attention back.

---

## 3. Weights

Base carry capacity **60 kg**. Hearty stew grants **+25%** (75 kg).

| Item | kg | | Item | kg |
|---|---|---|---|---|
| Copper / tin ore | 5.0 | | Copper or bronze ingot | 4.0 |
| Iron ore | 6.0 | | Iron ingot | 5.0 |
| Coal | 4.0 | | Timber | 2.0 |
| Stone | 3.0 | | Fibre | 0.5 |
| Cave fungus | 0.4 | | Oil (1 unit) | 0.8 |
| Tool | 3.0 | | Lantern | 2.0 |
| Timber prop | 4.0 | | Stone column | 12.0 |

**A full pack is 12 copper ore.**

### The smelting ratio — 3 ore → 1 ingot
15 kg of ore becomes 4 kg of ingot: a **73% weight saving**
([D-031](./design-decisions.md)). A smelter at the mine face nearly quadruples the value of
every trip, which is the single best emergent insight in the design.

It stays honest because the smelter and its fuel have to get down there first: a smelter costs
**8 stone + 4 copper ingots**, and coal (4 kg) is mined on −2 where you need it. **Do not
tutorialise this.**

---

## 4. Digging

```
  dig_seconds = rock_hardness / tool_power
  breach_seconds = (rock_hardness × 8) / tool_power
  breach requires tool_power ≥ rock_hardness × 1.2
```

| Stratum | Hardness | | Tool | Power |
|---|---|---|---|---|
| Surface soil | 6 | | Flint | 16 |
| −1 Rootshelf | 10 | | Bronze | 30 |
| −2 Greyseam | 18 | | Iron | 55 |
| −3 Old Terraces | 30 | | Steel | 95 |
| −4 The Works | 48 | | Ancestral | 160 |
| −5 Drowned | 70 | | | |
| −6 The Crush | 100 | | | |
| −7 | 140 | | | |

**A tier-appropriate tool always digs a tile in ~0.6 s at any depth.** That is the invariant the
tables are built to satisfy. Under-tier tools degrade gracefully rather than hitting a wall —
flint on −2 is 1.1 s, on −3 is 1.9 s: discouraging, never forbidden, which preserves "you can
always go look" at the tool level.

### The resulting breach ladder

| Breach floor of | Needs | Time |
|---|---|---|
| −1 | Flint | 5.0 s |
| −2 | **Bronze** | 4.8 s |
| −3 | **Iron** | 4.4 s |
| −4 | **Steel** | 4.0 s |
| −5 | Steel | 5.9 s |
| −6 | **Ancestral** | 5.0 s |

This falls out of the formula rather than being authored, which is why it is trustworthy.

Other: ore tiles take **1.5×** wall time and yield **2–4 units**. Rubble clears in **0.4 s**
with a shovel.

---

## 5. Exposure

Peak fill **2.22/s** — 0→100 in **45 s** bare at solar noon.

| Game time | Sun multiplier | Bare time to Sunstruck |
|---|---|---|
| 11:00–13:00 | 1.00 | 45 s |
| 09–11, 13–15 | 0.85 | 53 s |
| 07–09, 15–17 | 0.60 | 75 s |
| 05–07, 17–19 | 0.35 | **128 s** |
| 19:00–05:00 | 0.00 | ∞ |

Shade multipliers: **Direct ×1.0 · Dappled ×0.25 · Occluded ×0**.

| Drain | Rate | 100→0 |
|---|---|---|
| Occluded (outdoor shade) | 1.11/s | 90 s |
| Indoors / underground | 6.67/s | 15 s |

Getting into shade is relief, not a reset — that asymmetry is what makes a shade *route* matter
rather than a single shade *tile*.

**Damage:** 85–99 → 0.8% max HP/s. 100 → 3.5% max HP/s (~29 s from full health to death — long
enough to run, short enough to be terrifying).

**Mitigation:** ash paste −30% fill for 3 real min. Woven cloak −35% (post-pre-alpha).
Dawn + ash paste = **183 s** in the open, which is the intended early "real errand" budget.

Weather multipliers (out of pre-alpha; fix wind and weather at 1.0): overcast ×0.5, rain ×0.3,
storm ×0.1.

---

## 6. Light

| Source | Radius | Duration / cost |
|---|---|---|
| **Dark vision** (innate) | 7 | monochrome, low detail, free |
| Torch | 5 | 4 real min |
| Oil lantern | 7 | 1 oil / 90 s; 10-unit tank = 15 real min |
| Brazier | 8 | fuel-fed, fixed |
| Wall lamp | 6 | fixed |
| Lamp lattice | 10 | 2 SP per 10 tiles |

Note the deliberate relationship: **a torch's radius (5) is smaller than dark vision (7).** Light
never extends how far you can *see* — it changes what you can *understand*. Ore identification
requires the tile's light level ≥ 0.35, i.e. inside a light radius.

---

## 7. Power

Unit: **SP** (shaft power). Transmission loss compounds at **0.95 per level of depth**.

| Source | Output @ wind 1.0 | | Consumer | Draw |
|---|---|---|---|---|
| Windmill (T2) | 10 SP | | Powered hoist | 6 |
| Great mill (T3) | 24 SP | | Lift car | 12 |
| | | | Smelter blower | 5 |
| Wind range | ×0.3 calm – ×2.0 storm | | Lamp lattice | 2 / 10 tiles |
| Flywheel store | 600 SP·s | | **Pump** | **25** |
| | | | Deep pump | 40 |

**Brownout:** when demand exceeds supply, every machine runs at `supply ÷ demand` speed. Never a
hard cutoff — a sluggish warren is diagnosable, a stopped one is a mystery.

Worked examples:

- One windmill serving −3: `10 × 0.95³ = 8.6 SP`. Runs one hoist (6) comfortably; **two hoists
  (12) run at 71% speed**, which is exactly the legible pressure we want.
- One pump at −5 needs `25 ÷ 0.95⁵ = 32 SP` at the source — **two great mills**. Draining the
  Drowned Reaches should require your power infrastructure to be genuinely good.

---

## 8. Survival & recovery

**Hunger:** Full → Empty in **3 game days (72 real min)** of active play.
Peckish at 60%, Hungry at 25%, Empty at 0.

**Meals:** buff duration **15 real min**, one active at a time.

| Meal | Effect |
|---|---|
| Hearty stew | **+25% carry capacity** |
| Grub skewer | +20% dig speed |
| Ash-cap tea | −30% exposure fill |
| Root mash | +50% health regen |
| Lamp-oil cake | −40% lantern burn |

**Marrow-Ache** (tier 1): −25% move, −30% dig, −40% manual craft. Base duration **1 game day
(24 real min)**. Tier 2 (dying while afflicted): −40 / −45 / −60%, 1.5 game days. **Caps at
tier 2.**

Recovery accelerates while sleeping, by room comfort tier:

| Room | Multiplier | Effective duration |
|---|---|---|
| Rough | 1.25× | 19 min |
| Snug | 1.5× | 16 min |
| Fine | 2× | 12 min |
| Grand | 3× | 8 min |

Worker crafting is **never** affected ([D-007](./design-decisions.md)).

**Growth:** cave fungus 1 game day per cycle. Surface grain 3 game days.

---

## 9. World scale

| Level | Radius (tiles) | Approx. area | Widest timber hall (support R) |
|---|---|---|---|
| Surface (summit) | 90 | ~25,400 | n/a |
| −1 Rootshelf | 64 | ~12,900 | 17 (R=8) |
| −2 Greyseam | 81 | ~20,600 | 15 (R=7) |
| −3 Old Terraces | 102 | ~32,700 | 13 (R=6) |
| −4 The Works | 129 | ~52,300 | 11 (R=5) |
| −5 Drowned | 163 | ~83,500 | 9 (R=4) |
| −6 The Crush | 207 | ~134,600 | 7 (R=3) |
| −7 | 207 | ~134,600 | 7 (R=3) |

Each level is **~1.6× the area** of the one above through −6; −7 breaks the pattern, which is the
first signal the player has left the mountain proper ([D-002](./design-decisions.md)).

Column bonuses to R: timber +0 · cut stone +1 · iron-braced +3 · ancestral arch +5. An
iron-braced hall at −6 (R=6) is as open as a timber hall at −3.

---

## 10. Early-game economy check

Validating that A2 actually lands.

| Cost | Copper ore equivalent |
|---|---|
| Bronze pick (4 bronze ingots) | 12 |
| Smelter (8 stone + 4 ingots) | 12 + stone |
| Brazier ×2 | 6 |
| **Hand winch** (20 timber + 12 ingots + 6 rope) | **36** |
| — | — |
| **Total early demand** | **≈ 66 ore + timber + stone** |

At 12 ore per pack that is **5.5 loaded trips** — landing squarely on A2's 5–6, with the winch
affordable around trip 4 and genuinely wanted by trip 6. ✔

---

## 11. Confidence

| Section | Confidence | Notes |
|---|---|---|
| Digging formula | **High** | Self-consistent; the breach ladder is derived, not authored |
| Weights & smelting | **High** | Validated against §10 |
| Exposure rates | Medium | The 45 s peak is a guess; the *shape* matters more than the value |
| Power | Medium | Worked examples check out; wind variance untested |
| Level radii | **Low** | Pure guesses. Expect these to move most |
| Marrow-Ache duration | Medium | 24 min may prove too long even with comfort scaling |
| Hunger rate | Low | Deliberately slack; hunger is not meant to bite |

Sections marked Low are the ones to instrument first in playtest.
