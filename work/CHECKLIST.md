# Slice 007 checklist

Working list for [NOW.md](./NOW.md). **Agent mode for the whole slice** (Derik, 2026-11-08), on a
`slice-007` branch: Claude builds, in small commits, the suite green before each; Derik merges the
PR and verifies by hand. Forks are taken one at a time, before the section that needs them, and
each lands as a `D-nnn`. Numbers in brackets are the brief's outcomes.

Ordered so the game runs at the end of every section: the breach first (a hole you can make and
see), then the build mode and cursor (something to point with), then placing and using a ladder.

Slice 006's checklist is in git history (last at `701740b`).

---

## A. Decided in planning

*Settled with Derik, 2026-11-08.*

- [x] Scope: breach a floor and place a ladder, free of cost; items, inventory and the wood
  cost come later, and build mode is shaped to take a cost.
- [x] Agent mode on a `slice-007` branch, PR to `main`.
- [x] Every fork below, settled in planning as D-150 to D-154.

## B. Breach

- [x] *Decide:* what a floor's hardness is. *Its level's (D-151).*
- [x] *Decide:* what's beneath a breach. *The breach clears the landing (D-152).*
- [x] *Decide:* how you breach. *Its own input, held facing the floor, `R` / pad `X` (D-153).*
- [x] *Decide:* which tiles can be breached. *Plain open floor, both ends clear (D-152).*
- [x] `Digging`, a static class in `src/world/` taking the profile: the dig rules move off
  `TuningProfile` (`hardness_of`, `dig_hardness`), and the breach rules join them (D-150).
- [x] Breach numbers in the profile: the floor hardness per depth, the time multiplier (×8) and
  the gate (×1.2) (D-151).
- [x] A breach request on the world's tile gatekeeper, with its own refusal reasons and outcome,
  applied whole or not at all (trap 1). Refused: under-tier, outside the level, the deepest
  level, not open floor, a tile someone stands on (trap 2). [6]
- [x] The breach capability: progress at `breach_seconds`, reset like a dig. [1]
- [x] Refusals are shown to the player (the first reader of a refusal reason, D-141's
  "feedback"). *`RefusalNotice`: the followed actor's refusal, for 2.5 s at the bottom of the
  screen.*
- [x] The temporary Surface hole comes out of `surface_start`, and the tests that read it move
  (D-140, trap 7). [5]
- [x] Tests: each refusal; the time with flint on the Surface, −1 and −2; an NPC breaches; a
  second world is untouched. [6, 8]
- [ ] By hand: breach −1's floor; try −2's. [1]

## C. Build mode and the anchored cursor

- [x] *Decide:* the controls. *As ui-ux says: `E` / `Y`, cursor on mouse or right stick,
  primary places (D-154).*
- [x] *Decide:* where a ladder is aimed. *At a hole on your level, Sensed or Lit only
  (D-154).*
- [x] The cursor's radius is a profile number (about 5).
- [x] Build mode in presentation, per local player (D-045): a grid cursor clamped around the
  character, mouse and stick with the same reach, snapping tile to tile (ui-ux §2.1).
- [x] Valid and invalid shown by shape and icon as well as color (ui-ux §7), from the same
  placement rules the gatekeeper enforces, so the preview can't disagree with the outcome. On
  Remembered or Unknown tiles, invalid with the reason (D-154).
- [x] The new bindings in `project.godot` and in ui-ux's control tables: breach `R` / `X`,
  build mode `E` / `Y`. *Build mode is `B`, since `E` is interact; breach holds pad X until
  tools can be swapped
  ([D-155](../docs/design-decisions.md#d-155--build-mode-is-b-on-the-keyboard-breach-holds-pad-x-until-tools-can-be-swapped)).*
- [x] What toggling build mode does to a held dig, a held breach, the fade and F5/F6 (trap 5).
  *Entering build mode stops a held dig and breach; the fade pauses input as before; F5 and F6
  are unaffected; a world swap turns build mode off. ui-ux §7's dimming and grid, the pad's B
  to leave, and the cursor's audible tick aren't built.*
- [x] Tests: the clamp; mouse and stick reach the same tiles; the preview matches the rules. [2]
- [ ] By hand: toggle it, move it with both inputs, read it in the dark. [2]

## D. Placing and using a ladder

- [x] Primary action in build mode requests a ladder on the world's fixture gatekeeper, as
  decided; a refusal is shown (trap 4). [3]
- [x] The ladder is drawn on the level below, and its top in the hole above, at once (trap 3).
  [3, 7]
- [x] The world's fixture id counter carries on across a save and load (D-130, trap 3). [4, 7]
- [x] Tests: a placed ladder climbs both ways; it's saved and loaded; ids carry on; an NPC and
  a second world. [7, 8]
- [ ] By hand: breach, place, climb down to −2 and back, save, relaunch. [3, 4]

## E. Done

- [x] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
  *846 tests, 43 scripts.*
- [x] `python scripts/coverage.py` run; uncovered lines looked at (006 closed at 97.4%).
  *97.5%.*
- [ ] By hand: outcomes 1–5 walked in one sitting, launched outside the editor at least once.
- [ ] Claude reviews the slice.
- [ ] Claude writes `log/007-dig-your-own-way-down.md`.
- [ ] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Not in this slice, worth knowing

- **Items, spoil and a weight-limited inventory** (M1). A ladder's wood cost waits for them.
- **Removing a placed ladder** (the hammer, ui-ux §7).
- **Ghost (blueprint) placement** (ui-ux §7), which only matters once things cost something.
- **The hotbar and radial menu** (ui-ux §2.2): one buildable item doesn't need them.
- **Other tools than flint**: bronze is what breaches −2. Until tools can be found or made, −2's
  floor stays shut, which is the tool gate working.
