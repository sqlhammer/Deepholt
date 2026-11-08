# Slice 010 checklist

Working list for [NOW.md](./NOW.md). **Agent mode for the whole slice** (Derik, 2026-11-08), on a
`slice-010` branch: Claude builds, in small commits, the suite green before each; Derik merges the
PR and verifies by hand. Every fork was settled in planning. Numbers in brackets are the brief's
outcomes.

Ordered so the game runs at the end of every section: the rule and the overlay first (you can see
what's safe), then props (you can fix it), then the countdown (it matters), then collapse.

Slice 009's checklist is in git history (last at the 009 close).

---

## A. Decided in planning

*Settled with Derik, 2026-11-08.*

- [x] Scope: the rule, the countdown, collapse and clearing, props, the overlay
  ([D-163](../docs/design-decisions.md#d-163--slice-010-is-holding-it-up-the-support-rule-collapse-timber-props-the-overlay)).
- [x] Only excavated tiles are judged (D-164).
- [x] Props: a fixture, 2 timber, blocks its tile (D-165).
- [x] Rubble: a top kind, cleared like a dig, no yield; 45 s with cracks and a notice (D-166).
- [x] Agent mode on a `slice-010` branch, PR to `main`.

## B. The support rule and the overlay

- [ ] The "excavated" bit in memory's flags (D-147, D-164), set by digs and breaches (both the
  dug tile and a breach's landing), saved with memory. [7]
- [ ] R by depth in the profile (the doc's table); a support rule (`Support`, static, taking the
  profile): Stable, Marginal, Failing per excavated tile; supports are solid non-rubble tiles and
  props (D-163). [1, 7]
- [ ] Each level keeps its derived states, recomputed in a window around a change (traps 1, 2).
- [ ] The overlay: `V` / L3 tints excavated tiles green, amber, red, for the shown level. [6]
- [ ] Tests: a 2-wide tunnel never fails at any depth; a room 2R+2 wide fails in its middle; R
  falls with depth; natural caves never judged; a dig far away changes a state; an NPC. [1, 7]

## C. Timber props

- [ ] A `PROP` fixture kind: a placeholder sprite, blocks walking, a support (D-165).
- [ ] Its cost in the profile (2 timber), through `Building` (D-159).
- [ ] Build mode's second item: `1` / `2` pick ladder or prop, RB cycles; the preview uses the
  gatekeeper's rule for each.
- [ ] The quick key (`F` / D-pad ↓): at the cursor in build mode, else the faced tile.
- [ ] Tests: a prop restores support; it costs 2 timber; it blocks walking; the quick key. [2]

## D. The countdown

- [ ] A failing region's countdown, 45 s in the profile, ticking only in a running world (trap
  5); regions that grow, shrink and split keep the oldest time (trap 3). [1, 2]
- [ ] Saved with its level, resumed on load. [5]
- [ ] The warning: cracks in three stages on failing tiles, and a notice; Marginal shows nothing
  but amber in the overlay. [1]
- [ ] Tests: a prop cancels it; it resumes after a load; it doesn't tick during a load; a split
  region. [2, 5]

## E. Collapse and rubble

- [ ] A `RUBBLE` top kind: solid, not a support, not open to the flood, diggable at the profile's
  rubble hardness (about 0.4 s with flint), yields nothing, a placeholder atlas cell (trap 6).
- [ ] A countdown that ends fills its region with rubble through the world's tile gatekeeper;
  anyone caught is moved to the nearest open tile, with a notice (D-163). [3]
- [ ] What's under rubble is buried: fixtures and drops kept and saved, hidden and unusable until
  cleared; a buried brazier gives no light (trap 4). [4]
- [ ] Tests: collapse fills the region; an actor is moved; a ladder and a drop come back after
  clearing; clearing yields nothing; rubble isn't a support. [3, 4]

## F. Done

- [ ] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
- [ ] `python scripts/coverage.py` run; uncovered lines looked at (009 closed at 97.6%).
- [ ] By hand: outcomes 1–6 walked in one sitting, launched outside the editor at least once.
- [ ] Claude reviews the slice.
- [ ] Claude writes `log/010-holding-it-up.md`.
- [ ] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Not in this slice, worth knowing

- **The upward cascade and reinforced floors** (cut from pre-alpha).
- **Cut stone, iron-braced and ancestral columns** (their R bonuses).
- **Damage and stun from a collapse**, which need health.
- **The overlay's rings and ghosted suggestions** (digging-and-structure §4).
- **Sound** for the countdown.
