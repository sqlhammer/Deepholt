# Slice 012 checklist

Working list for [NOW.md](./NOW.md). **Agent mode for the whole slice** (Derik, 2026-11-09), on a
`slice-012` branch: Claude builds, one or more commits per section, the suite green before each;
Derik merges the PR and verifies by hand. Numbers in brackets are the brief's outcomes.

Ordered so the game runs at the end of every section: the small changes first (R, ladders), then
the axe and trees (a reason to be on the Surface), then the Surface itself, then what's below.

Slice 011's checklist is in git history (last at the 011 close).

---

## A. Decided in planning

*Settled with Derik, 2026-11-09.*

- [x] Scope (D-179).
- [x] The Surface: meadow, rock, road through a cut to the ramp, from the seed (D-180).
- [x] Trees: a fixture, axe only, timber (D-181).
- [x] The axe; axe, pick, shovel, no timber (D-182).
- [x] Copper and tin in small veins at tunable shares (D-183), on −2 only (D-187).
- [x] Two or more hand-made caves per level, placed by seed (D-184).
- [x] No preloaded ladders (D-185).
- [x] R halved, rounding up (D-186).
- [x] The numbers in the brief, approved with it.

## B. Small changes

- [x] R table 0, 4, 4, 3, 3, 2, 2, 2; support tests follow. [5]
- [x] Greyseam's ladder removed; tests that climbed it build their own. [4]

## C. The axe and trees

- [x] A flint axe item and tool class, its multipliers; the starting kit. [2]
- [x] A TREE fixture kind: blocks walking, placeholder art, a renderer texture.
- [x] Chopping: the primary action facing a tree; axe only, refused otherwise; work in the
  profile; the world fells it and yields timber, overflowing to the ground. [2]
- [x] Tests: chop time, yield, refusal, overflow, a felled tree's tile is walkable. [2]

## D. The Surface

- [x] Generation steps, in order: meadow ground, rock disc and quarter, the road and its cut,
  dirt patches, the spawn, trees (trap 1). [1, 3]
- [x] Tests: road open to the ramp, spawn on the road, trees off the road and rock, the quarter,
  same seed same Surface, another seed another. [1, 3, 6]

## E. Ores and caves

- [x] Tin: ore id, item, icon. [4]
- [x] Cave prefabs (five shapes) and their placement: 2–3 per level, sealed, apart (trap 4). [4]
- [x] Veins by share into −2's minable rock; none on −1 (trap 4, D-187). [4]
- [x] Tests: −2's shares near the profile's, −1 still has no ore, caves sealed and apart, caves
  never judged. [4, 6]

## G. A sharp HUD and the window (added 2026-11-10)

- [x] The HUD at a whole-number scale, on a frame over the game picture of at least 576 × 360
  (D-188). [7]
- [x] Press Start 2P at 8 px, imported without anti-aliasing, hinting or sub-pixel positions;
  its license beside it (D-189). [7]
- [x] 32 px cells and slots, six grid rows shown with scroll arrows, bare weights, wrapped words;
  the weight bar and refusals hide under the open inventory (D-190). [7]
- [x] Exclusive full screen at launch; F11 to a window and back (D-191). [7]
- [x] Tests: the scale is whole and the frame never under 576 × 360 on common screens; the font
  imported sharp; the board fits the smallest frame; wrapping; the F11 modes and window size.
- [x] Screenshots taken from the running game at 1280 × 800 and 1920 × 1080.

## F. Done

- [x] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
- [x] `python scripts/coverage.py` run; uncovered lines looked at (011 closed at 96.1%).
- [ ] By hand: outcomes 1–5 walked in one sitting, launched outside the editor at least once.
- [x] Claude reviews the slice.
- [x] Claude writes `log/012-a-world-worth-digging.md`.
- [x] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Not in this slice, worth knowing

- **Regrowing trees,** coal and iron, −1's own resources, caves below −2.
- **A real tree sprite** and real ore icons: placeholders, as before.
