# M0-07 — Game clock and rate machines

**Depends on:** M0-02, M0-05 · **Feeds:** M0-09, M0-10
**Acceptance check:** §10.6 (a rate machine accrues correctly across level changes)

## Goal

Build the mechanism the whole M5 thesis depends on: **a powered hoist keeps hauling while you
are three levels away**, without anything ticking off-screen.

## In scope

- A monotonic `game_time` tick source, paused with the game, saved in the header.
- `RateMachine`: stores `rate`, `power_ratio`, `last_evaluated_tick`, and an accumulated output
  buffer. Output is computed **lazily**:
  ```
  produced = rate × power_ratio × (now − last_evaluated_tick)
  ```
  evaluated when queried, when an actor arrives on that machine's depth, or when its power
  network changes — **never on a per-frame tick**.
- A power-network event hook: any event that changes `power_ratio` re-evaluates the affected
  machines and stamps a new `last_evaluated_tick` before the ratio changes. This ordering is the
  whole correctness argument — evaluate first, then change the ratio.
- Wind fixed at **1.0** ([pre-alpha-scope §4](../../../docs/pre-alpha-scope.md)), as a named
  constant with a comment pointing at the stepped-value constraint below.
- A debug test machine placeable at a `WorldPos`, with an output readout in the overlay.
- Debug time controls: step N ticks, and a large jump, to test long intervals without waiting.

## Out of scope

Windmills, driveshafts, line shafts, hoists, brownout — all M5. Crops (M6). This chunk builds the
accrual *mechanism* and one debug machine, nothing that appears in the game.

## Design constraints

- **Nothing ticks off-screen.** If you find yourself adding a machine to a `_process` list, the
  design has been lost ([§5](../../../docs/tech/world-runtime-and-persistence.md)).
- Accrual is **exact, not approximate**, provided `power_ratio` is constant across the interval.
  In pre-alpha it is, because wind is fixed and the player can only build on the level they occupy.
- When variable weather arrives, wind must be a **stepped** value changing on discrete events, or
  accrual stops being exact. That is a design constraint on the weather system, decided in §5 —
  record it as a comment where the wind constant lives.
- Creatures, crops and fauna on other levels are **frozen**. Nothing that can threaten an actor
  runs where an actor cannot see it.

## Automated checks

| Check | Expectation |
|---|---|
| machine at rate 2/tick, advance 100 ticks, query once | output exactly 200 |
| query 10 times during those 100 ticks | still exactly 200 total, no double-count |
| ratio 1.0 for 50 ticks then 0.5 for 50 | exactly 150, with the re-evaluation stamped at the change |
| a machine on a depth with no actor for 1000 ticks | accrues exactly, and appears in no per-frame list |
| profiler / frame-time with 100 machines idle | indistinguishable from 0 machines |

## Human verification

1. Place a debug machine at rate 1/tick on depth −3 and note the tick count.
2. Travel to Surface, wait 60 seconds of game time, return to −3. → Output equals the elapsed
   ticks. Nothing was lost and nothing was invented.
3. Halve `power_ratio` mid-run using the debug control, wait, restore it. → The total matches
   hand arithmetic across the three intervals. Do this one by hand, on paper.
4. Place 100 debug machines and watch the FPS readout. → Unchanged from the same scene with none.
5. Use the large time-jump control for a simulated hour. → Output scales exactly; no drift, no
   overflow, no hitch.

## Exit checklist

- [ ] Lazy accrual only; no machine appears in any per-frame update
- [ ] Ratio changes evaluate-then-stamp, in that order
- [ ] Correct across level changes
- [ ] Wind fixed at 1.0, with the stepped-weather constraint recorded in the code
- [ ] 100 idle machines cost nothing measurable

## Discovered work

-
