# 012 — A world worth digging

*Written by Claude, 2026-11-09.*

> You wake on a meadow at the end of a dirt road. Trees stand around you; the road winds toward
> a mass of grey rock and through a cut in it, down to the ramp. You have an axe and no timber.
> Below, the rock hides caves nobody made, and further down, at the Greyseam, it is seamed with
> copper and tin.

**Result:** built in Agent mode on the `slice-012` branch, a commit per section. The suite
passes: 1060 tests in 54 scripts, no skipped files. Coverage is 95.0% (011 closed at 96.1%). The
drop is mostly 011's grid inventory: its drawing code, at 70%, which headless Godot can't run.
This slice's new files are covered 96–100%. **No by-hand walk has been done, of this slice or of
008 to 011.**

---

## What got decided

Nine decisions, D-179 to D-187, all Derik's, and the numbers approved with the brief:

- **The scope** (D-179): polish before new mechanics.
- **The Surface** (D-180): an open meadow, a rock mass ~20 around the start room and one rock
  quarter, and a seeded road that runs through a cut in the rock to the ramp. The spawn is at the
  road's far end.
- **Trees** (D-181): a fixture, felled with an axe only, for timber.
- **The kit** (D-182): axe, pick, shovel; no timber.
- **Ore** (D-183, corrected by D-187): copper and tin in small veins, **on −2 only**.
- **Caves** (D-184): two or three of five hand-made shapes on each of −1 and −2.
- **No preloaded ladders** (D-185), and **R halved, rounding up** (D-186): 4, 4, 3, 3, 2, 2, 2.

**D-187 is a correction of my own mistake.** I first recorded ore on −1 too, framed as reversing
only Derik's slice-006 choice. In fact the strata table, pre-alpha scope and the tier spine all
put copper and tin on −2 and none on −1. I hadn't checked the docs. Derik asked, I checked, and
D-187 corrects it. D-183 stands as written, because the decisions file is append-only.

**Choices made while building, not put to Derik:**

- **The rock mass is a disc around the origin,** where the start room is stamped. The ramp is six
  tiles east of the origin, inside the disc.
- **The road** starts in the quarter diagonally opposite the rock quarter, about 70 tiles from
  the ramp's approach. Its legs are 6–12 tiles long, each bending up to ±46° off the bearing to
  the ramp, and it is cut two wide with 4-connected steps, so there are no diagonal pinches. It
  can cut through the start room's walls; the ramp, holes and ramps are never cut.
- **Trees** take open *grass* only, not dirt patches, at 4% of the grass, two tiles clear of the
  road and the spawn. Any kind that blocks walking now stays off ramps, trees included. The
  rule moved from "a prop" to "anything that blocks walking".
- **Chopping is the dig input on a faced tree,** inside the dig capability: one action, two
  outcomes by what's there. The world is the gatekeeper ("Chopping needs an axe."), heard once
  per tree, as the breach refusal is.
- **Caves** sit wholly in solid rock inside the level's disc, at least 12 tiles from the fixed
  room's footprint and each other. Each prefab has a ring of rock around its hollow, so a cave is
  sealed even when stamped next to rock that a later step opens. Their floors are rock ground.
- **Veins** grow edge to edge from a random rock tile, in ore-id order, until each ore's share of
  the level's minable rock is reached. Ore only goes into minable rock.
- **Tin's art** is blue-grey square flecks, where copper is white rings. Copper's atlas cell is a
  white placeholder with no color, so tin had to differ in shape, not hue.
- **The support tests keep 010's R table** through a profile of their own, because they measure
  rooms drawn for R = 8. One test pins the default's halved table and its 11-wide red room.

---

## What surprised

**The meadow had no art.** Grass ground had no cell in the tile atlas, so the whole Surface would
have drawn as the magenta MISSING tile. No test looked at the renderer's cell tables for new
kinds; I found it only by checking how tin would draw. Grass and tin now have cells, and a test
checks that their cells exist and that the atlas holds one cell per entry.

**Generation cost doubled the suite's time, then half of that came back.** Laying the meadow
tile by tile through the setters, each with its signal, took 270 ms per Surface, and the tests
build a world a couple of hundred times. Building whole layers as arrays and loading them at
once brought it to about 55 ms. The suite still went from 21 s to 41 s. Part of that is real:
every new game now draws and saves ~700 trees. `test_game` alone went from 13 s to 22 s.

**Rebuilding an old save's level dropped the Surface's own generation.** A save from before
fixtures were saved is regenerated from a copy of the recipe, and the copy took the fixed
placements but not the generator, so the Surface came back with no spawn. The copy now takes
the generator and the cave list.

**A test pinned the fixture counter below the trees.** `test_saved_counters_are_restored` set
the counter to 40; the Surface's trees now use ids into the hundreds, and the load rightly moved
the counter past them.

---

## Something you may want to look at

**The Surface's start room has copper in its walls.** `surface_start` carries four copper tiles
(the `c`s in its ore grid), from before this slice. The strata table gives the Surface no metal
ore, so by the same reading as D-187 they shouldn't be there. I left them, since the room isn't
this slice's to change without asking. Removing them is a one-line prefab edit.

---

## What to do differently

1. **(Claude) Check the design docs before recording a decision about content placement.** D-183
   went in against three docs; D-187 had to correct it.
2. **(Claude) When a new kind is added to any layer, check every table that maps kinds to
   something:** the renderer's cells, the gatekeeper's conflicts, the prefab characters, the
   pinned id tests.
3. **Walk 008 to 012 together.** Five slices of by-hand outcomes are stacked up.

---

## Added mid-slice: a sharp HUD and the window (2026-11-10)

Derik's screenshots showed soft HUD text and Windows' taskbar over the hotbar. Built in Agent
mode inside this slice, at his request, on four decisions of his: a whole-number HUD scale on its
own frame (D-188), Press Start 2P (D-189), 32 px cells with six rows shown (D-190), exclusive full
screen and F11 (D-191). He chose the font and the cells from mockups rendered at Deck size.

**Result:** 1074 tests in 55 scripts, green. Coverage 94.4% (95.0% before): the new F11 toggle is
29% covered, since the part that changes the window talks to the operating system, which headless
tests can't; the inventory's drawing is 68.5% covered, as before. Screenshots from the running
game at 1280 × 800 and 1920 × 1080 showed the text and icons sharp, and the inventory fitting.

**Choices made while building, not put to Derik:**

- **The HUD's scale is the largest whole number leaving a 576 × 360 frame,** rather than the
  game's scale rounded down. Rounded down alone, a window just under 2× the game would get a frame
  of 1:1 HUD pixels, or a frame too small for the inventory. 576 × 360 is what a 16:9 screen gives
  at any whole scale; the Deck gets 640 × 400.
- **A cell's weight from 10 kg up is shown in whole kilos** ("13" for 12.5), so it fits in four
  characters, the cell's width. The exact weight is in the line under the board.
- **The build column's last two slots lead left to the tool row's end,** since they sit beside it
  now; the column runs past the six rows shown.
- **The weight bar and refusal notices hide while the inventory is open.** The first screenshot
  showed the refusal printed over the inventory's words and the weight bar through its
  background.
- **The key help lost a space between groups,** to fit one line at 8 px a letter.
- **F11's window is 1280 × 800, shrunk to fit a smaller screen,** and centered.
- **F3 keeps the engine's font**: it's a debug screen, and Press Start 2P is too wide for it.

**What surprised:**

- **Two of the four fonts in the first mockup were drawn wrong.** I took their sizes from their
  names; Jersey 10's pixel grid needs a font size of 18.67, which no whole size hits, and Micro 5
  needed 11, not 10. Derik spotted Jersey's mangled letters. The second mockup read each font's
  grid from its outlines and checked that no pixel came out half-covered.
- **The first mockup of the bigger cells was drawn wrong too:** it cut the build column off at
  six slots. The redraw showed all eight running past the tool row, before Derik chose.
- **`wrap` is one of GDScript's built-in functions,** so a static `wrap()` on the overlay failed to
  compile; renamed `wrap_text`.
- **One suite run failed five save tests in `test_game`, which then passed alone and in two full
  runs.** It came straight after the run that didn't compile, which likely left test saves behind.
  Not reproduced; noted in case it returns.

---

## By-hand walk (nothing here has been done)

From the brief, in order: a new game on the meadow at the road's end, trees around, the road
through a cut to the ramp, a rock quarter; the axe fells a tree in about 3 s for 4 timber, the
pick is refused; another world has another road and quarter; −1 has caves but no ore, −2 has
copper and tin in veins and caves, and no ladder stands below −1's hole; an 11-wide room on −1
goes red. Then the HUD: sharp text and icons on the Deck and on a 1080p screen, the inventory
fitting with its six rows, no taskbar over the game, F11 to a window and back.
