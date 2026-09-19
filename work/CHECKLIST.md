# Slice 001 checklist

Working list for [NOW.md](./NOW.md). Ordered so something is on screen early, not by code
dependency. **Decide** items are forks to talk through before building past them; each outcome
becomes a `D-nnn`. Numbers in brackets are the brief's by-hand outcomes.

## A. Tile data — no scene ✅

- [x] Ore is a third byte array alongside ground and top ([D-054](../docs/design-decisions.md)).
- [x] The kinds from [D-051](../docs/design-decisions.md) and [D-052](../docs/design-decisions.md) exist as a table.
- [x] A level's tile data can be created, written and read by coordinate, per [D-048](../docs/design-decisions.md).
- [x] Test: write a tile on each layer, read it back.
- [x] Reads outside the array return 255; inside the array but outside radial bounds return 254. No kind on any layer uses either ([D-057](../docs/design-decisions.md), [D-059](../docs/design-decisions.md)).
- [x] Test: reads past each edge of the array return 255, and a read in a corner outside the radius returns 254.

## B. Loading a grid

- [x] Grid characters per [D-056](../docs/design-decisions.md).
- [x] An unrecognised character fails the load ([D-055](../docs/design-decisions.md)). Ragged
  lines no longer do: a prefab covers only what it was authored to cover, and unmentioned tiles
  keep the level's default ([D-062](../docs/design-decisions.md), superseding that half of D-055).
- [x] Ore under anything but `#` fails the load ([D-056](../docs/design-decisions.md)) — where the
  top grid states the tile. Over a tile it never mentions, ore is legal, since the default is
  minable rock ([D-062](../docs/design-decisions.md)).
- [x] Test: unrecognised-character and ore-over-stated-non-minable each fail to load.
- [x] A prefab's layer grids stamp into level data, with the marker landing on the anchor rather than world `(0, 0)` ([D-060](../docs/design-decisions.md)).
- [x] Test: a small inline grid loads; spot-check tiles on all four sides of the anchor, including negative coordinates.
- [x] Test: for each grid, no anchor marker fails to load and two fail to load ([D-050](../docs/design-decisions.md), [D-053](../docs/design-decisions.md)).
- [x] Test: a prefab stamps at a non-zero anchor, and layers of different shapes align by their markers.
- [x] Prefabs are `.tres` resources with stable ids, indexed by a registry autoload ([D-061](../docs/design-decisions.md)).
- [x] Test: the authored prefab loads from disk by id and stamps into a level.
- [x] The slice's hand-made level file **is authored**.

## C. Pixels

- [ ] **Decide:** how tile data is encoded into textures.
- [ ] **Decide:** how an id becomes pixels — atlas lookup, and combining ground and top.
- [ ] **Decide:** how much of a level one quad covers.
- [ ] Placeholder atlas: rock ground, rock, copper.
- [ ] Launch: the hand-made level is on screen, and rock, copper and open floor are distinguishable at a glance at the intended scale. [1]
- [ ] Move the view across tiles and watch the edges, not just a still frame.

## D. An actor

- [ ] **Decide:** what an actor is.
- [ ] **Decide:** how input reaches an actor.
- [ ] A moleperson stands in open space; keyboard and gamepad both move them. [2]
- [ ] They cannot walk into rock or copper, and blocking is answered from tile data ([D-046](../docs/design-decisions.md)). [2]
- [ ] `F3` shows the actor's position and the depth the world calls it. [6]
  The readout itself is built — coordinate, array index, the three layers by name, and an
  11 × 11 tile window in the prefab's own characters. It reports whatever position the actor
  has, so this lands the moment the actor stops returning a constant.
- [ ] **Decide:** what happens at the edge of the level — after looking at a corner of the radial bounds at tile granularity.
- [ ] Walking to the edge does that, deliberately. [5]

## E. Digging

- [ ] **Decide:** who may change a tile, and how anything else learns it changed. Before the dig verb exists.
- [ ] **Decide:** the rules for digging what cannot be dug.
- [ ] Test: changing a tile through the mutation path and reading it back.
- [ ] Test: each cannot-dig rule.
- [ ] Face rock or copper, press dig, and the tile becomes open floor on screen. [3]
- [ ] **Decide, by looking:** whether digging is instant.
- [ ] Dig a four-to-five tile corridor and walk down it; it stays dug. [4]

## F. Done

- [ ] Quit and relaunch: the level is back to its hand-made state. [7]
- [ ] `scripts/test.ps1` passes.
- [ ] By hand: outcomes 1–7 walked through in one sitting.
- [ ] Claude drafts `log/001-dig-one-tile.md`; Derik corrects it.
