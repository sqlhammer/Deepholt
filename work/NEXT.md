# Next

Sketches, not commitments. Slice 005 is built ([log](./log/005-clearing-the-backlog.md)); its
by-hand outcomes are still to walk. 006 is next unless that walk turns something up. Cheap to
throw away; expect them to change.

---

## 006 — The dark

Dark vision, a light radius, and rock you cannot see past. The first half of *the dark is home,
the sun is the hazard* (pillar [P3](../docs/game-overview.md)) — inverted from the genre default.

Changes what "readable" means: slice 001 made rock and floor distinguishable, slice 002 added
holes, ramps and ladder tops that have to read at a glance, and this one takes most of the screen
away and asks again. Tunnel memory's remembered bit is persistent
([D-033](../docs/design-decisions.md)), so it's a new byte layer in a save format that now exists:
one more name on `SaveGame.TILE_LAYERS`
([D-112](../docs/design-decisions.md#d-112--tile-layers-are-saved-by-name-a-byte-layer-per-fact-a-saved-bound-wins)).
Light itself is derived, so it isn't saved. Likely the first slice where the render route from
001 (D-046) either holds up or gets replaced.

What 005 changes here: light radii and anything else tunable go in the world's
`TuningProfile` ([D-135](../docs/design-decisions.md)), not in code. The level-change fade
(D-142) is a black overlay over the whole display. A dark that's already near black may want it
restyled, and the dead Surface hole (D-140) is there to judge how a hole reads in the dark.
The tunnel-memory layer still edits save format v1 in place (D-133).

What 004 changes here: anything new that draws (a light or fog layer) has to follow the view's
`shown_world_changed` as well as its depth, or it won't hear a load (D-129). Light comes from
actors and fixtures, so it is worked out per world, from that world's actors, never from "the"
player (D-045). A new byte layer is also one more layer `World`'s levels carry through a swap.

## 007 — Dig your own way down

Breach a floor to make a hole, and build a ladder in it. The first runtime use of the fixture
gatekeeper (it has only ever placed things during generation), and the first of the vertical
logistics ladder you build rather than find ([vertical-logistics §2](../docs/systems/vertical-logistics-and-power.md)).
Breaching is the M1 verb and the one hard tool gate on descent
([digging-and-structure §1](../docs/systems/digging-and-structure.md)); building needs at least a
placement mode. It's also the first time a fixture is created at runtime, so the fixture id
counter 004 saves gets its first real use, and the first time levels below −2 can be reached.
Probably too big as one slice; the split should fall out of 006. If 005 builds fixture moves and
the ladder rule for neighboring shafts, this is where a player first reaches both.

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
- **Generation on first descent** (world-runtime §8). All eight levels are built at launch. When
  that changes, a save in which some levels don't exist yet is a missing key, and the load needs
  that case.

None of them are next.

---

## Carry-forward

Found during 005, not recorded anywhere else. None of it is decided.

- **The two playtime timer scripts are identical** (`active_play_timer.gd`,
  `total_play_timer.gd`); merge them when the clocks are next touched.
- **`content/tuning/default.tres` has no `uid` yet;** the editor adds one on its first save.
- **Coverage at the end of slice 005: 97.5%** (`python scripts/coverage.py`; 004 closed at
  95.7%).
