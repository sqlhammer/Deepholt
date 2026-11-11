# 015 — The long haul

*Written by Claude, 2026-11-10. Agent mode, on `slice-015` (from `main` at 3174b38), one
commit per section. Not yet walked by hand.*

**Result:** 1238 tests, green, ~50 s (the suite was ~47 s before). Everything in the brief is
built except outcome 2, which D-217 moved to 016. I saw −3, the torch, the CRAFT and PACK tabs
and the map in a real window through a throwaway screenshot test, and fixed what that showed
(below). The chute, the winch, the crank bar and the depth strip have **not** been seen on
screen; they're checked by tests only.

## What got decided

Asked one at a time before the build: D-215 to D-228. One more came up while building: D-229.

- **D-215:** −3 is reached by a ramp the seed places on −2. −2's floor stays for bronze.
- **D-216:** −3 holds caves, iron veins, one `CRUSHED` region and a landing, and has its own
  tint. There are no ruins yet.
- **D-217** (Derik, against my recommendation): iron needs a bronze pick, and flint is refused
  with a reason. Outcome 2, "iron is worth the climb", can't be walked until 016.
- **D-218:** a `CRUSHED` region is a saved region tag, filled with rubble that every tool
  refuses with its own message.
- **D-219, D-220:** a chute is a fixture over a hole on the hole's own level. One hole holds a
  ladder or a chute, never both. Chutes stack. A chute costs 2 timber, and a drop made while
  facing one goes down it.
- **D-221, D-222, D-228:** the torch burns 4 minutes while lit and sits in a light slot of its
  own; L or D-pad up lights it. It's made in a new CRAFT tab of the inventory (mock-up A of
  three, from a canvas Derik reviewed), 1 timber for 2 torches.
- **D-223** (Derik, for every UI): on-screen prompts name only the control scheme in use.
- **D-224, D-225:** the crate belongs to its winch and holds 120 kg. The winch costs 12 timber
  and 20 stone. Held at the top, it lifts the crate in 15 s and lowers it in 5 s (Derik's
  numbers; I'd proposed 30 and 10), and two players cranking add their rates.
- **D-226, D-227:** the map shows every player as a dot and doesn't pause. It opens on View or M;
  LB / RB, the wheel and Page Up / Down change its level; quick save leaves the pad.
- **D-229:** the seed carves a winding tunnel from −2's landing to the ramp, 40 to 60 tiles away.
  I raised this partway into building: a ramp left sealed in rock would only be found by
  digging blind.

## Sections

- **A (7e09dad):** −3. A tunnel carver and the ramp's chamber on −2, −3's arrival room
  (stamped under the level above's ramp, with a brazier), iron, a crushed region, the region
  store and its save, dig refusals with reasons, a −3 tint, and art for iron and rubble.
- **B (34ae6ad):** the chute.
- **C (1303933):** the winch and its crate. A fixture can now hold items (`Fixture.contents`)
  and has a burn timer (`time_left`); both are saved.
- **D (1b6ccb4):** the torch, its light slot, carried light, the CRAFT tab with recipes
  (`Recipe`, `RecipeRegistry`, `content/recipes/`), and scheme-only prompts.
- **E (fec480b):** the map and the depth strip.
- **F (28b3dcf):** telemetry for the haul, and the report counting criterion 1.
- **777bed3:** fixes from the screenshots.

Two commits came first: a0eab00 (the decisions and NOW) and 2d7e51c, below.

## Choices made while building, not put to Derik

- **Where chuted items land when they can't land under the hole:** they spill to the nearest
  open tile with no fixture, up to 4 rings out; with none, they lie on the landing, buried. I
  wrote this into D-220 without asking. I flagged it at the time, and it stands until he says
  otherwise.
- **Every buildable kind gets a build slot.** A kind missing from a hotbar takes its first empty
  build slot, saved games included, so the chute and winch appear in old saves. Before this,
  nothing could add a buildable to a slot.
- **A lift takes 15 s whatever the load.** D-225 says so; my earlier proposal had scaled the time
  with the load.
- **Pad A on a winch:** a tap takes what's in the crate when it's at the top and holds
  something, and holding A cranks. So on a pad you empty the crate before you lower it. On a
  keyboard, E cranks and T takes, separately.
- **A torch that burns out lights the next one** in the pack, with a full burn. Dropping a lit
  torch puts one burning on the ground and lights the next in hand.
- **Carried light is recomputed every time the screen's state is rebuilt,** which happens when
  the followed player moves, memory changes, or the followed player's light is toggled.
  Another player's torch moving doesn't trigger a rebuild on its own.
- **The light slot on the PACK tab is display only;** the focus doesn't reach it. It sits past
  the build column at the tool row's height, which is the end of the hotbar as drawn there.
- **Hold to keep making:** one more after 0.4 s, then one every 0.15 s.
- **The map draws 2 HUD pixels a tile, centered on you,** after 1 pixel proved unreadable in the
  screenshots. Its picture is rebuilt at most every 0.25 s while memory grows under it.
- **The depth strip** marks every level of the mountain, the one you're on filled and named.
  Levels not yet generated are drawn dimmer.

## What went wrong, mine

- **The suite was red before I touched it.** Derik's export in his UAT commit added a
  `[runnable_presets]` section to `export_presets.cfg`, and the preset test read it as a preset.
  The test now reads only `preset.N` sections (2d7e51c). I committed that fix before running it;
  the next run was green.
- **I missed a gap in fork 5, and another in fork 4b.** The brief proposed torches made "from
  timber" without noticing there was no crafting at all; that became fork 5b and the CRAFT tab.
  It said "anything dropped on its tile falls", and a hole isn't passable, so nobody can stand on
  a chute's tile; I named that in fork 4b.
- **I recommended Page Up / Page Down for the map** despite a note in my own memory that
  Derik's laptop doesn't deliver those keys to Godot. They're bound, along with the wheel, which
  does work. If they fail on his laptop, the map needs another level key on the keyboard.
- **A blanket fix for the Unicode minus** changed one of Derik's assertion messages in
  `test_save_game.gd`. I caught it in the diff and restored it.
- **Several tests pinned "build slot 3 is empty"** and broke twice, once for the chute and once
  for the winch. They now find the first empty slot from `Hotbar.BUILDABLE`.

## What surprised

- **The cave test's helper copied generation's early steps,** so the descent step changed which
  caves it computed. It now follows `generate_level`'s order. That duplication will break again
  the next time a step is added.
- **The inventory's help line was the only prompt in the game.** So D-223 changed one existing
  string, and the CRAFT tab, the map and the tab strip were built to it from the start.
- **Generating −3 cost the suite ~2 s,** not the minute trap 8 feared. The worlds in
  `test_minus_three` are built once per seed for the file.

## Seen in a window

From the throwaway screenshot test (deleted, never committed):

- −3's arrival room, the brazier, and torchlight along a corridor. Crushed rubble reads clearly
  against rock.
- The CRAFT tab matches mock-up A. Its keys follow the scheme.
- Two fixes came from the window: the PACK tab's help line ran off the board (the tab keys now
  live only on the strip), and the map was unreadable at 1 pixel a tile and its header ran over.
  F3 printed crushed tiles as `?`; it prints `x` now.
- The GUT runner's panel covered the right of the screen, so the depth strip wasn't captured.

## By hand, still to do

All of NOW.md's outcomes 1 and 3 to 8 (outcome 2 is 016's). In particular:
- the winch's crank feel at 15 s;
- the chute and winch art over a real hole;
- the depth strip;
- Page Up / Page Down on the laptop.
