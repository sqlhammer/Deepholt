# 010 — Holding it up

*Written by Claude, 2026-11-08.*

> Dig out a room wider than the rock can span and the ceiling starts to crack. You have
> forty-five seconds to set a timber prop, or the room fills with rubble. Narrow tunnels never
> fail; the deeper you go, the narrower "wide" becomes.

**Result:** built in Agent mode on the `slice-010` branch. The suite passes: 963 tests in 48
scripts, no skipped files. Coverage is 96.6% (009 closed at 97.6%); the drop is almost all
`_draw` code (the overlay and the cracks) and input-handler branches, which headless Godot can't
run. **The by-hand outcomes haven't been walked, and neither have 008's or 009's.**

---

## What got decided

Four decisions, D-163 to D-166, all Derik's, all settled in planning: the support rule as
written with R from the profile; **only what players dig is judged** (a saved bit in memory's
flags); the countdown is 45 s, per connected failing region, and saved; props are a 2-timber
fixture that blocks its tile; rubble is a top kind cleared like a dig for nothing, and what it
covers is buried, not destroyed.

The bindings, proposed in the brief and approved: `V` / L3 for the overlay, `F` / D-pad down for
the quick prop, `1` / `2` and RB for the build items.

**Choices made while building, not put to Derik.** He may want to look at these:

- **Countdowns run only on a level a player is on.** A level nobody is on stands still, so
  nothing collapses out of sight. The brief didn't say. Leaving a failing room freezes its
  clock; coming back finds it where you left it. The rate machine (still not built) is what
  would let a place run while you're away. `World.advance_time` is where to change it.
- **A breach marks only its landing as excavated,** not the hole's own tile above. The floor
  that became a hole was open already; marking it would have put a natural cave tile under the
  rule, and a collapse onto a hole.
- **The level's edge counts as a support.** A tile outside the disc is the mountain's own wall.
- **The Surface has no ceiling,** so nothing there is judged: its entry in the R table is 0, which
  the code reads as "none".
- **Regions are tiles joined edge to edge,** four ways, not diagonally.
- **A prop is refused where an actor's feet touch the tile** (`ACTOR_ON_TILE`), checked by the
  gatekeeper and by build mode's preview alike. It would have walled them in.
- **A prop can't go on a ramp, and shares its tile with no other fixture.**
- **Rubble hardness is 6.4,** so flint clears it in 0.4 s (tuning appendix §4 says 0.4 s "with a
  shovel", which doesn't exist yet).
- **The overlay marks as well as tints:** nothing for Stable, a slash for Marginal, a cross for
  Failing, so it reads without color (pre-alpha-scope M2's colour-blind-safe encoding). It tints
  only tiles the player has seen.
- **The cracks are three stages across the countdown,** mirrored on alternate tiles so a room
  doesn't tile one crack. The notice is "The ceiling is failing." when a region starts, and "The
  ceiling came down on you." if you were caught.
- **Memory's bit 1 is EXCAVATED.** That broke a quiet assumption in `Visibility.build`, which
  copied the memory layer as its Unknown/Remembered bytes. The tiles now keep a derived copy with
  only the REMEMBERED bit, so the copy stays native and fast.
- **Props block through a derived set on the tiles,** kept by the level from its fixtures, so
  walking, spawning and landing all agree without each asking the fixtures.
- **Numbers in the profile:** `support_radius_by_depth`, `collapse_countdown_seconds`,
  `prop_cost`, and rubble's hardness.
- **The build went in as one commit,** the same thing 009's log said to stop doing. The
  simulation, the saves, the presentation and the tests all touch `world.gd`, `game.gd` and the
  input handler, and I didn't stage by hunk.

---

## Something you may want to change in the doc's numbers

**"Dig a room 18 tiles wide: its middle goes amber, then red" doesn't happen under the rule as
written.** A room's middle tile is as far from the nearest wall as the room is wide, halved
and rounded up: 17 and 18 wide are 9 away, which is R + 1, Marginal (amber). **Red begins at 19
wide** (10 away), and only the one middle tile; a 21-wide room fails its middle 3 by 3. The doc's
"widest hall 17 tiles" for R = 8 is the widest that doesn't count down, 18 being amber still.
The tests pin the rule; if the numbers should bite sooner, the R table in the profile is the lever
(7 at −1 would put red at 17 wide).

---

## What surprised

**The distance transform paid off.** A dig beside a 21-wide room is judged in about 0.6 ms.
The window around a change is `(2R + 5)` tiles on a side, two passes of four neighbors each, and
nothing scans the level except a load, once, to find the excavated bits.

**The collapse had to be batched.** A failing region is hundreds of tiles; each `set_top` would
have asked the rule to judge the window around it, hundreds of times. `hold()` and `release()`
gather a collapse into one box. The same applies to any future bulk change.

**A countdown as a clock plus deadlines costs nothing to tick.** Each failing tile holds the
moment its region falls, and a region shares one; ticking is one add and one comparison, however
big the region.

**My own tooling bit me twice, and neither shipped.** A Python edit script wrote `§` as a bare
byte, so Godot refused `tuning_profile.gd` (invalid UTF-8) and the suite went red in a way that
looked like a code error; and a script that replaced text without asserting it matched silently
skipped the pickup guard, which the new burial test caught. Both are fixed; the habit now is to
write edit scripts with `encoding="utf-8"` and an assert on every replacement.

---

## What to do differently

1. **(Claude) Stage by section, even when files overlap.** This is 009's lesson, learned and not
   applied. A commit per section (rule, countdown, collapse, props, overlay) would have been
   easier to review.
2. **(Claude) Assert every replacement in an edit script.** The silent skip was the only real
   bug found late.
3. **Walk 008, 009 and 010 together.** Three slices of by-hand outcomes are stacked up, and 010
   touches how they all meet: a drop under rubble, a ladder under rubble, a prop on a tile you
   walked.

---

## By-hand walk (nothing here has been done)

From the brief, in order: a corridor on −1 that never warns; a room wide enough to go amber and
then red, with cracks and the notice; a prop (`F`, or build mode's second item) set before the
time runs out; a countdown let run out, standing in it; digging the rubble out; a ladder and a
drop surviving burial; a save mid-countdown and a relaunch; the overlay on `V`.

---

## Closed

*Added by Claude, 2026-11-09, when the slice was closed.*

Derik closed the slice and merged it into `main` on 2026-11-09. He was walking 008 to 010 by
hand at the time; no result was reported to Claude, so the by-hand outcomes stay unticked. Anything
the walk finds is fixed in the next slice or a follow-up. The next slice is tools and the hotbar,
ahead of "Getting it home".
