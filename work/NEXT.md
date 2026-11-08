# Next

Sketches, not commitments. Slice 007 is built ([log](./log/007-dig-your-own-way-down.md)) on the
`slice-007` branch; its by-hand outcomes haven't been walked. Cheap to throw away; expect them to
change.

---

## 008 — What you carry

Digging yields something, and you have to carry it. Spoil and stone from mining, ore from veins,
a weight-limited inventory with no teleport ([D-013](../docs/design-decisions.md)), and the carry
weight on the HUD, always ([ui-ux §5](../docs/ui-ux-and-controls.md)). The ladder gets its wood
cost, so build mode's preview shows a cost and refuses what you can't afford
([ui-ux §7](../docs/ui-ux-and-controls.md)). This is milestone M1's other half
([pre-alpha-scope](../docs/pre-alpha-scope.md)): "dig a 20-tile tunnel and fill a pack".

What 007 changes here: placement already goes through the gatekeeper, and the preview already
uses its rules, so a cost is one more rule in both. Spoil must never become a hauling chore
([digging-and-structure §1](../docs/systems/digging-and-structure.md)). Where wood comes from
(the Surface, under exposure) is an open fork, and a large one.

## 009 — Holding it up

The support rule: excavated space has to be held up or it fails (pillar
[P4](../docs/game-overview.md), [digging-and-structure §2](../docs/systems/digging-and-structure.md)).
Depth-scaled support radius, timber props (the reserved D-pad down, ui-ux §2.5), three ceiling
states and a telegraphed failure countdown, then local collapse into rubble. The support
overlay comes with it. Milestone M2.

What 007 changes here: build mode and the anchored cursor exist, so a prop is a second item to
place. A breach is the largest single excavation today, so it's the first thing to check
against support.

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
