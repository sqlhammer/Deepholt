# Next

Sketches, not commitments. Slice 006, "Down into the dark", is in [NOW.md](./NOW.md): generation
on first descent, then the dark. Cheap to throw away; expect them to change.

---

## 007 — Dig your own way down

Breach a floor to make a hole, and build a ladder in it. The first runtime use of the fixture
gatekeeper (it has only ever placed things during generation), and the first of the vertical
logistics ladder you build rather than find ([vertical-logistics §2](../docs/systems/vertical-logistics-and-power.md)).
Breaching is the M1 verb and the one hard tool gate on descent
([digging-and-structure §1](../docs/systems/digging-and-structure.md)); building needs at least a
placement mode. It's also the first time a fixture is created at runtime, so the fixture id
counter 004 saves gets its first real use, and the first time levels below −2 can be reached.
Probably too big as one slice; the split should fall out of 006. A placed brazier is the
natural first runtime placement, since 006 makes the brazier a fixture kind with a light.

What 006 changes here: levels exist one ahead of arrival (D-143), so a hole breached on the
deepest level a player has reached opens onto a level that already exists. Lights placed at
runtime will need the light field rebuilt on placement, which 006 builds for moves.

What 005 changes here: fixtures can already move through the gatekeeper (D-138), and the
ladder rule for neighboring shafts is settled (D-139), so both are reachable here for the first
time. The temporary Surface hole comes out in this slice (D-140). The first stratum below the
Surface with its own stone, if it arrives here, triggers the content validator (D-137).

What 004 changes here: a placement is a request on the actor's own world
(`actor.current_level.world.place_requested`, D-125, D-126), answered on the same world, the
way the dig capability already works. The breach is a tile change, so it goes through the same
world's tile gatekeeper.

## Not placed yet

- **The support rule**: excavated space has to be held up or it fails (pillar
  [P4](../docs/game-overview.md)).
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
