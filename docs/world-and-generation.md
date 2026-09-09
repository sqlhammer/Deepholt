# World & Generation

---

## 1. The cone

The world is **7 stacked top-down levels** beneath a surface layer. All levels share a single
coordinate origin — the mountain's axis — and each level is a bounded, irregular blob whose
radius grows with depth until the mountain's footprint is reached.

```
                 .-''''''-.
               .'   ☀ SUR  '.        surface: bounded by the mountain's slope
              /  [cave mouths] \
             |==== -1 Rootshelf ====|          smallest playable area
            |===== -2 Greyseam =====|
           |====== -3 Terraces ======|
          |======= -4 The Works =======|
         |======== -5 Drowned =========|
        |========= -6 The Crush ========|   widest
        |          -7  ? ? ?            |   widening STOPS — beneath the footprint
```

Rough area target (tune in playtest): each level is **~1.6×** the playable area of the one
above, from −1 through −6. Level −7 is *not* larger than −6; the break in the pattern is the
first thing that tells the player they've left the mountain proper.

**Why the shared origin matters:** a shaft dug at (x, y) on level −2 lines up with (x, y) on
level −3. Player-built vertical infrastructure is spatially real, ancestral lift shafts are
pre-aligned across several levels at once, and "directly below the workshop" is a meaningful
phrase. Do not let levels drift into independent coordinate spaces.

---

## 2. Strata

| | Stratum | Character | Signature resources | Signature problem |
|---|---|---|---|---|
| ☀ | **Surface** | Ruined, overgrown, lethal at noon | Wood, fibre, grain, salvage, hide | Sun exposure & shade routing |
| −1 | **Rootshelf** | Soft stone, root mats, worms. Home. | Clay, flint, root fibre, cave fungus | None — this level is safe by design |
| −2 | **The Greyseam** | Warm updrafts, banded grey rock | Copper, tin, coal | First real ceilings to support; first dark |
| −3 | **The Old Terraces** | Ancestral *residential* warren, half-buried | Iron, cut stone, salvaged goods | Unstable ruin spans; the premise lands here |
| −4 | **The Works** | Foundries, the old lift network, vast collapsed halls | Steel inputs, machinery salvage, ancestral blueprints | Enormous spans that must be re-shored |
| −5 | **The Drowned Reaches** | Standing water, sluices, sealed bulkheads | Deep fungi, silver, sealed caches | Water. Nothing here without drainage |
| −6 | **The Crush** | Crumpled, folded strata; actively settling | Rare ore in pinched seams | Continuous structural failure |
| −7 | **?** | Beneath the footprint. The Deep Warren. | — | Reconnection |

Levels −1 to −3 are the *approach*. −4 to −6 are the *disaster*, one act each (see
[story-and-setting.md](./story-and-setting.md)). −7 is the payoff.

---

## 3. Region access — "levels are open; regions are earned"

This is the descent-gating model. **Getting onto a level is never blocked. Using all of it is.**

Each level is partitioned into 4–8 **regions** (districts), each tagged with an access class:

| Class | Blocked by | Unlocked by | Runtime? |
|---|---|---|---|
| `OPEN` | nothing | — | — |
| `UNSTABLE` | ceiling will fail if you excavate | shoring tech + materials | yes |
| `SEALED` | ancestral bulkhead or rubble plug | mechanism keys, or cutting tech | yes |
| `CRUSHED` | collapsed to solid | deep shoring + jacks; clearing is slow work | yes |
| `WATER_SOURCE` | — | — | **no — see §5** |

**There is no `FLOODED` access class at runtime** ([D-039](./design-decisions.md)). Generation
decides where water sits and then *realises that boundary as physical geometry* — solid rock,
ancestral bulkheads, sealed doors. After that, water is governed by connectivity, not by a tag.
`WATER_SOURCE` marks the regions generation intends to drown, and exists only during generation.

**Generation guarantees, enforced, every seed:**

1. At least **40%** of each level's area is `OPEN` at first arrival.
2. The descent point to the next level is reachable through `OPEN` regions only.
3. Every level contains at least one gated region — the player always leaves something behind
   to come back for.
4. Gated regions hold the disproportionate rewards: the best ore, the authored POIs, and the
   shortcuts that shorten your supply lines.
5. **Every water body is enclosed by a watertight boundary.** Because runtime water spreads by
   connectivity, generation must verify that the open-space component containing each water
   source cannot reach the descent point or the player's arrival area. A seed that fails this
   is rejected. This replaces the old metadata guarantee with a geometric one, and it is the
   principal new cost of [D-039](./design-decisions.md).

The intended feeling on arriving at a new stratum: *"I can work here. But half of this is
going to need pumps."*

---

## 4. Generation pipeline (per level)

1. **Bound** — compute the level's disc radius from depth; perturb the boundary with noise
   so the mountain isn't a cylinder.
2. **Partition** — Voronoi-ish split into 4–8 regions; assign region archetypes from the
   stratum's palette; assign access classes subject to the §3 guarantees.
3. **Carve** — cellular-automata cave generation per region, with per-archetype parameters
   (open caverns vs. tight seams vs. orthogonal ruin corridors).
4. **Stamp POIs** — place authored prefab chunks (with variants and rotation) at region
   centres and junctions. Some POIs are *guaranteed per stratum*, others are from a pool.
5. **Align verticals** — place ancestral shafts and lift cores at coordinates shared with
   adjacent levels; punch matching floor/ceiling holes.
6. **Distribute** — ore, fauna spawners, hazards, decoration from the stratum table.
7. **Seal the water** — for each `WATER_SOURCE` region, realise its boundary as solid rock,
   ancestral bulkheads or sealed doors, then discard the tag. Water bodies exist as geometry
   from here on.
8. **Validate** — connectivity check against the §3 guarantees, **including the watertight
   check (§3.5)**; reject and reseed on failure.

### Authored vs. procedural
Procedural generation supplies *space and material*. Authored prefabs supply *meaning*. The
ancestral ruins in particular must be hand-built — a residential terrace or a pump station
only tells a story if a designer laid out the rooms. Target roughly **70% procedural / 30%
authored** by area on ruin strata (−3 onward), and near-100% procedural on −1 and −2.

---

## 5. Water — connectivity, not fluid simulation

Two rules, and they are in tension on purpose. Read both.

### Rule 1 — water spreads by connectivity
A **water body** occupies a connected component of open space. If you breach a wall between a
flooded chamber and a dry one, the water comes through. If you close a bulkhead, it stops.
Water is where water can reach, bounded by things the player can *see*
([D-039](./design-decisions.md)).

What this buys:

- **Legibility.** No invisible metadata boundary. A player who digs two tiles into the wrong
  wall gets an obvious, physical, deserved answer.
- **Agency.** Draining is a puzzle — find every opening, seal it, *then* pump. Bulkheads and
  doors become critical infrastructure rather than decoration.
- **The disaster becomes re-enactable.** Over-digging into a flooded chamber brings the water
  to you, which is exactly what happened to the ancestors
  ([story-and-setting §2](./story-and-setting.md)). Collapse and flood finally talk to each
  other: a cave-in that opens a wall can let water in.

### Rule 2 — it is still not a fluid simulation
**Water has no height, no level, no flow, and no pooling.** A water body is submerged or it is
being drained; `drain_stage` is a small integer *per body* (submerged → waist → ankle → dry),
never per tile.

> **Hard line:** drain stage is per-body. The moment someone proposes per-tile water depth so
> it can "find its level", the answer is no. Connectivity raises the player's expectation that
> water behaves physically, and that expectation is the single most likely route back into a
> multi-month fluid-simulation hole ([D-017](./design-decisions.md)). This paragraph exists to
> be pointed at.

### Draining
1. Identify the openings connecting the body to anywhere you don't want water.
2. Seal them — bulkheads, doors, built wall.
3. Install pumps, supply power, connect a discharge route.
4. The body drains through discrete stages and its tiles become workable.

Reopening a sealed wall re-floods, unless the source itself has been cut off.

### Telegraphing — required, not optional
Because a wrong breach is expensive, walls adjacent to a water body must be **unmistakably
readable before you swing**: damp discoloration, seepage particles, dripping audio, and a
distinct sound when struck. A player must never flood their base by surprise. Recovery must
also always be possible — pump it back out — so a flood is a setback, never a lost save
([D-019](./design-decisions.md)).

### Deferred: shaft flooding
Water travelling *down the player's own shafts* to lower levels is the natural extension, and
it is excellent — it makes bulkheads at lift landings essential and ties water directly to
pillar P1. It is **deferred past pre-alpha**, but nothing in the architecture may preclude it.

---

## 6. The surface

**Scope: the summit and upper slopes only** — a bounded ring around the top of the mountain,
radius ~90 tiles, with all cave mouths at similar elevation ([D-041](./design-decisions.md)).
The full mountainside down to the base is a **planned post-pre-alpha expansion**; surface bounds
are therefore a generation parameter, never a baked constant, and nothing may assume all cave
mouths share an elevation.

Contents:

- **Multiple cave mouths** around the mountain, at different compass bearings. Because the
  mountain shades itself at low sun, *which mouth you use* changes your exposure route. Some
  mouths are initially collapsed and can be opened from below — a genuine reward.
- **Ruins** of the fallen surface world: shells of buildings that double as authored shade.
- **Canopy** — existing forest, plus saplings the player plants that mature into permanent
  shade over in-game weeks.
- **Wanderer POIs** — a trader's camp, a hermit's tower. Small, warm, hand-built.

Surface generation has one hard requirement the underground doesn't: **it must author shade.**
Every generated cluster of trees, walls and rock is also a piece of the exposure puzzle, and
must be validated as such — at minimum, a survivable dawn route from each cave mouth to at
least one resource cluster.
