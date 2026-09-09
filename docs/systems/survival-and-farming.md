# Survival & Farming

Three pressures only — **hunger, light, exposure** ([D-006](../design-decisions.md)). Light and
exposure are specced in [light-and-sunlight.md](./light-and-sunlight.md). This document covers
hunger, and the two agricultures that answer it.

---

## 1. Hunger — gentle by design

A slow-draining meter. Reaching empty is *not* a death sentence; the tone is warm
([D-019](../design-decisions.md)) and starving to death because you were absorbed in building
is a bad memory to give someone.

| State | Effect |
|---|---|
| **Fed** | Meal buff active (see §2) |
| **Peckish** | Meal buff expires. No penalty |
| **Hungry** | Stamina regen halved |
| **Empty** | Slow health drain and a further −15% walk speed. Survivable for a long time |

Hunger's real job is not threat. It is **the reason you keep a kitchen, a farm, and a reason
to come home.**

---

## 2. Cooking — the buff layer that feeds the hauling pillar

Cooked meals grant a timed buff. **One meal buff active at a time**, so eating is a choice
about what this expedition is for.

| Meal | Buff | Why it matters |
|---|---|---|
| **Hearty stew** | **+ carry weight** | Directly answers the game's central pressure. "What did I eat before this trip" becomes expedition planning |
| **Grub skewer** | + dig speed | Excavation sessions |
| **Ash-cap tea** | + exposure resistance | Surface runs; stacks with gear |
| **Root mash** | + health / stamina regen | Deep or dangerous work |
| **Lamp-oil cake** | reduced lantern burn rate | Long dark expeditions |

Design rule: **at least one meal buff must always target the current pillar.** Carry weight is
the anchor; if a future meal outclasses it for general use, that is a balance bug.

Buff duration in the 10–20 real-minute range — long enough to cover an expedition, short
enough that you re-decide next time.

---

## 3. Two agricultures

### 3.1 Underground — the default

| Crop | Needs | Notes |
|---|---|---|
| **Cave fungus** (staple) | Compost substrate, moisture, **darkness** | Reliable, dull, always available |
| **Ash-cap** | Compost, warmth (near a hearth or a warm updraft) | Exposure-resist ingredient |
| **Deep fungi** | Found at −5+, transplantable | High-value, slow |
| **Grub / worm beds** | Fed on compost | Protein. Extremely moleperson |

**Compost** is made from spoil plus organic waste — which quietly gives excavation byproduct a
use, and means digging feeds you. Some species require darkness, so a fully-lit warren is
suboptimal and there is always a room you deliberately leave dark
([light-and-sunlight.md §3.2](./light-and-sunlight.md)).

### 3.2 Surface — the risky one

Grain, roots and fibre need **direct sun**. Which means the crop you most want is grown in the
place that hurts you, and tending it is a timed excursion with a shade route.

Three ways to play it, and all three should stay viable:

1. **Dawn/dusk tending.** Cheap, constant low-grade risk, no infrastructure.
2. **Shade-routed farm.** Build awnings and paths so the *farmer* is shaded even though the
   *crop* is not. Pure expression of the surface pillar.
3. **Indoor growing under lamp lattice.** Safe, but costs **power** — which means your windmill
   is now competing with your pumps. This is the good tradeoff: it converts a survival problem
   into a logistics problem, which is the game's favourite move.

---

## 4. Water

Not a survival meter ([D-006](../design-decisions.md)) — no thirst. Water exists as an
*industrial and agricultural* input: irrigation for beds, feed for boilers later, and the
antagonist of the Drowned Reaches. Keeping water and thirst separate means the player's
relationship with water is always about engineering, never about a bar.

---

## 5. Pre-alpha subset

- [ ] Hunger meter with four states
- [ ] Hearth / cooking station, 2 meals (hearty stew, grub skewer)
- [ ] Cave fungus beds, compost from spoil
- [ ] One surface crop with dawn/dusk tending

Cut: ash-cap, deep fungi, grub ranching, indoor lamp-lattice growing, irrigation, all other
meals.
