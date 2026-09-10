# M0-04 — Render chunking and camera

**Depends on:** M0-03 · **Feeds:** M0-05
**Acceptance check:** §10.2 (32 × 32 render chunking and camera culling)

## Goal

The world becomes visible, and it becomes visible *the way the design constant demands*:
≈32 × 20 tiles on screen, no player zoom, and only chunks near the camera instantiated as nodes.

## In scope

- A visual chunk node per 32 × 32 tile chunk, built from that chunk's tile data.
- **Camera culling of nodes, not data**: instantiate chunks within a small margin of the camera
  frustum, free them when they leave. Data is untouched ([§1](../../../docs/tech/world-runtime-and-persistence.md)).
- Rebuild-on-dirty: a chunk marked dirty by M0-03 refreshes its visuals, and only that chunk.
- `Camera2D` fixed so the 512 × 320 viewport shows **≈32 × 20 tiles** at 16 × 16 px art
  ([art-and-camera §3](../../../docs/tech/art-and-camera.md)). **No player zoom control.**
- Verified against the primary target, **Steam Deck 1280 × 800 at 2.5×**
  ([D-044](../../../docs/design-decisions.md)) — this is the display the chunk is signed off on.
- Aspect handling: 16:9 windows **pillarbox**. Ultrawide pillarboxes. The view never widens.
- Camera motion must be **subpixel-stable through the 2.5× upscale**: at a fractional scale a
  camera at an arbitrary float position makes the whole frame shimmer. Snap the camera to the
  virtual pixel grid, and let the shader handle the fractional step to the screen.
- **The camera's follow target, resolved the sanctioned way.** The camera is presentation, so it
  is allowed to know which actor is locally controlled ([D-045](../../../docs/design-decisions.md)):

  > Presentation may resolve the local actor. Simulation must take an actor — or a set of
  > actors — as a parameter.

  M0-06 makes control a *component*, so the derivation needs no new machinery and no global:
  the local actor is **the actor carrying the local input-control component**. A `LocalActor`
  reference living in `src/render/` is correct; a global, an autoload, a `"player"` group lookup
  or a `current_player` field is not.

  This is written down because the chunk otherwise leaves "follow what?" unanswered, and the two
  idiomatic Godot answers — `get_tree().get_first_node_in_group("player")` and
  `get_node("/root/Player")` — are both violations that M0 exists to prevent.
- A debug-only free-fly camera mode, clearly labelled, for verification.
- Debug overlay section: live chunk-node count, chunks built this frame, chunks freed this frame.

## Out of scope

Tunnel memory's four render states (M3 — this chunk draws every tile plainly). The overlay zoom
to 48 × 30, which belongs to the support overlay in M2. Any real tile art; flat colours per
`terrain_id` are correct for M0.

## Design constraints

- **The Deck is the primary target and it does not scale integrally.** 2.5× means the frame must
  be judged *in motion* — a still frame at 2.5× looks fine and a panning one does not. Every
  camera check below is a panning check.
- **Tile count is the constant, not resolution.** No display may show meaningfully more of the
  world than another. Verify on the primary target plus at least two other sizes.
- 16:9 desktops pillarbox and that is the correct behaviour, not a defect to be filed. Filling the
  extra width would mean showing more world, which §1 forbids.

## Automated checks

| Check | Expectation |
|---|---|
| chunk-node count with camera at origin | bounded, ≈ frustum area / 1024 plus margin |
| pan the camera 500 tiles and back (headless) | node count returns to the same bound, no leak |
| dirty a tile, step a frame | exactly one chunk rebuilds |

## Human verification

1. Launch the `flat` world. → You see the carved room; the rest is solid.
2. At **1280 × 800**, count tiles across the window (the debug overlay draws a tile ruler).
   → **≈32 across, ≈20 down**, filling the window with no bars.
3. **Pan the camera slowly and diagonally across the tile grid and watch the edges.** → No
   crawling, no shimmer, no rows of pixels pulsing thicker and thinner. This is the 2.5× check
   and it is the one most likely to fail; do it for a full 20 seconds, not a glance.
4. Pan again at one tile per second, then very fast. → Stable at both speeds.
5. Resize to 1920 × 1080 and to 2560 × 1600. → Tile count stays ≈32 × 20. 1080p carries ~96 px
   of pillarbox each side; 2560 × 1600 fills and is pixel-exact at 5×.
6. Make the window ultrawide (drag it very wide, or run at 21:9). → It **pillarboxes**. You do
   not see more of the world.
7. Free-fly the camera across the whole depth and back. → The chunk-node count stays roughly
   constant, never climbing with distance travelled; framerate is steady.
8. Edit a tile with the inspector while looking at it. → It changes immediately, and the overlay
   shows exactly 1 chunk rebuilt.
9. Try every zoom input you can think of (scroll wheel, +/−, gamepad sticks). → Nothing zooms.

## Exit checklist

- [ ] ≈32 × 20 tiles at 1280 × 800 and at three or more other window sizes
- [ ] Fills the Deck with no bars; 16:9 and ultrawide pillarbox
- [ ] **Stable under a slow diagonal pan** — no shimmer through the 2.5× upscale
- [ ] Camera snapped to the virtual pixel grid
- [ ] Node count bounded by the camera, not the world
- [ ] Dirty rebuild is per-chunk
- [ ] No player zoom control exists

## Discovered work

-
