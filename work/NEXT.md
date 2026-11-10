# Next

Sketches, not commitments. Slice 013, what just happened, the debug log, is accepted
([log](./log/013-what-just-happened.md)); PR #10 waits on #9. Slice 014, telemetry, is closed
([log](./log/014-how-it-plays-for-other-people.md)); PRs #9, #10 and #11 wait to be merged, in that
order. Slice 012, a world worth digging, is closed and merged
([log](./log/012-a-world-worth-digging.md)); its by-hand walk, like 008 to 011's, was not reported.
Cheap to throw away; expect them to change.

---

## 015 — Getting it home

*Moved from 013 (2026-11-10): the debug log (D-193), then telemetry (D-198), went first. It adds
the chute's telemetry events: pre-alpha criterion 1 is a chute before the 5th expedition.*

*What 012 changes here:* ore is on −2 now, and home is −1, so the haul is real: copper and tin
come up a level. A new game starts with no timber, so a chute or winch costs chopping first.

*What 011 changes here:* a chute and a winch are buildables, so they take build slots (D-170),
and the inventory's build section lists them. A crate is a pack item or a fixture; which one it
is decides whether it can be hotbarred.

The first vertical logistics past the ladder ([vertical-logistics §2](../docs/systems/vertical-logistics-and-power.md)):
a chute for items going down, and the hand winch for one crate going up. It's the answer
D-013 promises to tedium, "cheaper logistics, never a bigger pack". Drops are the natural
input and output: a chute moves a tile's drops to the level below.

## Not placed yet

- **The rate machine** that lets a hoist haul while you are three levels away.
- **Procgen beyond the recipe's fixed placements** (D-084's rules and tags).
- **A title screen and a save-slot menu.** Today launch continues the first slot, and
  `--new-game` is the only way to start fresh (D-111).

None of them are next.

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
- **The Surface's start room still has four copper tiles** in its walls (012's log); the strata
  table gives the Surface no metal ore.
- **−1's own resources** (clay, flint, root fibre, cave fungus) and **coal on −2** aren't built.
- **Not built from digging-and-structure §4:** coverage rings around supports, ghosted column
  suggestions, and the header showing the depth's R. Cut stone columns (+1 at −2) are the next
  support kind; they would be a new object kind beside the prop.
