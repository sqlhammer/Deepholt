# M0-02 — Coordinates and depth mapping

**Depends on:** M0-01 · **Feeds:** M0-03, M0-05, M0-06, M0-09
**Acceptance check:** §10.1 (shared-origin coordinates and a display/internal mapping function)

## Goal

One coordinate type and one depth-naming function, used everywhere, so the off-by-one bug
[world-runtime §2](../../../docs/tech/world-runtime-and-persistence.md) warns about never gets
a chance to exist.

## In scope

- `WorldPos { x: int, y: int, depth: int }` — value type, hashable, printable.
- **Internal depth is positive; display is negative.** `depth 0` = Surface, `depth 1..7` =
  levels −1 … −7. Exactly one function converts internal → display string, and one converts back.
  No other code in the project may format a depth.
- Per-depth bounding radii as **generation parameters, not baked constants**
  ([D-041](../../../docs/design-decisions.md)) — a `LevelBounds` table with the eight radii from
  §1, loaded from a resource file, plus `is_in_bounds(pos)`.
- Level seed derivation: `level_seed = hash(world_seed, depth)`, deterministic and stable.
- The global-coordinate-space rule made testable: `(x, y)` is the same world column on every
  depth; only the bounds differ.

## Out of scope

Tile data (M0-03). Any conversion between world coordinates and pixels (M0-04).

## Design constraints

- Surface bounds must be reachable from a parameter, never a literal — the full mountainside is
  a planned expansion that roughly quadruples the surface ([D-041](../../../docs/design-decisions.md)).
- A coordinate valid at depth 6 may lie outside the disc at depth 1. `is_in_bounds` is per-depth;
  the coordinate space is global. Do not "fix" this by clamping to the smallest disc.

## Automated checks

| Check | Expectation |
|---|---|
| round-trip `display(internal(d)) == d` for depths 0–7 | pass |
| `display(0) == "Surface"`, `display(3) == "−3"` | pass |
| a coordinate inside depth 6's disc but outside depth 1's | in bounds at 6, out of bounds at 1 |
| `hash(seed, depth)` stable across two runs, distinct per depth | pass |
| grep for depth string formatting outside the mapping function | no matches |

## Human verification

1. Run the test suite. → All coordinate tests pass.
2. Open the debug scene and use the depth stepper. → The overlay shows
   `Surface, −1, −2 … −7` in order and never shows a positive number or `-0`.
3. Step past depth 7 and below Surface. → It clamps; no crash, no `−8`.
4. Change the surface radius in the bounds resource from 90 to 30, relaunch. → The overlay's
   reported surface tile count drops accordingly, with no code change.

## Exit checklist

- [ ] `WorldPos` in use, no ad-hoc `(x, y, depth)` tuples elsewhere
- [ ] Exactly one internal↔display mapping function
- [ ] Bounds are data, not constants; all eight depths present
- [ ] Seed derivation deterministic

## Discovered work

-
