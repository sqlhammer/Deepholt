# 014b — Fixes from walking 012

*Written by Claude, 2026-11-10. A mini-slice after Derik's UAT walks of 012 to 014, in Agent
mode, on `slice-014b` (from `main` at 13b7315).*

**Result:** 1132 tests, green. The suite's engine warnings fell from 150 to 39; the 39 left are
the ones tests provoke on purpose with bad saves and prefabs. Nothing here has been seen in a
running game yet: the draw order in particular is checked by tests on positions, not by eye.

## What Derik found

012's main walk passed, except for four things he asked to change. The cave walk passed. 013's
pad controls and all of 014 aren't walked yet, and 013's case E (the jump on −1) wasn't caught
or reproduced.

## What got decided

- **D-211** (Derik): the support radius drops by one at every depth, to 3, 3, 2, 2, 1, 1, 1. An
  11-wide room on −1 had collapsed as the rule said, but the room was too large before it did.
  Red now starts at 9 wide on −1 and −2, 7 wide on −3 and −4, and 5 wide from −5. Derik chose this
  over changing −1 and −2 only, or −1 only.
- **D-212** (Derik): what a player drops isn't picked back up until they've been out of its reach
  (more than 1 tile away). Then it's an ordinary drop. Only the dropper skips it. It isn't saved.
  Derik chose this over marking dropped stacks as placed, so that only take picks them up, and
  over a few seconds' grace.
- **D-213** (Derik): no metal ore on the Surface. The start room's four copper tiles are gone,
  and a test pins it for three seeds.
- **D-214** (from Derik's screenshot): fixtures and actors are drawn in one sort. An actor north of
  a tree is behind it; on its tile or south of it, in front.

## How each was fixed

- **Drops:** the old rule (slice 009's trap 3) skipped the drop only while you stood on its tile.
  Pickup reaches the 8 tiles around you, so your first step picked it back up. Every tile you've
  dropped on is now remembered until you're out of its reach, or on another level.
- **Draw order:** the World node was added after the fixture renderer in the game viewport, so
  every actor drew over every fixture. A `Standing` node (Y-sorted) now holds both, and sorting
  reaches each actor: World, Actors, Players and NPCs all sort. A fixture sprite's origin sits
  4 px above its tile's top edge, and draws where it did before through an equal and opposite
  offset. 4 px is the distance from an actor's origin to its feet's center, which is what decides
  the tile an actor is on. So the line between behind and in front is the tile edge the feet cross. A
  test reads `Actor.feet_box` and fails if the two drift apart.

## Choices made while building, not put to Derik

- **Ladders, braziers and props sort too,** not only trees. An actor on a ladder's tile still
  draws over it, as before. One on the tile north of a ladder now draws behind the ladder's top
  8 px, which rise into that tile.
- **The first-launch warning:** while checking that this slice added no warnings, I found 111 of
  the suite's 150 came from `SaveGame.get_save_slots`. It warned whenever the saves folder didn't
  exist, which is every first launch. It now returns no slots quietly, and still warns when a
  folder exists but can't be opened. This is outside the four fixes; it's here because of the
  standing rule to fix a recurring warning at its cause.
- **The 015 planning docs** (NOW, NEXT, D-210) were uncommitted on `main`. They're committed on
  this branch with D-211 to D-214, so 015 builds on 014b.

## What surprised

- **D-186's R table never reached the design doc.** `digging-and-structure §4` still shows the
  original 8 to 3. Left as it is and carried forward in NEXT, since the decisions log is the
  record and the doc is Derik's.

## By-hand

Walkthrough in [uat-014b](../lesson/uat-014b-uat-fixes.md) (untracked).
