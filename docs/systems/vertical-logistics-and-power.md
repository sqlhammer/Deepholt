# Vertical Logistics & Power

Pillar P1. This is the game's signature system. Everything else exists to give it problems
to solve.

---

## 1. The premise: down is free, up is the game

Gravity is a one-way subsidy. Dropping a ton of ore from −4 to −5 costs nothing; lifting it
from −4 to −1 is the central logistical problem of the game.

This only works because inventory is **weight-limited with no teleport** ([D-013](../design-decisions.md)).
If the player can pocket 900 iron and warp home, none of the following exists. Guard this.

**Design rule:** every downward-only solution should be cheap and early. Every upward
solution should cost materials, space, and power. The asymmetry *is* the design.

---

## 2. The transport ladder

| # | Structure | Direction | Carries | Needs | Era |
|---|---|---|---|---|---|
| 1 | **Ladder** | both | player only, slowly | wood | start |
| 2 | **Stair** | both | player, at walking pace | stone, a 2×3 footprint | −1 |
| 3 | **Chute** | **down only** | items | wood, an aligned hole | −1 |
| 4 | **Hand winch** | up | one crate, one level, player must operate it | rope, timber | −2 |
| 5 | **Powered hoist** | up | continuous crate flow, one level | power | −3 |
| 6 | **Lift car** | both | player **and** cargo, multiple levels | aligned clear shaft, power, a landing per level | −4 |
| 7 | **Ancestral lift core** | both | high throughput, spans many levels | *restored*, not built | −4 find |

The intended arc: *"I climb"* → *"I throw things down and climb"* → *"I crank a winch and
hate it"* → *"the hoist runs while I mine"* → *"I ride the lift to my mine"*.

Step 4 is deliberately tedious. The hand winch exists so that the powered hoist feels like
a liberation rather than a convenience.

### Shaft alignment
All levels share a coordinate origin, so a lift shaft is a genuine column through the
mountain: every level it passes must have a cleared, aligned tile column and a landing where
you want a stop. Restoring an **ancestral lift core** means clearing rubble and water out of
a shaft that already runs six levels — the biggest single engineering project in the mid-game,
and the moment the map stops feeling like seven maps and starts feeling like one mountain.

---

## 3. Power

### 3.1 Generation — wind, on the surface

Windmills are built on the **surface**, on exposed high ground. Note the tension this creates
for free: the best wind is on open, unshaded ground, which is the most dangerous place in the
game to stand. Building and maintaining your power supply is a *surface excursion* with an
exposure route to plan.

Output scales with weather and terrain exposure.

### 3.2 Transmission — the driveshaft

Power is **mechanical**, not electrical. A vertical **driveshaft** occupies a tile column and
must be continuous from the windmill down through every level it serves. Each level's segment
costs materials to build and maintain.

- **Transmission loss ≈ 5% per level.** Deep machinery is expensive to feed, which pushes the
  player toward more windmills, better shafts, and eventually local generation.
- On each level, power spreads horizontally through **line shafts and belts** — the Victorian
  mill idiom. Visually excellent, thematically right for the industrial ruins of The Works,
  and it makes power distribution a *layout* problem on every level, not just a vertical one.
- **Gearboxes** split and step power; **clutches** let the player cut a branch off.

### 3.3 Load and brownouts

Total draw greater than supply does **not** shut machines off. Everything runs
**proportionally slower**. This is the single most important choice in the power system:
brownouts are legible ("everything is sluggish, I need more wind") where hard cutoffs are
mysterious and infuriating ("why did my pump stop").

### 3.4 Storage — the flywheel

A **flywheel** or **counterweight tower** banks surplus power for calm days. A large, visible,
satisfying building that the player constructs specifically to defeat the weather.

### 3.5 Weather does two opposed jobs

This is the payoff for choosing wind:

| Weather | Surface travel | Power |
|---|---|---|
| **Storm** | Excellent — low light, safe | Excellent — peak output |
| **Overcast / rain** | Good | Good |
| **Night** | Excellent | Whatever the wind is doing |
| **Clear and calm** | **Lethal** | **Brownout** |

A clear calm day is the worst day in the game. The player will learn to read the sky, bank
power before it, and use storms as their window to go out. One weather system, texture in two
places, no extra machinery.

---

## 4. Consumers

| Machine | Draw | Purpose |
|---|---|---|
| Powered hoist | low | One-level item lift |
| Lift car | medium | Player + cargo, multi-level |
| **Pump** | **high** | Draining flooded chambers. The reason power exists |
| Grinder / smelter blower | medium | Processing throughput |
| Lamp lattice | low | Fixed lighting without fuel |
| Ventilation fan | low | Later; deep-level quality of life |

Pumps are the anchor — but note that pumping is only the *last* step. Water spreads by
connectivity ([D-039](../design-decisions.md)), so draining a chamber means first finding and
sealing every opening into it; a pump running against an open passage achieves nothing. Bulkheads
and doors are drainage equipment.

Draining the Drowned Reaches should require the player's power infrastructure to be genuinely
*good* — multiple windmills, a well-built shaft, a flywheel
bank — and completing a drain should be a celebrated event.

---

## 5. Pre-alpha subset

- [ ] Weight-limited inventory, no teleport
- [ ] Ladder, chute, hand winch
- [ ] Single windmill, single driveshaft, one level of line shaft
- [ ] Proportional brownout under overload
- [ ] Powered hoist as the one powered consumer
- [ ] Shaft alignment across the three pre-alpha levels

Cut from pre-alpha: lift car, ancestral lift core, flywheel, gearboxes and clutches,
transmission loss tuning, pumps, weather variability (fix wind at a constant for now).
