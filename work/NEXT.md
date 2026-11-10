# Next

Sketches, not commitments. Slice 010 is done and merged ([log](./log/010-holding-it-up.md)); no
by-hand walk of 008, 009 or 010 has been reported. Slice 011, tools in hand, is planned in
[NOW.md](./NOW.md). Cheap to throw away; expect them to change.

---

## 012 — Getting it home

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
- **Not built from digging-and-structure §4:** coverage rings around supports, ghosted column
  suggestions, and the header showing the depth's R. Cut stone columns (+1 at −2) are the next
  support kind; they would be a new object kind beside the prop.
