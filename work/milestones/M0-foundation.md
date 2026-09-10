# M0 — Foundation

> **Exit:** the six checks in [world-runtime §10](../../docs/tech/world-runtime-and-persistence.md)
> pass — including **no `Player` singleton anywhere in the codebase** and a rate machine
> accruing correctly across save/load.

## Why this milestone exists

M0 builds nothing a player would recognise as a game. It builds the two things that are
expensive to retrofit and free to get right now ([pre-alpha-scope §7](../../docs/pre-alpha-scope.md)):

1. **The actor-agnostic entity model** — no `Player` singleton, capabilities as components,
   so the deferred worker layer and co-op need no changes here ([D-004](../../docs/design-decisions.md)).
2. **The shared coordinate origin** — `(x, y)` on one depth is directly below `(x, y)` on the
   depth above, which is what makes shafts, chutes, driveshafts and the whole M5 thesis
   spatially real.

Everything else in M0 exists because those two need a world to live in, and because the
**rate machine** (§5) is the mechanism by which a hoist hauls ore while the player is three
levels away. If M0's accrual is wrong, M5 cannot be judged.

## Acceptance checks → chunks

| # | Check ([§10](../../docs/tech/world-runtime-and-persistence.md)) | Chunks |
|---|---|---|
| 1 | Eight depths with shared-origin coordinates and a display/internal mapping function | M0-02, M0-05 |
| 2 | Tile arrays resident for all depths, 32×32 render chunking, camera culling | M0-03, M0-04 |
| 3 | Support and light recompute from scratch on load | M0-08, M0-09 |
| 4 | An `Actor` with components, and no `Player` singleton anywhere | M0-06 |
| 5 | Save/load round-trips a modified world, `format_version` + one no-op migration | M0-09 |
| 6 | A rate machine accrues correctly across save/load and across level changes | M0-07, M0-09 |

M0-10 is the sign-off pass that runs all six end to end.

## Dependency order

```
M0-01 skeleton
   └─ M0-02 coordinates
        ├─ M0-03 tile storage ── M0-04 render + camera ── M0-05 depth switching
        ├─ M0-06 actors
        └─ M0-07 clock + rate machines
             └─ M0-08 derived fields ── M0-09 save/load ── M0-10 acceptance
```

M0-06 and M0-07 are independent of the render path and can be worked in parallel with
M0-04/M0-05 if two people are on it.

## Deliberately not in M0

Procgen (M3), digging (M1), the support *rule* (M2), light *sources* (M3), water and chambers
(out of pre-alpha entirely — [§4](../../docs/pre-alpha-scope.md)), generation threading
(M3 — M0 uses hand-made debug worlds), and any UI beyond debug readouts.

M0-08 builds the *pipeline* that recomputes support and light on load, with placeholder rules.
That is not a stub of a deferred system — it is the load-order guarantee §3 demands, and M2/M3
drop real rules into it without touching the plumbing.
