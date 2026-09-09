# World Runtime & Persistence

The hardest thing in the project to change later. This document fixes the world representation,
the simulation model for levels you are not standing on, and the save format.

Target engine: **Godot 4**.

---

## 1. The result that changes everything: no streaming system

The instinct with seven stacked levels of up to ~135,000 tiles is to build chunk streaming.
Do the arithmetic first.

| Depth | Tiles |
|---|---|
| Surface (summit + upper slopes, radius 90) | ~25,400 |
| −1 … −7 | 12,900 · 20,600 · 32,700 · 52,300 · 83,500 · 134,600 · 134,600 |
| **Total** | **≈ 497,000 tiles** |

At **8 bytes per tile in memory**, the entire eight-layer world is **≈4.0 MB**. Persistent
fields are 6 bytes, so a full uncompressed save of every tile in the mountain is ~3.0 MB, and
compresses to well under 1 MB.

**Surface bounds must be a generation parameter, not a baked constant**
([D-041](../design-decisions.md)): the full mountainside is a planned post-pre-alpha expansion
that would roughly quadruple the surface. Even then the total stays under 8 MB, so the
conclusion below does not change.

> **Do not build a tile streaming system.** Hold every level's tile data resident for the whole
> session. This removes an entire subsystem, an entire class of bugs, and weeks of schedule.

What *does* need culling is **rendering and node instantiation**, not data. Only build visual
chunks near the camera.

---

## 2. Coordinates

```
  WorldPos { int x; int y; int depth }
```

- `depth 0` = surface, `depth 1..7` = levels −1 … −7.
- **Internal depth is positive; display is negative.** One mapping function, used everywhere,
  or this will cause off-by-one bugs forever.
- **All depths share one origin — the mountain's axis** ([world-and-generation §1](../world-and-generation.md)).
  `(x, y)` on depth 3 is directly below `(x, y)` on depth 2. This is what makes shafts, lifts and
  driveshafts spatially real, and it is non-negotiable.
- Each depth has its own bounding radius, so a coordinate valid at depth 6 may lie outside the
  disc at depth 1. Bounds are per-level; the coordinate space is global.

---

## 3. Tile storage

Structure-of-arrays, chunked at **32×32** for dirty tracking and render batching.

| Field | Size | Persistent? |
|---|---|---|
| `terrain_id` | u16 | yes |
| `flags` | u16 | yes |
| `region_id` | u8 | yes |
| `ore_id` | u8 | yes |
| `light_level` | u8 | **no — computed** |
| `support_state` | u8 | **no — computed, cached** |

`flags` bits: `is_wall`, `floor_breached`, `is_built_floor`, `is_reinforced`, `has_rubble`,
`visited`, `remembered`, `submerged`.

### Derived, never stored
**Support state is computed, not authored.** On any tile edit, mark dirty and recompute support
within `R_max + 2` of the change, processed across frames from a dirty set. It must also be
**fully recomputed on load** — never trusted from a save file, or a tuning change to R silently
leaves old worlds structurally wrong.

Light level is likewise recomputed from light sources on load.

`remembered` is the one bit of the render model that *is* persistent
([art-and-camera §2](./art-and-camera.md)).

---

## 4. Regions and chambers

### Regions — generation-time only
```
  Region { id, archetype, access_class, cleared }
```
`access_class` ∈ `OPEN · UNSTABLE · SEALED · CRUSHED` ([D-012](../design-decisions.md)).
Tiles carry `region_id` for archetype, decoration, ore and fauna lookup.

**There is no `FLOODED` class** ([D-039](../design-decisions.md)). Generation decides where water
sits, realises that boundary as actual rock and bulkheads, and discards the tag. Nothing at
runtime consults a region to answer "is this wet".

### Chambers — the runtime water model
A **chamber** is a connected component of open space. A **water body** is a chamber flagged as
submerged.

```
  WaterBody { id, chamber_root, drain_stage, pump_ids, sealed: bool }
```

- `drain_stage` is **per body**, a small integer (submerged → waist → ankle → dry). **Never per
  tile.** There is no height, level, flow or pooling, and there must never be
  ([D-017](../design-decisions.md), and the hard line in
  [world-and-generation §5](../world-and-generation.md)).
- Tiles carry a `submerged` flag, flipped in bulk when a stage completes.

### Connectivity maintenance
Note the asymmetry, because it determines the data structure:

| Edit | Effect on components | Cost |
|---|---|---|
| Mine a wall | **merge** | cheap — union-find |
| Build a wall / close a bulkhead | **split** | expensive — recompute the affected component |

Mining is frequent and cheap; sealing is rare and expensive. Use union-find for merges and a
bounded flood-fill on split, budgeted across frames. On a merge where exactly one side is a water
body, the other side floods.

**Chambers are recomputed on load**, like support and light — never trusted from a save.

Deferred but not precluded: water travelling down player-dug shafts between depths. The chamber
model is per-depth today; the extension is a cross-depth link at any open floor breach.

---

## 5. Simulating levels you are not on

This is the requirement that most shapes the architecture, and it comes from the design:

> **A powered hoist must keep hauling while you are three levels away.** That is the entire
> point of the hoist ([vertical-logistics §2](../systems/vertical-logistics-and-power.md)).

### Deterministic accrual, not background ticking

Machines are **rate machines**. Each stores `last_evaluated_tick` and its rate. Nothing ticks
off-screen; a machine's output is computed lazily when it is queried, when the player arrives on
that level, or when its power network changes.

```
  produced = rate × power_ratio × (now − last_evaluated_tick)
```

This is **exact, not approximate**, provided `power_ratio` is constant across the interval — and
it is, because power only changes on discrete events: a machine built or destroyed, a driveshaft
cut, or the wind changing. Every such event re-evaluates the affected network and stamps a new
`last_evaluated_tick` on its machines.

In pre-alpha wind is fixed at 1.0 ([pre-alpha-scope §4](../pre-alpha-scope.md)), so power changes
*only* from player construction — and the player can only build on the level they occupy. The
accrual is therefore trivially exact for the whole first build.

When variable weather arrives, wind must become a **stepped** value (changing on discrete
weather events) rather than a continuous curve, so accrual stays exact. **This is a design
constraint on the weather system, decided here.**

### What else runs off-level
Nothing. Creatures, crops and fauna on other levels are frozen; crops use the same accrual model.
Nothing that can threaten the player runs where the player cannot see it.

---

## 6. Entities

**No system may assume a single actor** ([D-004](../design-decisions.md)). This is the M0 rule
that is expensive to retrofit and free to honour now.

- One `Actor` base — the player, a recruited moleperson, and a creature are all Actors with
  different component sets. There is no `Player` singleton, no `get_player()`, and no global that
  resolves to "the" character.
- Capabilities are **components**: `Inventory`, `Locomotion`, `Health`, `Exposure`, `Hunger`,
  `Afflictions`, `WorkAssignment` (later). A creature simply lacks most of them.
- Every actor has a stable `actor_id`. Built structures record `builder_id`. Storage is shared by
  default; ownership is recorded for later, not enforced now.
- Anything that reads "the player's position" for gameplay (vision, exposure, spawn suppression)
  must accept a **set** of actors.

The worker layer, when it arrives, should require no changes here at all — that is the test.

---

## 7. Save format

```
  header   : format_version · world_seed · game_time · playtime · actor_count
  per depth: level_seed · region table · POI instances · tile arrays (compressed)
  entities : actors · structures · machines (with last_evaluated_tick) · ground items
  meta     : discovered techniques · quest/objective flags · tuning_profile_id
```

Decisions:

- **Store full tile arrays, not seed-plus-deltas.** A delta system saves maybe 2 MB and costs a
  permanent class of "my base disappeared after an update" bugs, because regeneration must stay
  bit-identical across every future change to procgen. Not worth it. Compress the arrays.
- **`format_version` is an integer with explicit migration functions.** Write the first migration
  before it is needed; a save format with no migration path is one that gets wiped repeatedly
  during pre-alpha, which destroys long-run playtest data — and long-run data is exactly what
  criterion 5 needs ([pre-alpha-scope §6](../pre-alpha-scope.md)).
- **Record `tuning_profile_id`** so a playtest save can be traced to the numbers it was played
  under ([content-schema §4](./content-schema.md)).
- Level seeds derive as `hash(world_seed, depth)`.
- Support and light state are **not saved** — recomputed on load (§3).

---

## 8. Generation threading

Level generation runs on a worker thread and must not touch the scene tree. It produces plain
tile arrays plus a region table and a POI placement list; the main thread instantiates nodes
from that. Generation happens on first descent, not at world creation, so starting a new game
is fast and only the surface plus −1 exist initially.

---

## 9. Co-op readiness

Not built in pre-alpha, but the shape above is already compatible:

- Tile arrays are small enough to send wholesale on join.
- Rate-machine accrual is naturally server-authoritative and needs no per-frame sync.
- Actor-agnostic entities mean a second player is just another Actor.
- Region state is a tiny table, trivially replicated.

The one thing that would break this is a `Player` singleton. Do not write one.

---

## 10. M0 acceptance

M0 is done when:

- [ ] Eight depths exist with shared-origin coordinates and a display/internal mapping function
- [ ] Tile arrays resident for all depths, with 32×32 render chunking and camera culling
- [ ] Support and light recompute from scratch on load
- [ ] An `Actor` with components, and **no `Player` singleton anywhere in the codebase**
- [ ] Save/load round-trips a modified world, with `format_version` and one no-op migration
- [ ] A rate machine accrues correctly across a save/load and across level changes
