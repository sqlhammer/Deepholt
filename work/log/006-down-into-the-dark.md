# 006 — Down into the dark

*Written by Claude, 2026-11-08.*

> Start a new game and only the Surface and −1 exist; each level appears as someone first
> reaches the one above it. Underground, the screen is black past what you can sense, your own
> tunnels stay drawn where you've been, and a brazier in the home cave shows what light is for.

**Result:** built across three modes on `main`. Derik built section B's generator entry points
in Educational Assistant mode (`e6e61a3`). Claude finished B in Agent mode at his request
(`7c9e32e`), then built C and D in Agent mode (`59f48b5`), stopping for each decision. The suite
passes: 810 tests in 41 scripts, no skipped files, no leak warning. Coverage is 97.4% (005
closed at 97.5%). **None of the by-hand outcomes have been walked.** Claude never launched the
game, because a launch reads, writes and prunes the real save slot. This log was written before
anyone saw the dark on screen.

---

## What got decided

Seven decisions, D-143 to D-149, and one content call. All of them were Derik's, put to him
one at a time:

- **Levels are generated one ahead of any actor's arrival, by the world, on the main thread.**
  A load builds only what its save holds, then generates each actor's level below after the
  swap (D-143).
- **The dark's scope:** all four render states, a brazier for light, the Surface lit (D-144).
- **Senses flood through open space.** The followed actor's flood draws the screen; every
  player's marks memory, set by the world directly (D-145).
- **One state byte per tile, built in GDScript.** Sensed is grey, Remembered darker grey
  (D-146).
- **Memory is a saved-only layer of bit flags.** `SAVED_ONLY_LAYERS` keeps an old save "whole"
  (D-147).
- **Other actors are hidden in the dark, and fixtures dimmed with their tile** (D-148).
- **Light floods like the senses, on or off per tile** (D-149).
- **A second brazier on −2, by Greyseam's copper,** so lit and unlit copper can be compared.
  −1 stays copper-free, as a test pins. Derik chose this over Claude's first attempt, which
  added copper to −1.

**Choices made while building, not put to Derik.** He may want to look at these:

- **A presentation node, `Visibility`, owns the state bytes.** The level renderer, the fixture
  renderer and the view all read it, so the rule runs once per change. The view has a
  `visibility` property and a new `followed_moved` signal.
- **`Senses` and `Light` live in `src/world/`** as stateless functions. Simulation will want
  light later (ore identification, crafting speed), and memory needs the flood now.
- **A player is sensed when it's added to the world,** not only on a step. A new game's first
  tiles are remembered at once, and a load marks memory around each loaded player.
- **A brazier conflicts with ladders, spawns and other braziers** on its tile.
- **The brazier's light radius is 6.** Derik set the sense radius (7) and the two brightnesses
  (1.0 and 0.35).
- **Ore in the dark draws copper's art in grey,** because copper is the only ore with art. A
  shader uniform (`unknown_ore_cell`) is the hook for a real "unknown ore" cell when a second
  ore arrives.
- **`LevelGenerator.problems_between(upper, lower)`** checks a newly generated pair. Ramps skip
  a missing other level; ladders still report a missing level above.
- **Hand-built test worlds now include a blank −2,** because an arrival on −1 generates the
  real −2 under a blank −1, and the cross-level check rightly fails.

---

## What surprised

**Two save-format traps were in plain sight.** `TILE_LAYERS` doubled as the "is this level
whole?" rule, so adding memory there would have made every older save regenerate its levels,
with fixture ids drifting and nothing failing. It was caught while writing C's lesson, before
any code. D-147 settled it.

**The fast path for the state bytes came from a coincidence of encodings.** With "remembered"
as bit 0 and Remembered as state 1, the state build is a native copy of the memory layer plus
a few hundred writes. On the largest level (415 x 415 tiles) the build takes 0.02 ms and the
flood 0.06 ms. A per-tile GDScript loop would have been tens of milliseconds every step. D-147
made memory bit flags, so the copy is correct only while bit 0 is the only bit used. The code
says to mask it when another bit arrives.

**Godot shaders can't return early from `fragment()`.** The first shader did, and failed
thirty tests through engine errors. The Unknown state is now the default color, with everything
else inside an `if`.

**(Claude) GUT skipped a new test file, and the suite reported green.** A `WorldPos` declared as
a `const` doesn't parse, so `test_first_descent.gd` was ignored. It was caught by reading the
run for "Ignoring", the trap every log since 002 names. Earlier, two of Derik's edits had
broken parsing in a shared test helper, which silently removed six files from the run. Claude
found that the same way.

**(Claude) Claude changed level design without asking.** Copper was added to −1 for outcome 5,
and a test that pinned "Rootshelf has no copper" caught it. The question then went to Derik,
who chose a second brazier on −2 instead.

**(Claude) A stray test helper leaked a whole game scene.** A first draft of a renderer test
instantiated `game.tscn` to borrow its renderer, and never freed the rest. It was rewritten
before any run.

---

## What to do differently

1. **When a list or constant gains a member, read every place that iterates it.** That's how
   the `TILE_LAYERS` trap would have been found, if it hadn't come up in the lesson.
2. **(Claude) Treat a pinned test as a decision, not an obstacle.** "Rootshelf has no copper"
   was a choice someone made. Ask before changing what a test pins.
3. **(Claude) Write throwaway helpers into the scratchpad, never into the tree.** The timing
   test was deleted, but it shouldn't have been in `tests/` at all.
4. **Measure the per-step cost the first time something runs every step.** It took one
   throwaway test to settle trap 5, and it's now in F3's "Dark" line for anyone to watch.

---

## Open, carried forward

- **By hand, for Derik: every outcome.** B's: `--new-game`, walk down to −2 and −3, save on −1
  and relaunch. C's: black past the ring, grey within it, a darker tunnel behind you, still
  there after a relaunch. D's: the brazier on −1, lit copper and dark copper by Greyseam's
  brazier on −2, the Surface, and how a hole and the fade read in the dark.
- **The GPU upload of the state texture wasn't measured.** It can't be measured headless. F3's
  "Dark" line shows the CPU rebuild; a by-hand walk on −7 would show whether the upload is
  felt.
- **`hardness_of` and `dig_hardness` put a digging rule on the tuning profile.** Derik asked why
  they're there. Whether the rule moves beside digging is his call.
- **Lit tiles aren't remembered** unless a player also senses them. Nothing needs them to be
  yet.
- **005's by-hand items** were never reported walked.

---

## Closed

*Added by Claude, 2026-11-08, when the slice was closed.*

Derik walked the by-hand outcomes, and the slice is closed. One thing came out of the walk:
the Sensed ring read like normal lighting, so there was little reason to want a torch. The
two greys were retuned by eye, Sensed 1.0 → 0.5 and Remembered 0.35 → 0.2 (`4662c9f`). A fade
toward the ring's edge, low detail (D-010's "low-detail monochrome") and warmer light were
offered and not taken for now.
