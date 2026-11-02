# Slice 005 — Clearing the backlog

> Take a ramp and the level change is a transition you can see, not a cut. Under it, every item
> deferred from slices 002–004 and every carried-forward note is either done or decided.

*Proposed by Claude, 2026-11-02. Derik set the scope: only the "Deferred from" sections for
slices 002–004 and the "Carry-forward" section from [NEXT.md](./NEXT.md). The dark and digging
move to 006 and 007. Derik accepts, edits or replaces this brief.*

## Where we are

Slice 004 is done ([log](./log/004-a-world-you-can-hold.md)). The world is a node that owns its
levels, its actors and both id counters. A load builds a whole `World` to one side and swaps it
in at the end of the frame. Derik walked outcomes 1, 3 and 4 by hand on 2026-11-02, and nothing
turned up.

Three slices left small things behind on purpose. Each one was the right thing to leave at the
time, and together they add up to about twenty. This slice clears them before the dark changes
how everything is drawn. Most of them are tidy-ups. Four are design forks. One, the level-change
transition, is a feel item, and it's the slice's playable edge.

## Mode

**Agent**, for the whole slice (Derik, 2026-11-02). Claude builds every section, and puts each
section's forks to Derik one at a time before building it.

## What should be true when you stop

By hand, unless marked:

1. Take the ramp or a ladder, either way: the change of level is a transition you can see, not
   a cut. A held dig does what was decided for the transition, and it still works on arrival
   ([D-108](../docs/design-decisions.md#d-108--a-held-dig-carries-across-a-level-change-level-changes-are-instant-for-now)).
2. F5 during a transition, then F6: the load leaves no half-finished transition behind, and the
   actor is where the save says.
3. F3's tile window shows a hole differently from open floor.
4. `--new-game`: the Surface starts without the temporary hole at (0, 2), if Derik decides it
   has served its purpose (it's the only hole on the Surface, and it has no ladder under it).
5. The slot folder doesn't keep growing: moved-aside and broken saves are pruned by the rule
   that gets decided, and the current save and its backup are never touched.
6. F3's "Last load" is read after a 004-shaped load, and the number goes in the log.
7. *Automated:* the playtime clocks are tested
   ([D-120](../docs/design-decisions.md)).
8. *Automated:* a load returns a typed result, not a dictionary.
9. *Automated:* a save whose only actors are NPCs loads and is shown. The view shows the new
   world without a followed actor, and the renderers stop drawing the old one.
10. *Automated:* an actor on a ladder that faces a hole with another ladder under it goes the
    way that was decided. It's tested in a built world with neighboring shafts, because −3
    can't be reached by hand until 007.
11. *Automated:* a fixture moves through the world's fixture gatekeeper. Its tile can't be
    changed any other way, and the move is announced the way that was decided.
12. *Automated:* the autosave interval comes from the tuning profile, and a save records that
    profile's id rather than `"none"`.
13. Nothing in the code is still called `density`. The dead tool-loading code is gone, slots
    are listed in sorted order, the comments are fixed, and
    [save-files.md](../docs/tech/save-files.md) matches the code.

Outcomes 10–12 can't be seen by hand, because nothing in the game uses them yet. They're
groundwork, built against the system each one belongs to. That's said plainly here so the
slice isn't padded.

## What you're deciding

Taken one at a time before the section that needs it.

- **The level-change transition** (D-108). What it looks like: a fade, a slide, the camera
  dropping, or something else. How long it takes. Whether the actor is delayed in the
  simulation (the move happens at the end), or moved at once while the view plays the effect.
  What a held dig does during it. Whether input, and saving on a level change
  ([D-110](../docs/design-decisions.md#d-110--when-a-save-happens-quit-level-change-a-timer-and-a-key)),
  waits for it.
- **Which way a ladder goes when both directions apply**
  ([D-106](../docs/design-decisions.md#d-106--interact-is-polled-on-the-physics-tick), "not
  decided"). The options are up, down, facing direction, or a second input.
- **Moving a fixture** (002, not recorded). Make `Fixture.tile` read-only, move fixtures only
  through the world's gatekeeper, and announce the move either as a removal plus a placement or
  as its own event.
- **The tuning profile's shape**
  ([D-037](../docs/design-decisions.md#d-037--one-tuningprofile-resource-holds-every-global-constant)).
  How it's reached: handed to the world, handed to the game, or global. And how much moves into
  it now: only the autosave interval, or every global constant the code already has (hardness,
  tool power, speeds, the autosave interval).
- **Pruning old saves.** How many moved-aside and broken saves are kept, or for how long, and
  when pruning runs.
- **Save format version 1.** Whether it's settled now, so that migrations start, or stays open.
- **The temporary Surface hole.** Whether it's removed now.
- **The appendix's hardness band and the content validator**
  ([D-081](../docs/design-decisions.md#d-081--hardness-belongs-to-tile-kinds-the-pre-alpha-tool-is-a-flint-pickaxe),
  [D-038](../docs/design-decisions.md#d-038--a-content-validator-enforces-the-derived-invariants-in-ci)).
  Whether the validator is built in this slice, and if so with which checks. D-081 accepts the
  Surface's 0.375 s, so a band check needs a way to allow it. Otherwise the open −5 and −7
  numbers stay with the strata they belong to.
- **The refusal reasons nothing reads** (`dig_refused`, `request_refused`). Show them in F3 now,
  or leave them for the sound and UI work that will use them.

## Already settled

- **A transition goes between the request and the move, never into the `Ramp` or `Ladder`
  rules** (D-108). It delays or animates `Actor.move_to`, which stays the one way an actor is
  put somewhere else
  ([D-119](../docs/design-decisions.md#d-119--move_to-is-the-one-way-an-actor-is-put-somewhere-else)).
- **No system assumes exactly one actor** (pillar [P5](../docs/game-overview.md)), and nothing
  resolves to *the* player
  ([D-045](../docs/design-decisions.md#d-045--no-player-singleton-carves-out-the-presentation-layer)).
  A transition belongs to the actor that's taking it. It doesn't pause the game.
- **Fixtures change only through their own gatekeeper, which now lives on the world**
  ([D-090](../docs/design-decisions.md#d-090--objects-get-their-own-gatekeeper-separate-from-world),
  [D-125](../docs/design-decisions.md)).
- **One `TuningProfile` resource holds every global constant, and a save records its id**
  (D-037, [D-116](../docs/design-decisions.md)). The autosave interval moves into it first.
- **Anything that draws follows `shown_world_changed`** (D-129). A view that has no followed
  actor still has to announce a new world.
- **What a refused save does, and what's kept:** the broken save is kept, the backup is tried,
  and the failure is loud
  ([D-111](../docs/design-decisions.md#d-111--continue-by-default-a-flag-for-a-new-game-backups-and-broken-saves)).
  Pruning can't break that.
- **Hardness is the tile kind's** (D-081). The rename to `hardness` changes names only.
- **A saved bound wins, and a saved level wins over the recipe**
  ([D-112](../docs/design-decisions.md#d-112--tile-layers-are-saved-by-name-a-byte-layer-per-fact-a-saved-bound-wins)).
  See trap 4.

## Traps

### 1. A transition is a window where the world is half moved

Today a level change happens in one call. A transition stretches it across frames, and
everything that can happen in a frame can now land in the middle of it: F5 and the
level-change save, F6 freeing the actor mid-tween, a dig, a second interact, another actor's
move. Choose where the actor *is* during the transition first (still on the old level, or
already on the new one). Then check each of those against that answer. A swap has to cancel a
transition the way it already cuts off input handlers. Otherwise a tween or timer fires against
a freed actor.

### 2. An effect that belongs to the view must not live on the actor

A fade is presentation, and it follows the shown actor (D-045 lets the view hold one). A delay
before the move is simulation, and it belongs to each actor. If both live in one place, the
second local player, or an NPC taking a ladder, either gets a fade it shouldn't, or nobody does.

### 3. The typed load result changes every load test again

004 kept the dictionary for exactly this reason. Expect a large, mechanical diff. Grep each run
for `Ignoring` and `Parse Error`, because GUT skips a file it can't parse and the suite still
passes.

### 4. Removing the Surface hole doesn't remove it from a save

A saved level is built from the save, not the recipe. An existing slot keeps the hole, so the
by-hand check needs `--new-game`.

### 5. Pruning deletes, and that can't be undone

The moved-aside and broken saves are the evidence D-111 keeps on purpose. A pruning rule that
matches on a file name can also match the live save or its backup if the naming ever changes.
Match the exact patterns (D-123's timestamp), test against a folder that has the live save, the
backup, and one of each kind, and never prune during a load.

### 6. A validator that fails on accepted numbers gets switched off

The Surface's 0.375 s is accepted (D-081). A band check without a recorded exception fails the
build on day one, and a check that's always failing is one that people stop reading.

### 7. Groundwork with no caller rots quietly

Outcomes 10–12 have only tests as callers. Write each against the system it belongs to (the
gatekeeper, the profile), not as a one-off helper, so that 006 and 007 use it rather than work
around it.

### 8. A wide slice hides which part broke

This slice touches saves, the view, fixtures and the actor. Commit by section, run the suite
before each commit, and launch the game by hand at the end of every section that changes
something you can see (002's log).

## Carried into this slice

From [NEXT.md](./NEXT.md) at `c8e5d62`, all of it, each now an item in
[CHECKLIST.md](./CHECKLIST.md):

- **Deferred from 002:** level-change transitions (D-108); moving a fixture; up or down when
  both apply on a ladder (D-106).
- **Deferred from 003:** slot sorting (R-P6); the dead tool-loading code (R-B5); "it's" → "its"
  and comments over 70 characters (R-S4); save-files.md; the autosave interval into the tuning
  profile; pruning old saves; tests for the playtime clocks; settling format version 1.
- **Deferred from 004:** a save whose only actors are NPCs; a typed load result; measuring the
  load time.
- **Carry-forward:** `density` → `hardness`; the appendix's band at −5 and −7, and the content
  validator; the refusal reasons nothing reads; F3 printing a hole as `.`; the temporary Surface
  hole; the coverage figure (95.7% at the end of 004).
