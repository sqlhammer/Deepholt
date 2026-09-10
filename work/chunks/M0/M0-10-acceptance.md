# M0-10 — M0 acceptance sign-off

**Depends on:** M0-01 … M0-09

## Goal

Run the six checks in [world-runtime §10](../../../docs/tech/world-runtime-and-persistence.md)
end to end, in one sitting, on a clean checkout — and either exit M0 or say plainly which chunk
reopens.

This is a chunk, not a formality. Each preceding chunk verified itself in isolation; this one
verifies they hold **together**, which is where foundations usually fail.

## In scope

- A clean-clone run: fresh clone, open in Godot, run tests, run the session below. No local
  state, no leftover saves, no editor cache.
- One combined session exercising all six checks in sequence.
- The completed sign-off log at `work/verification/M0/M0-10-acceptance.md`.
- A short **carry-forward note** in the log: anything M1 must know about, and anything listed in
  a chunk's *Discovered work* that has not been resolved.

## The six checks

| # | Check | How it is exercised in the session below |
|---|---|---|
| 1 | Eight depths, shared origin, display/internal mapping | steps 3–4 |
| 2 | Tile arrays resident, 32 × 32 chunking, camera culling | steps 2, 5 |
| 3 | Support and light recompute from scratch on load | step 8 |
| 4 | `Actor` with components, **no `Player` singleton anywhere** | steps 6, 10 |
| 5 | Save/load round-trips a modified world, versioned + one migration | steps 7–9 |
| 6 | Rate machine accrues across save/load and level changes | steps 7, 9 |

## Human verification — the combined session

1. Fresh-clone the repo, open `game/project.godot` in Godot 4.7, run `pwsh scripts/test.ps1`.
   → All tests pass, including the singleton check.
2. Launch **at 1280 × 800**, Steam Deck size and the primary target. Load the `shaft` world.
   Press F3. → Eight depths resident, ≈4 MB, ≈32 × 20 tiles visible, filling the window with no
   bars. Pan slowly for 20 seconds → no shimmer through the 2.5× upscale.
3. Put the crosshair on the shaft and step Surface → −7. → The column is under the crosshair on
   every depth; the depth readout reads `Surface, −1 … −7`.
4. Move off-axis, step depths again. → `(x, y)` never drifts.
5. Free-fly across a full depth. → Chunk-node count stays bounded; framerate steady.
6. Spawn two controllable actors and one without `Inventory`. Drive each in turn. Move one to a
   different depth. → All three tracked; component queries correct.
7. Dig a recognisable shape on −2. Place a rate machine on −3. Travel to Surface, wait, return.
   → Machine output matches elapsed ticks.
8. Save. Quit the process. Relaunch. Load. → World, actors and machine restored. Derived fields
   recompute on load (confirm via the overlay's recompute timing line, and by poisoning before save).
9. Check machine output, run 30 more seconds, save/load once more. → Totals match hand arithmetic.
10. Search the codebase for `get_player` and `Player`. → Nothing but the check script.

## Exit criterion

**M0 exits when all ten steps pass in a single session on a clean clone**, and the log is
committed. Any failure reopens the owning chunk; do not patch around it here.

## Exit checklist

- [ ] Clean-clone run completed
- [ ] All six §10 checks passed
- [ ] Sign-off log committed with a name and a date
- [ ] Carry-forward note written for M1
- [ ] `STATUS.md` updated; M1 breakdown started

## Discovered work

-
