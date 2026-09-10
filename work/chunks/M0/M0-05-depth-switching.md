# M0-05 — Depth switching and shared origin

**Depends on:** M0-04 · **Feeds:** M0-07, M0-10
**Acceptance check:** §10.1 (shared-origin coordinates, proven visually)

## Goal

Prove the non-negotiable: `(x, y)` on one depth is directly below `(x, y)` on the depth above.
This is the guarantee that M1's breaching, M3's chutes and M5's driveshafts all rest on, and
it is much cheaper to prove now than to discover broken in M5.

## In scope

- A depth-change operation that swaps the active depth's render layer while **preserving the
  camera's `(x, y)`** exactly — no re-centring, no drift.
- Chunk nodes for the departed depth freed; the new depth's built. Tile data for both stays
  resident and untouched.
- A **vertical alignment probe** in the debug overlay: a persistent crosshair at the camera's
  `(x, y)` plus a readout of the tile under it on the current depth *and* the depth above and below.
- Debug controls to step depth up/down.

## Out of scope

Ladders, chutes, breaching floors, or any in-world means of changing level (M1/M3). This is a
debug teleport between depths. Ghosted adjacent layers and the layer-stack map are M3.

## Design constraints

All depths share one origin — the mountain's axis
([world-and-generation §1](../../../docs/world-and-generation.md)). Per-depth bounds differ, so
stepping down at the surface's edge may leave you outside the disc below; show that state
honestly in the overlay rather than sliding the camera to somewhere legal.

## Automated checks

| Check | Expectation |
|---|---|
| depth change preserves camera `(x, y)` bit-exactly | pass |
| `shaft` world: the carved column reads carved at the same `(x, y)` on all 8 depths | pass |
| depth change frees the old depth's chunk nodes | pass |
| tile data on the departed depth is unchanged after a round trip | pass |

## Human verification

1. Load the `shaft` world and put the crosshair on the shaft column at Surface.
2. Step down through −1, −2 … −7 without touching the camera. → The crosshair never moves, and
   the shaft tile is under it on **every** depth.
3. Move 5 tiles off the shaft and step down and back up. → You return to the same tile; the
   overlay's `(x, y)` is unchanged from where you started.
4. Move to the far edge of a deep depth and step up toward the surface. → The overlay reports
   "outside bounds at this depth" rather than teleporting the camera somewhere valid.
5. Step through all eight depths repeatedly for a minute. → Chunk-node count returns to its
   baseline each time; memory does not climb.

## Exit checklist

- [ ] Camera `(x, y)` preserved across every depth change
- [ ] Shaft column aligns on all eight depths, verified by eye
- [ ] Out-of-bounds reported, not corrected
- [ ] No node or memory leak across repeated switching

## Discovered work

-
