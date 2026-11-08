# Next

Sketches, not commitments. Slice 008 is done and merged ([log](./log/008-what-you-carry.md));
its by-hand outcomes are still to walk. Cheap to throw away; expect them to
change.

---

## 009 — Letting go

Shedding weight, which Derik scheduled here (D-156): drop something from the pack, and pick it up
again. Drops are a new saved thing in the world, a per-level store of item stacks on tiles, drawn
small. They're the same store D-158's model needs: a yield that doesn't fit becomes a drop, and a
player picks drops up automatically from its own and adjacent tiles, up to 150%. With dropping in
place, the "no cap" of D-158 can be revisited, and an inventory screen (ui-ux §5: per-item weight,
sort by value density, a take-this preview) is the natural way to choose what to drop.

What 008 changes here: every actor has a `Pack` with a running weight, items are `.tres` resources
found through `ItemRegistry`, and the HUD already follows the pack. A drop on a dark tile meets
D-148 (what's drawn in the dark). The "dragon bag" randomizer (D-156) could arrive here too, if
stone's volume needs managing.

## 010 — Holding it up

The support rule: excavated space has to be held up or it fails (pillar
[P4](../docs/game-overview.md), [digging-and-structure §2](../docs/systems/digging-and-structure.md)).
Depth-scaled support radius, timber props (the reserved D-pad down, ui-ux §2.5), three ceiling
states and a telegraphed failure countdown, then local collapse into rubble. The support overlay
comes with it. Milestone M2. A timber prop is a second costed item for build mode, from the timber
008 introduced.

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
