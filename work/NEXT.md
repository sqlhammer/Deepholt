# Next

Sketches, not commitments. Slices 012 to 015 are closed and merged. **016, something worth
carrying, is built** on `slice-016` (2026-11-11, [log](./log/016-something-worth-carrying.md)),
not yet walked. 017 is next.

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

*From 015:* −3 is reached by a ramp (D-215), so breaching −2's floor with bronze is a way to
put your own shaft where you want it, not the only way down. **Bronze must dig iron** (D-217:
flint is refused), so outcome 2 of 015, "iron is worth the climb", is walked here. The bench
recipes go in the CRAFT tab's "at a workbench" section (D-222), shown when standing at one. The
winch's crate belongs to its winch (D-224), so storage is a fixture of its own, though it can
reuse `Fixture.contents`. The lantern's fuel is still unsourced; it needs a resource.

## 017 — Ore comes up without you

A windmill on the Surface, a driveshaft down the levels, one level of line shaft, the powered
hoist, proportional brownout (a second hoist slows both); the rate machine, so a hoist hauls
while you're on another level and across save and load; −3's three authored ruins, one holding
the hoist's blueprint; and a first-session pass so an unguided tester's first hour roughly
follows pre-alpha-scope §5's ten steps, at least an elder who points down.

*From 016:* the rate machine exists: the smelter is one, against a saved world clock
(`world_time`, D-238). The hoist extends it with power, rather than starting it. The winch's
cost (12 timber + 20 stone, D-225) never took the tuning appendix's ingots; with ingots now
real, 017 could reprice it. Stations can't be removed (no hammer), so one built in a one-wide
tunnel seals it.

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
- **From Derik's UAT walks (2026-11-10):** 012 to 014a pass. Not done: 013's case E (the jump
  on −1, not caught or reproduced) and 014's A4 (the Linux build on the Deck).
- **Telemetry drops the `loaded` event on a load at launch:** `load_game` records it before
  `begin()`, deferred a frame, opens the session file. The summary's load times still count it.
- **The UAT for 014 D2 assumed 60 Hz** ("p50 about 17 ms"); on a 240 Hz screen p50 is 5 ms.
- **`digging-and-structure §4`'s R table is the original design** (8 to 3); the numbers in play
  are D-211's (3, 3, 2, 2, 1, 1, 1). The doc hasn't been brought in line since D-186.
- **Not built from digging-and-structure §4:** coverage rings around supports, ghosted column
  suggestions, and the header showing the depth's R. Cut stone columns (+1 at −2) are the next
  support kind; they would be a new object kind beside the prop.
- **From 015:** Page Up / Page Down change the map's level, but Derik's laptop may not deliver
  them (the wheel does work). If so, the map needs another keyboard key.
- **From 015:** `test_rock_generation`'s cave helper repeats `generate_level`'s early steps,
  and breaks whenever a step is added before caves. A hook that reports where caves went would
  end that.
- **From 015:** another player's torch moving doesn't redraw your screen on its own; it shows
  at your next step. Fine for one player at a keyboard; local co-op would want a signal.
- **From 015:** the map rebuilds a level's picture at most every 0.25 s while memory grows.
  It's unmeasured on −7 (radius 207).
- **From 015:** the chute, winch, crate and torch art are placeholders drawn by script.
- **Coverage at the end of slice 015: 91.4%** (012 closed at 95.0%). The gap is the CRAFT tab's
  and the map's drawing, which only a windowed run reaches.
- **Coverage at the end of slice 016: 90.2%.** The gap is the BUILD tab's and the sectioned
  CRAFT list's drawing, and the refusal notice's texts.
- **From 016:** rock is hardness 6 on every level, so tool tiers are faster everywhere but not
  by stratum (tuning §4's ~0.6 s per stratum doesn't hold).
- **From 016:** the bed has nothing to do until death (M6), past a stuck player on load.
- **From 016:** a flint tool item weighs 2.5 kg; tuning §3 says 3.0. New tools are 3.0.
- **From 016:** the smelter, storage and fungus art is placeholder drawn by script; storage and
  fungus haven't been seen underground.
