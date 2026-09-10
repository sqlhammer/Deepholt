# M0-01 — Project skeleton and test harness

**Depends on:** nothing · **Feeds:** everything

## Goal

A Godot project that boots to a known virtual resolution, has a folder layout the rest of
M0 can grow into, and can run its tests headless from one command.

## In scope

- Project settings fixed to the [art-and-camera §3](../../../docs/tech/art-and-camera.md) constants:
  - **Window size 1280 × 800** — the Steam Deck, and the primary target
    ([D-044](../../../docs/design-decisions.md)).
  - Viewport (virtual) resolution **512 × 320** — 16:10 exactly, ×2.5 to the Deck.
  - Stretch mode `canvas_items`, aspect `keep` — so a 16:9 window pillarboxes rather than
    revealing more world.
  - Nearest-neighbour texture filtering, no mipmaps, no player zoom control.
  - Develop in a windowed 1280 × 800 so what you see while working is what the Deck shows.
- Source layout under `game/`:
  ```
  game/
    scenes/          .tscn files
    src/
      world/         coordinates, tile storage, depths
      render/        chunk rendering, camera
      entity/        actors and components
      sim/           clock, rate machines
      persist/       save/load, migrations
      debug/         debug overlay and dev scenes
    tests/           test scripts, mirroring src/
  ```
- **GUT** (Godot Unit Test) installed under `game/addons/gut/`, plus a
  `scripts/test.ps1` wrapper running it headless and returning a non-zero exit code on failure.
- A `scripts/check-no-player-singleton.ps1` grep check (see M0-06) wired into the same wrapper,
  failing the run if it matches. It returns clean today and must stay clean for the project's life.
  The check is **scope-aware** against the source layout above: `LocalActor` is permitted under
  `src/render/` and `src/debug/` only, because presentation may resolve the locally controlled
  actor and simulation may not ([D-045](../../../docs/design-decisions.md)). The placeholder
  version in this chunk need only run and be able to fail; M0-06 makes it real.
- One placeholder test that asserts `true`, proving the harness itself runs and can fail.
- **The pixel-art upscale shader.** 2.5× is not an integer scale: plain nearest-neighbour maps
  each source pixel to an alternating 2 px / 3 px block, and that pattern shifts as the camera
  moves, so tile edges crawl during a pan. Filter *only* at pixel boundaries (edge-antialiased
  nearest / sharp-bilinear) so interiors stay flat and edges resolve cleanly
  ([art-and-camera §3](../../../docs/tech/art-and-camera.md)).

  This is built now, not in M4. It is ~20 lines, it is the difference between the primary target
  looking finished or looking broken, and every later chunk's verification is done through it.
- `game/src/debug/debug_overlay.gd` — a toggleable (`F3`) `CanvasLayer` printing FPS and a
  section-per-system text block. Later chunks add lines to it; M0-01 just builds the frame.

## Out of scope

Any game content. Any art beyond a solid-colour test pattern. CI configuration.

## Decisions this chunk makes

- **Test framework: GUT.** Chosen because it runs headless from the command line and needs no
  build step. If you prefer gdUnit4, swap it here and nowhere else — no later chunk names GUT.
- **Debug overlay is a permanent fixture, not a temporary scaffold.** Every M0 chunk verifies
  itself through it, so it is built first and built properly.
- **The upscale shader is infrastructure, not art.** It is a consequence of a 2.5× primary
  target, so it belongs in the skeleton alongside the viewport settings.

## Automated checks

| Check | Expectation |
|---|---|
| `pwsh scripts/test.ps1` | exits 0, placeholder test passes |
| deliberately break the placeholder test, re-run | exits non-zero |
| `pwsh scripts/check-no-player-singleton.ps1` | exits 0, no matches |

## Human verification

1. Open `game/project.godot` in Godot 4.5 and press **F5**. → The game window opens, no errors
   in the Output panel.
2. Confirm the window opens at **1280 × 800** — Steam Deck size — and that the test pattern
   fills it edge to edge with **no black bars in any direction**.
3. Put a scrolling test pattern on screen (fine 1 px checks and diagonals) and pan it slowly.
   → Edges stay stable. No crawling, no shimmer, no rows of pixels visibly thicker than their
   neighbours. **This is the shader check and it cannot be done from a screenshot.**
4. Resize the window to 1920 × 1080. → It **pillarboxes** — roughly 96 px of black each side —
   and shows exactly the same amount of world. It never stretches non-uniformly.
5. Press **F3**. → The debug overlay appears with an FPS readout. Press F3 again. → It hides.
6. Run `pwsh scripts/test.ps1` in a terminal with Godot *not* open. → It completes without
   opening a window and reports 1 passing test.
7. Confirm the `game/src/` subfolders above all exist, even the empty ones.

## Exit checklist

- [ ] Project boots windowed at 1280 × 800 over a 512 × 320 viewport, `canvas_items` + `keep`
- [ ] No bars at Deck size; 16:9 pillarboxes
- [ ] Pixel-art upscale shader in place and verified by panning, not by screenshot
- [ ] Folder layout in place
- [ ] `scripts/test.ps1` runs headless, passes, and can fail
- [ ] Singleton grep check exists and is clean
- [ ] F3 debug overlay toggles

## Discovered work

-
