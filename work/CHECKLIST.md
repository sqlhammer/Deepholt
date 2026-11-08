# Slice 008 checklist

Working list for [NOW.md](./NOW.md). **Agent mode for the whole slice** (Derik, 2026-11-08), on a
`slice-008` branch: Claude builds, in small commits, the suite green before each; Derik merges the
PR and verifies by hand. Forks are taken one at a time, before the section that needs them, and
each lands as a `D-nnn`. Numbers in brackets are the brief's outcomes.

Ordered so the game runs at the end of every section: items and the pack first (nothing to see
yet but the HUD), then yields (the pack fills), then weight (you feel it), then the ladder's cost.

Slice 007's checklist is in git history (last at `76c5d8d`).

---

## A. Decided in planning

*Settled with Derik, 2026-11-08.*

- [x] Scope: yields, a weight-limited pack, the load curve, the carry HUD, a timber cost; no
  shedding and no inventory screen
  ([D-156](../docs/design-decisions.md#d-156--slice-008-is-the-pack-yields-weight-the-load-curve-and-a-timber-cost)).
- [x] 1 stone per wall for now; 2–4 ore per vein; 10 starting timber, 4 per ladder; the "dragon
  bag" randomizer deferred (D-156).
- [x] Agent mode on a `slice-008` branch, PR to `main`.
- [x] Every fork below, settled in planning as D-157 to D-159.

## B. Items and the pack

- [x] *Decide:* how items are defined. *Full schema, `.tres` per item, `ItemRegistry` (D-157).*
- [x] *Decide:* where the pack lives and how it's saved. *On each actor, in its save entry; an
  older save loads empty (D-157).*
- [x] *Decide:* the HUD's carry weight. *Bottom center, bar and number, bands marked (D-159).*
- [x] Items: stone, copper ore and timber, with the appendix's weights (content-schema §3). *In
  `content/items/`; `Item` and `ItemRegistry` in `src/entity/items/`, beside `ToolData`. The
  registry is a static class loading on first use, not an autoload (no world state, D-124).*
- [x] The pack: what an actor carries, its total weight kept current (trap 3), its capacity from
  the profile (60 kg).
- [x] A new game's first player starts with the profile's starting items (10 timber); a load
  restores the saved pack instead (trap 6). [1]
- [x] The pack round-trips through a save; an unknown item id is reported, never dropped (trap
  5). [5]
- [x] The carry weight on the HUD, for the followed actor (D-045). [1]
- [x] Tests: weights add up; capacity from the profile; save and load; an unknown id; an NPC has
  its own pack. [5, 6]
- [ ] By hand: `--new-game` shows 20 / 60 kg. [1]

## C. Yields

- [x] *Decide:* who puts a yield in the pack, and what a dirt wall yields. *The world; dirt
  nothing; uncapped; drops later (D-158).*
- [x] Yield rules in `Digging`, numbers in the profile (D-150): 1 stone per rock wall, none for
  dirt; 2–4 ore per vein, copper ore for copper.
- [x] The digging actor's pack gets the yield, never "the" player's (trap 2); a dig with no actor
  yields nothing. [2, 6, 7]
- [x] Tests: a wall, a vein's range, an NPC's dig, a dig with no actor, a second world. [6, 7]
- [ ] By hand: dig a wall and a copper vein, and watch the weight. [2]

## D. Weight you feel

- [x] *Decide:* where the 150% ladder refusal lives. *`Ladder.target_for`, shown by
  `RefusalNotice` (D-159).*
- [x] The load curve in the profile (the appendix's table), and in `Actor.speed`. [3]
- [x] Above 150%, a ladder refuses, and says why. Ramps still work (D-030). [3] *`Ladder.can_climb`
  is the rule; `Actor.interact` asks it and announces `World.climb_refused`, which
  `RefusalNotice` shows.*
- [x] Tests: speed at each band's edges; the ladder at 150% and just over; an NPC. [3, 6]
- [ ] By hand: walk empty, half, full, over; try the ladder over 150%. [3]

## E. The ladder's cost

- [x] *Decide:* who checks and takes a cost. *The fixture gatekeeper, with one rule the preview
  shares (D-159).*
- [x] The ladder's cost in the profile (4 timber); placing takes it from the requesting actor's
  pack; a placement with no actor costs nothing. [4] *One rule, `Building`, in `src/world/`, asked by
  the gatekeeper (a new `CANNOT_AFFORD` refusal) and by the cursor.*
- [x] Build mode's preview shows the cost and refuses what you can't afford, with the reason
  (ui-ux §7). [4]
- [x] Tests: placing takes the cost; can't afford is refused by both the preview and the
  gatekeeper; generation and loads place for free. [4]
- [ ] By hand: place ladders until the timber runs out. [4]

## F. Done

- [x] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
  *890 tests, 46 scripts.*
- [x] `python scripts/coverage.py` run; uncovered lines looked at (007 closed at 97.5%).
  *97.6%.*
- [ ] By hand: outcomes 1–5 walked in one sitting, launched outside the editor at least once.
- [x] Claude reviews the slice. *In the log.*
- [x] Claude writes `log/008-what-you-carry.md`.
- [x] Claude re-sketches [NEXT.md](./NEXT.md), with shedding weight as the next slice (D-156).

---

### Not in this slice, worth knowing

- **Dropping, discarding and picking up** (D-156): the next slice. Drops for yields that don't
  fit, picked up from adjacent tiles up to 150%, are the model ahead (D-158).
- **The inventory screen** with per-item weight and sort by value density (ui-ux §5).
- **The "dragon bag" yield randomizer** (D-156).
- **Climb-time multipliers** (appendix §2): ladders are instant, so there's nothing to slow.
- **Smelting, ingots and other ores** (D-031): no stations yet.
