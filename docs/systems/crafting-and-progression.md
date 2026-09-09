# Crafting & Progression

---

## 1. Two currencies

Progression runs on two separate things, and keeping them separate is what makes the descent
*be* the tech tree ([D-005](../design-decisions.md)).

| | **Materials** | **Techniques** |
|---|---|---|
| Source | Mined, farmed, salvaged | **Recovered from ancestral ruins** |
| Gates | Whether you can afford a thing | Whether you know a thing exists |
| Feel | Effort | Discovery |

You never *invent* the important technology. The molepeople already knew how to seal against
water, brace a deep span, and run a lift; the upper shelf simply forgot. Every major unlock is
a recovered blueprint, which means **the tech tree is buried in the world in roughly the order
you need it**, and reading a document is never optional flavour text you skip
([story-and-setting.md §5](../story-and-setting.md)).

---

## 2. The tier spine

| Tier | Stratum | Key materials | Techniques unlocked |
|---|---|---|---|
| **T0** | Surface, −1 Rootshelf | Flint, clay, timber, fibre, root, cave fungus | Workbench, flint tools, timber prop, **ladder**, **chute**, torch, hearth, fungus bed, shade post |
| **T1** | −2 Greyseam | Copper, tin → **bronze**, coal | Smelter, bronze tools, cut stone column, stone stair, **hand winch**, oil lantern, ash paste, awning |
| **T2** | −3 Old Terraces | **Iron**, cut stone, salvage | Forge, iron tools, **windmill + driveshaft + line shaft**, **powered hoist**, woven cloak, reinforced floor, loom |
| **T3** | −4 The Works | **Steel**, machinery salvage, bearings | **Lift car**, gearbox & clutch, **flywheel**, **pump**, smoked lenses, lamp lattice, restoration of the **ancestral lift core** |
| **T4** | −5 Drowned Reaches | Silver, deep fungi, sealed caches | **Bulkhead sealing**, deep pumps, waterproofing, **everburn crystal** |
| **T5** | −6 The Crush | Pinched-seam rare ore | **Deep shoring**, hydraulic jacks, **ancestral arch** |
| **T6** | −7 Deep Warren | — | Reconnection. Recruits, and the techniques the deep kept alive |

Read the bold entries down the column: **ladder → chute → winch → hoist → lift → lift core.**
That is the game's actual progression curve, and every tier's headline unlock is a piece of it.

---

## 3. Crafting stations

| Station | Tier | Purpose |
|---|---|---|
| Workbench | T0 | Basic tools, structural parts |
| Hearth / kitchen | T0 | Meals ([survival-and-farming.md](./survival-and-farming.md)) |
| Smelter | T1 | Ore → ingots. **Site this near your mine, not your home** |
| Forge | T2 | Iron and steel tools, machine parts |
| Loom | T2 | Cloaks, rope, belts |
| Machine shop | T3 | Bearings, gears, pump and lift components |

All stations require a minimum tile light level for full speed, and all are slowed by
Marrow-Ache when operated by hand — but **never when operated by a worker** later
([D-007](../design-decisions.md)).

### The smelting insight
Ingots weigh substantially less than the ore they came from. In a weight-limited world
([D-013](../design-decisions.md)) this makes *where you smelt* one of the most consequential
decisions a player makes, and building a forward processing camp at −3 is a genuine
strategic leap. **Do not tutorialise this.** Let players find it; it is the best "oh!" in the
design.

---

## 4. Tools

| Tool | Job |
|---|---|
| **Pick** | Mining, and **breaching floors** — the one remaining hard tool gate on descent |
| **Shovel** | Soft material, spoil, clearing rubble faster |
| **Hammer** | Placing and removing built structures |
| **Lantern** | Light, fuel-consuming |
| **Weapon** | See [combat-and-fauna.md](./combat-and-fauna.md) |

Tool tiers: flint → bronze → iron → steel → ancestral. Each tier raises dig speed and the
hardness (and therefore stratum depth) it can breach.

---

## 5. What progression is *not*

- Not a stat wall. You descend when you can **supply** a level, not when a number clears a bar.
- Not a skill tree with points. There is no XP and no levelling.
- Not a linear gate chain. Region gates ([D-012](../design-decisions.md)) mean you can always
  go look, and always leave something behind.

---

## 6. Pre-alpha subset

- [ ] T0 and T1 in full, T2 partial (iron tools, windmill, driveshaft, powered hoist)
- [ ] Workbench, hearth, smelter, forge
- [ ] Pick / shovel / hammer / lantern, flint → bronze → iron
- [ ] Techniques as recoverable blueprints from at least three authored ruin POIs on −3

Cut: T3 and above, loom, machine shop, steel, everything downstream of the lift car.
