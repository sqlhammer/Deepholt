# M0-08 — Derived-field recompute pipeline

**Depends on:** M0-03 · **Feeds:** M0-09
**Acceptance check:** §10.3 (support and light recompute from scratch on load)

## Goal

Guarantee, structurally, that support state and light level are **never trusted from a save file**
— so a future tuning change to R cannot silently leave old worlds structurally wrong.

## In scope

- A `DerivedField` registry: each entry declares its backing array, an `invalidate_all()`, and a
  `recompute(region)` that runs from the dirty set across frames.
- Two registered fields, `support_state` and `light_level`, with **placeholder rules** for M0:
  - support: `STABLE` everywhere,
  - light: `0` everywhere.
  M2 and M3 replace the rule bodies and touch nothing else.
- Dirty-driven recompute: a tile edit marks dirty within `R_max + 2` of the change and the
  pipeline processes the dirty set across frames with a per-frame budget
  ([§3](../../../docs/tech/world-runtime-and-persistence.md)).
- A `recompute_all_from_scratch()` entry point that M0-09 calls on load, before any gameplay runs.
- A **poison test hook**: a debug command that writes garbage into the derived arrays. If a later
  chunk ever starts trusting them, this test fails loudly.
- Debug overlay: dirty-set size, tiles recomputed last frame, per-frame budget used.

## Out of scope

The real support rule, depth-scaled R, Stable/Marginal/Failing, collapse (all M2). Light sources,
dark vision, ore-ID gating (all M3). Chambers and connectivity — water is out of pre-alpha.

## Design constraints

- Support state is **computed, not authored**. There is no code path anywhere that sets it from
  a file, a generator, or a designer.
- The two placeholder rules are not stubs of deferred systems; they are the trivial correct
  answer for a world with no support rule and no light sources yet.

## Automated checks

| Check | Expectation |
|---|---|
| edit one tile | dirty region covers `R_max + 2` around it, no more |
| dirty 10,000 tiles | processed across multiple frames, per-frame budget respected |
| poison the arrays, call `recompute_all_from_scratch()` | arrays return to correct values |
| poison the arrays, then read them without recomputing | test fails (proves the hook detects trust) |
| `recompute_all_from_scratch()` on all 8 depths | completes, timed and reported |

## Human verification

1. Load the `flat` world, press F3. → Dirty set is 0 and derived-field values are the placeholder
   values everywhere.
2. Edit a tile with the inspector. → The dirty count jumps by roughly the `R_max + 2` area, then
   drains to 0 over the next few frames. Framerate does not stutter.
3. Run the debug **poison** command and inspect a few tiles. → They show garbage.
4. Run **recompute all**. → Those tiles return to correct values, and the overlay reports the
   time it took for all eight depths.
5. Confirm by reading the code that nothing writes `support_state` or `light_level` outside the
   pipeline.

## Exit checklist

- [ ] Registry with two fields and swappable rule bodies
- [ ] Dirty-set recompute, budgeted across frames
- [ ] `recompute_all_from_scratch()` exists and is fast enough to call on every load
- [ ] Poison hook in place and proven to catch trust
- [ ] No write path to derived fields outside the pipeline

## Discovered work

-
