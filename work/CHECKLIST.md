# Slice 009 checklist

Working list for [NOW.md](./NOW.md). **Agent mode for the whole slice** (Derik, 2026-11-08), on a
`slice-009` branch: Claude builds, in small commits, the suite green before each; Derik merges the
PR and verifies by hand. Every fork was settled in planning. Numbers in brackets are the brief's
outcomes.

Ordered so the game runs at the end of every section: drops first (something on the ground),
then yields that overflow into them, then pickup and the take key, then the inventory.

Slice 008's checklist is in git history (last at `0f34fe3`).

---

## A. Decided in planning

*Settled with Derik, 2026-11-08.*

- [x] Scope, fill to 100%, the take key, the overlay
  ([D-160](../docs/design-decisions.md#d-160--slice-009-is-letting-go-drops-dropping-pickup-to-100-a-take-key-an-inventory-overlay)).
- [x] Drops through the world, per level, saved, never decaying; drawn like actors (D-161).
- [x] The inventory doesn't pause (D-162).
- [x] Agent mode on a `slice-009` branch, PR to `main`.

## B. Drops

- [x] A per-level store of drops: item stacks by tile, the same item merging, announcing changes
  (trap 2).
- [x] Drops are saved with their level; a load reports a drop with an unknown item or outside its
  level, never dropping it silently (trap 5). [6]
- [x] The world's drop request moves items from an actor's pack onto its tile. [4, 7]
- [x] Drops are drawn: a small placeholder sprite per item (Claude), shown only on Sensed or Lit
  tiles (D-161). [5] *`DropRenderer` draws a colored square per item, up to four to a tile.*
- [x] Tests: merging, saving and loading, a drop request, the dark. [5, 6, 7]

## C. Yields that overflow

- [x] One rule for how much fits under a load limit (trap 1), in `Carrying`.
- [x] A dig's yield fills the digger's pack to 100%, and the rest drops at the dug tile, a stack
  split if only part fits (D-160). [1, 8]
- [x] Tests: a full pack, a partial fit, an NPC digger, no actor. [1, 8]

## D. Pickup and the take key

- [x] Auto-pickup: a player, on each tile step, takes drops from its own and the 8 adjacent
  tiles, up to 100%; the rest stays; NPCs never pick up. Through the world (D-161). [2, 7]
- [x] What you just dropped isn't picked straight back up (trap 3).
- [x] A load restores drops without anyone picking them up (trap 4).
- [x] The take key takes everything in reach, whatever the load. [3]
- [x] Bindings: take `T` / pad LB (trap 6).
- [x] Tests: the 100% limit, the reach, an NPC, the take key past 150%, a load. [2, 3, 7]

## E. The inventory overlay

- [x] Tab / pad Menu toggles it; walking works, digging, breaching and building don't (D-162).
- [x] The pack's items with their weights, sorted by value density (ui-ux §5).
- [x] Drop one (`X` / pad A) and drop the stack (`Z` / pad X), only while it's open (trap 6). [4]
- [x] Tests: the sort, dropping one and a stack, the keys doing nothing else while open. [4]

## F. Done

- [x] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
  *909 tests, 47 scripts.*
- [x] `python scripts/coverage.py` run; uncovered lines looked at (008 closed at 97.6%).
  *97.6%.*
- [ ] By hand: outcomes 1–6 walked in one sitting, launched outside the editor at least once.
- [x] Claude reviews the slice. *In the log.*
- [x] Claude writes `log/009-letting-go.md`.
- [x] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Not in this slice, worth knowing

- **Drops that decay** (D-160): never, for now.
- **The "dragon bag" yield randomizer** (D-156).
- **A take-this preview on the ground** (ui-ux §5): the take key takes everything; choosing what to
  take waits for a better inventory.
- **Containers and chutes** that would hold or move drops.
