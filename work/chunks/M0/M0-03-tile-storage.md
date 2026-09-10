# M0-03 — Resident tile storage

**Depends on:** M0-02 · **Feeds:** M0-04, M0-08, M0-09
**Acceptance check:** §10.2 (tile arrays resident for all depths)

## Goal

Every tile of all eight depths held in memory for the whole session, in the
structure-of-arrays layout [world-runtime §3](../../../docs/tech/world-runtime-and-persistence.md)
fixes — and a measured number on screen proving the "no streaming system" arithmetic was right.

## In scope

- Per-depth structure-of-arrays, chunked **32 × 32** for dirty tracking:

  | Field | Size | Persistent |
  |---|---|---|
  | `terrain_id` | u16 | yes |
  | `flags` | u16 | yes |
  | `region_id` | u8 | yes |
  | `ore_id` | u8 | yes |
  | `light_level` | u8 | no — computed |
  | `support_state` | u8 | no — computed, cached |

- `flags` bits, named as constants, in this order:
  `is_wall · floor_breached · is_built_floor · is_reinforced · has_rubble · visited · remembered · submerged`.
- Allocation of all eight depths at startup, sized from the M0-02 bounds table.
- `get_tile(pos)` / `set_tile(...)` marking the owning 32×32 chunk dirty, and a queryable dirty set.
- **Debug world fixtures** — hand-made worlds, since procgen is M3:
  - `flat`: every depth solid rock with a carved 40×20 room at the origin,
  - `shaft`: `flat` plus a one-tile column carved at a known `(x, y)` through all eight depths,
  - `sparse`: a scattering of set tiles for save-size measurement.
  Loadable from the debug scene by name.
- Debug overlay section: total resident tiles, tiles per depth, measured bytes per tile, total MB.

## Out of scope

Rendering (M0-04). Procgen (M3). Chambers, water and the `submerged` flag's behaviour —
the bit is reserved in the layout and nothing reads it ([pre-alpha-scope §4](../../../docs/pre-alpha-scope.md)).

## Design constraints

- **Do not build tile streaming.** Data stays resident; only rendering is culled
  ([§1](../../../docs/tech/world-runtime-and-persistence.md)). If memory looks alarming, check the
  measurement before changing the architecture — the target is ≈4 MB for the whole mountain.
- `light_level` and `support_state` live in the same arrays but are marked non-persistent at the
  field level, so M0-09 cannot accidentally serialise them.

## Automated checks

| Check | Expectation |
|---|---|
| all eight depths allocated, counts match bounds | pass |
| `set_tile` then `get_tile` returns the written value | pass |
| `set_tile` marks exactly one chunk dirty; neighbours clean | pass |
| a flag set on one tile does not disturb adjacent tiles or other fields | pass |
| total measured resident bytes | < 8 MB |

## Human verification

1. Launch the debug scene with the `flat` world, press **F3**. → The overlay lists eight depths
   with per-depth tile counts, and a total near **497,000 tiles / ≈4 MB**.
2. Watch the memory figure for 60 seconds while stepping through depths. → It does not climb;
   nothing is being loaded or freed.
3. Load the `shaft` world and use the debug tile inspector to read the tile at the shaft
   coordinate on depth 0 and depth 7. → Both report carved, at the *same* `(x, y)`.
4. Use the inspector to toggle `has_rubble` on one tile. → That tile's flag changes, the chunk is
   listed as dirty, and no other tile changes.

## Exit checklist

- [ ] Eight depths resident, sized from bounds data
- [ ] SoA layout matches §3 exactly, including field sizes and flag order
- [ ] 32 × 32 dirty tracking works
- [ ] Three debug worlds loadable
- [ ] Measured total under 8 MB and displayed on the overlay

## Discovered work

-
