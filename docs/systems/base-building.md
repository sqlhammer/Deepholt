# Base Building

The warren is the game's memory. Everything else is transient — this is the part that persists
and accumulates.

---

## 1. Building vocabulary

Grid-aligned, tile-based, in Core Keeper's idiom.

| Category | Examples | Notes |
|---|---|---|
| **Structural** | Timber prop, stone column, iron-braced column, ancestral arch | Governed by the support rule ([digging-and-structure.md](./digging-and-structure.md)) |
| **Surfaces** | Floor tiles, wall facings, **Reinforced Floor** | Reinforced Floor is immune to upward cascade |
| **Stations** | Workbench, smelter, forge, kitchen, loom | Require a minimum tile light level to run at full speed |
| **Storage** | Crates, racks, silos | A weight-limited world means storage *placement* matters |
| **Logistics** | Ladder, stair, chute, winch, hoist, lift, driveshaft, line shaft | See [vertical-logistics-and-power.md](./vertical-logistics-and-power.md) |
| **Light** | Brazier, wall lamp, lamp lattice | Colour and detail; deters some fauna |
| **Comfort** | Bed, chairs, tables, rugs, hangings, carvings | Feeds the room score (§2) |
| **Surface** | Shade post, awning, covered walkway, windmill, planted sapling | The above-ground half of building |

---

## 2. Rooms & comfort

### Room vs Chamber — keep these apart
The same flood-fill runs for two unrelated purposes, and conflating them is how a natural cavern
ends up with a comfort score ([D-039](../design-decisions.md)):

| | **Room** | **Chamber** |
|---|---|---|
| Is | a *built*, enclosed, deliberate space | any connected component of open space |
| Requires | walls/doors the player put there, a floor | nothing — raw cave counts |
| Consumed by | comfort scoring, later worker assignment | **water connectivity** |
| Scored? | yes | never |

Every Room is a Chamber. Almost no Chamber is a Room. Shared algorithm, separate concepts,
separate names in code.

Enclosed spaces are **detected automatically** — a sealed floor area bounded by walls and doors
— and scored.

### Score inputs

| Input | Weight | Notes |
|---|---|---|
| Enclosure | required | An unsealed space scores nothing |
| **Light level** | high | The single biggest lever. Colour = home |
| Floor & wall material | medium | Bare stone → cut stone → tile |
| Furniture variety | medium | Variety beats quantity; spamming chairs is capped |
| Decoration | medium | Hangings, carvings, plants |
| Cleanliness | low | Rubble and loose spoil subtract |
| Size appropriateness | low | Cavernous empty halls score worse than snug ones |

### Tiers and what they do

| Tier | Effect |
|---|---|
| **Rough** | Baseline |
| **Snug** | Marrow-Ache recovers ~25% faster when resting here |
| **Fine** | ~50% faster; small passive stamina bonus on waking |
| **Grand** | ~75% faster; later, required to attract certain recruits |

This is the key integration: **comfort is what softens your worst moments.** Decorating stops
being vanity and becomes insurance, without ever being mandatory — a player who likes bare
stone is slower to recover, never blocked. And it is the *same* score the deferred worker layer
will need to answer "would a moleperson want to live here?", so one system does three jobs
([core-loops.md §5](../core-loops.md)).

**Anti-coercion rule:** no comfort tier may ever gate progression, tech, or content. It only
ever accelerates recovery and influences recruitment.

---

## 3. Architecture reads as depth

Because support radius shrinks with depth and better columns buy it back
([D-014](../design-decisions.md)), the *look* of a room encodes both where it is and how
advanced you are:

- **−1, timber:** wide, airy, rustic, few props
- **−4, timber:** a thicket of props. Claustrophobic, clearly beyond your means
- **−4, iron-braced:** open again, industrial, confident
- **−6, ancestral arch:** vaulted halls at the bottom of the world

The art team should treat this as a core visual promise: **a screenshot should tell you how
deep you are and how good you have gotten.**

---

## 4. Multi-level base design

The warren is expected to sprawl vertically, and the game should reward specialising by depth:

- **Living and comfort** near the top — safe, cheap to keep lit and warm.
- **Processing** near the ore — smelting where you mine saves enormous haul weight, because
  refined metal is lighter than raw. This is the single most important base-planning insight in
  the game and it should be *discoverable*, not tutorialised.
- **Power** vertical — one driveshaft column serving every level it passes.
- **Chutes down, hoists up**, co-located, so a level's throughput is one place you can look at.

---

## 5. Ownership & co-op shape

Per [D-004](../design-decisions.md), nothing may assume a single actor. Built objects record a
builder, storage is shared by default, and room detection is player-agnostic. No system may key
off "the player" — always "an actor".

---

## 6. Pre-alpha subset

- [ ] Floors, walls, doors, timber props, stone columns
- [ ] Workbench, smelter, kitchen, crates
- [ ] Braziers and wall lamps
- [ ] Bed with respawn
- [ ] Room detection with light + material + furniture scoring, Rough/Snug/Fine only
- [ ] Shade posts and awnings on the surface

Cut: Grand tier, decoration variety scoring, cleanliness, reinforced floor, ancestral arches,
lamp lattice, silos, planted saplings.
