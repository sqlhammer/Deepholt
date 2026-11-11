# Next

Sketches, not commitments. Slices 012 to 014 and 014a are closed and merged. Derik walked
012 to 014 with the UAT docs (`work/lesson/uat-*.md`); his fixes are 014b (D-211 to D-214,
[log](./log/014b-uat-fixes.md)). **015, the long haul, is planned in [NOW.md](./NOW.md).**

**015 to 017 were accepted together** (Derik, 2026-11-10, D-210), larger than earlier slices,
**all in Agent mode.** Together they take the game to the first session in
[pre-alpha-scope §5](../docs/pre-alpha-scope.md), ending at step 10: watching ore come up
without you. Cheap to throw away; expect them to change.

---

## 016 — Something worth carrying

A workbench, a smelter and a forge, and recipes that use copper, tin and iron; tools in tiers,
flint to bronze to iron, each faster and opening harder strata (bronze breaches −2's floor);
the oil lantern and its fuel; a bed and a home on −1 to respawn at; crates as storage.

*Why:* today ore has no use. Hauling it can be measured, but there's nothing at stake, so a
playtest of hauling would measure nothing. This makes the pack a choice (ore or stone, smelt
here or at home), and criterion 4, a smelter sited near the mine without being told, can't
happen until a smelter exists. Tool tiers make going deeper progress, not just distance.

*From 015:* how −3 is reached (its fork 1) decides whether bronze opens a new way down or only
a faster one. The crate is built in 015; storage reuses it.

## 017 — Ore comes up without you

A windmill on the Surface, a driveshaft down the levels, one level of line shaft, the powered
hoist, proportional brownout (a second hoist slows both); the rate machine, so a hoist hauls
while you're on another level and across save and load; −3's three authored ruins, one holding
the hoist's blueprint; and a first-session pass so an unguided tester's first hour roughly
follows pre-alpha-scope §5's ten steps, at least an elder who points down.

*Why:* step 10 is the moment the experiment tests; criterion 3 asks whether testers name it a
highlight. The rate machine is an M0 and M5 exit, and support countdowns already pause on
levels you've left waiting for it. At the end, playtest builds go to 5–8 testers and every
criterion but 6 can be judged.

## Left out of 015 to 017, on purpose

The sun, exposure and shade (M4): the Surface stays a timber run. Hunger, comfort, creatures and
combat (M6, M7): pressure, not the thesis. They follow the first playtest's answer.

## Not placed yet

- **Procgen beyond the recipe's fixed placements** (D-084's rules and tags).
- **A title screen and a save-slot menu.** Today launch continues the first slot, and
  `--new-game` is the only way to start fresh (D-111).

None of them are next. (The rate machine, once here, is 017's.)

---

## Carry-forward

Found during 005, not recorded anywhere else. None of it is decided.

- **The two playtime timer scripts are identical** (`active_play_timer.gd`,
  `total_play_timer.gd`); merge them when the clocks are next touched.
- **`content/tuning/default.tres` has no `uid` yet;** the editor adds one on its first save.
- **Coverage at the end of slice 005: 97.5%** (`python scripts/coverage.py`; 004 closed at
  95.7%).
- **Coverage at the end of slice 006: 97.4%** (005 closed at 97.5%).
- **`hardness_of` and `dig_hardness` sit on the tuning profile** (a digging rule on a numbers
  resource). Derik asked why; moving them beside digging is open.
- **The state texture's GPU upload is unmeasured** (headless can't). Watch F3's "Dark" line on
  −7, the largest level.
- **ui-ux §7's build-mode dimming and grid, pad B to leave, and the cursor's tick** weren't
  built in 007.
- **Pad X is contested** once tools can be swapped (D-155).
- **Coverage at the end of slice 007: 97.5%.**
- **Digging and breaching have no actor animation or sound.** A breach shows cracks on its tile
  (007); a dig has nothing but the tile vanishing. Both want a working animation once there's
  art, and strikes once there's audio.
- **Coverage at the end of slice 008: 97.6%.**
- **A `Worlds.with_levels` that adds a blank level under the deepest one asked for** would end the
  test-world trap that has come back three times since D-143 (008's log).
- **Coverage at the end of slice 009: 97.6%.**
- **Pad LB is contested** once the hotbar arrives (009 bound the take key there). 010 bound RB
  to cycling build items, which the hotbar will also want.
- **Coverage at the end of slice 010: 96.6%** (009 closed at 97.6%). The gap is `_draw` code and
  input-handler branches, which headless Godot can't run.
- **Countdowns run only on levels a player is on** (010's choice, not put to Derik). The rate
  machine decides whether a failing room should keep counting while you're away.
- **The support doc's "widest hall" column is one tile off the rule as written** (010's log): 17 wide
  is still amber at R = 8, red starts at 19.
- **Coverage at the end of slice 011: 96.1%** (010 closed at 96.6%). The gap is the hotbar's and
  the inventory's drawing, a click on a slot, and the notice's text paths.
- **Pad A confirming without also dropping is untested through `Input`** (011's log: a tap
  leaks across tests within a frame). The handler's order covers it; a test helper that waits
  out a frame without breaking the older tests would close it.
- **A second player spawned later digs bare-handed:** only a new game's first player gets the
  starting items (008's rule), and tools are starting items now (011).
- **Pad Y in the inventory assigns; outside it, Y is build mode.** The radial (LT) and the hammer
  will want more pad buttons; the pad is nearly full.
- **Coverage at the end of slice 012: 95.0%** (011 closed at 96.1%, after its grid inventory).
  The gap is drawing code: the grid inventory (70%), the overlays and cracks.
- **The suite takes ~41 s** (21 s before 012): a new world generates a ~55 ms Surface and ~700
  trees, and many tests build one. A smaller Surface recipe for tests would bring it back.
- **−1's own resources** (clay, flint, root fibre, cave fungus) and **coal on −2** aren't built.
- **Not walked by hand yet** (Derik's UAT, 2026-11-10): 013's pad controls, all of 014, and
  013's case E (the jump on −1), which wasn't caught or reproduced.
- **`digging-and-structure §4`'s R table is the original design** (8 to 3); the numbers in play
  are D-211's (3, 3, 2, 2, 1, 1, 1). The doc hasn't been brought in line since D-186.
- **Not built from digging-and-structure §4:** coverage rings around supports, ghosted column
  suggestions, and the header showing the depth's R. Cut stone columns (+1 at −2) are the next
  support kind; they would be a new object kind beside the prop.
