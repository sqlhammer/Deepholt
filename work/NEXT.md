# Next

Sketches, not commitments. Slice 003 is done ([log](./log/003-it-persists.md)), and 004 is
[NOW.md](./NOW.md). The order past it should fall out of what 004 teaches. Cheap to throw away;
expect them to change.

---

## 005 — The dark

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

## 006 — Dig your own way down

Breach a floor to make a hole, and build a ladder in it. The first runtime use of the fixture
gatekeeper (it has only ever placed things during generation), and the first of the vertical
logistics ladder you build rather than find ([vertical-logistics §2](../docs/systems/vertical-logistics-and-power.md)).
Breaching is the M1 verb and the one hard tool gate on descent
([digging-and-structure §1](../docs/systems/digging-and-structure.md)); building needs at least a
placement mode. It's also the first time a fixture is created at runtime, so the fixture id
counter 004 saves gets its first real use, and the first time levels below −2 can be reached.
Probably too big as one slice; the split should fall out of 004 and 005.

## Not placed yet

- **The support rule**: excavated space has to be held up or it fails (pillar
  [P4](../docs/game-overview.md)).
- **The rate machine** that lets a hoist haul while you are three levels away.
- **Procgen beyond the recipe's fixed placements** (D-084's rules and tags).
- **A title screen and a save-slot menu.** Today launch continues the first slot, and
  `--new-game` is the only way to start fresh (D-111).

None of them are next.

---

## Deferred from 002

- **Level-change transitions** ([D-108](../docs/design-decisions.md)). Ramps and ladders are
  instant for now; a transition time and visual effects are wanted later. It goes between the
  request and `Actor.move_to` ([D-119](../docs/design-decisions.md)), not into the `Ramp` or
  `Ladder` rules, and must say what a held dig does during it.
- **Moving a fixture** (a bed, M6). Discussed in 002, not recorded: make `Fixture.tile` read-only,
  move through the store and the gatekeeper, and decide whether a move is announced as a removal
  plus a placement or as its own event.
- **Up or down when both apply on a ladder** (D-106, not decided). Needs side-by-side shafts and
  −3.

## Deferred from 003

- **Small, unscheduled tidy-ups from the review:** sort the save slots instead of taking
  `get_directories()` order (R-P6); remove the dead tool-loading code (`_load_tool`, `TOOL_DIR`,
  the `equipped` check, R-B5); "it's" → "its" in three comments, and comments over 70
  characters (R-S4).
- **[save-files.md](../docs/tech/save-files.md) is behind the code** on the header (two playtime
  clocks, D-120), which keys are required (D-121, D-122), and the file-name timestamp (D-123).
- **The autosave interval** is a placeholder 300 s (D-110 leaves the number open), the first
  number to move into the tuning profile when it's built
  ([D-037](../docs/design-decisions.md#d-037--one-tuningprofile-resource-holds-every-global-constant)).
- **Nothing prunes old saves.** Moved-aside and broken saves pile up in the slot folder.
- **The playtime clocks have no tests** (D-120), most of 003's coverage drop.
- **Save format version 1 isn't settled.** Until versions are tracked, a header change edits v1
  in place. Settle it before any save has to survive an update.

## Carry-forward

Found during slices 001–003, not recorded anywhere else. Bring into planning; none of it is
decided.

- **Hardness is still called `density` in code** (`TileKind.MINABLE_DENSITY`). Renaming it to
  match the tuning appendix is an optional tidy-up (D-081).
- **The appendix's own numbers miss the 0.5–0.7 s band at −5 and −7** (D-081, open). The content
  validator that would catch this ([content-schema §5](../docs/tech/content-schema.md)) isn't
  built.
- **`dig_refused` and `Objects.request_refused` carry reasons that nothing reads yet.** They're
  there for feedback (sound, UI) when that arrives.
- **`F3`'s tile window prints a hole as `.`** (the readout names it).
- **The temporary hole at (0, 2) in `surface_start`** is kept on purpose; take it out when it has
  served its purpose. It's the Surface's one hole, with no ladder under it.
- **Coverage at the end of slice 003: 95.1%** (`python scripts/coverage.py`).
