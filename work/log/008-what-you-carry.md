# 008 — What you carry

*Written by Claude, 2026-11-08.*

> Dig a tunnel and your pack fills: a stone from every wall, copper from every vein. Fill it and
> you feel it in your legs, and above half again over the limit, the ladder home won't take
> you. You start with ten timber, and every ladder you place costs four.

**Result:** built in Agent mode on the `slice-008` branch, in six commits: the plan, then one per
section. The suite passes: 890 tests in 46 scripts, no skipped files, no leak warning. Coverage
is 97.6% (007 closed at 97.5%). **The by-hand outcomes haven't been walked.** Claude didn't launch
the game, because a launch reads, writes and prunes the real save slot.

---

## What got decided

Four decisions, D-156 to D-159, all of them Derik's, all settled before building:

- **The scope** (D-156): yields, a 60 kg pack, the load curve, the carry HUD, 10 starting timber
  and 4 per ladder. No shedding: a stuck player restarts, and shedding is the next slice.
  Derik's **"dragon bag" yield randomizer** is recorded there as deferred.
- **Items and packs** (D-157): the full content-schema `Item` as `.tres` files and a registry; a
  pack on every actor, saved in its entry; unknown items kept and reported.
- **Yields** (D-158): into the digger's pack, **uncapped**, so the over-150% band is reachable.
  Rock gives 1 stone, dirt nothing, veins 2–4 ore. Derik's model for later is recorded there: a
  yield that doesn't fit becomes a drop, and players pick drops up from adjacent tiles up to
  150%.
- **The cost, the HUD, the ladder rule** (D-159): one cost rule shared by the gatekeeper and the
  preview; a bottom-center bar and "20 / 60 kg"; the 150% limit in the Ladder rule.

**A conflict caught in planning:** Derik first chose a hard cap at 150% and kept D-030's
"above 150%, no ladders". With a cap at exactly 150%, that rule could never fire. Put back to
him, he chose no cap.

**Choices made while building, not put to Derik.** He may want to look at these:

- **`Item` and `ItemRegistry` live in `src/entity/items/`, beside `ToolData`.** The first draft
  made a `src/items/` folder that the coding standards' layout doesn't have; it was moved
  before anything was committed.
- **`ItemRegistry` is a static class that loads on first use, not an autoload.** That's no
  project.godot edit and no global state; the items are fixed data like the level recipes.
- **`Carrying` (the load curve) in `src/entity/`, and `Building` (costs) in `src/world/`,** as
  static rules taking the profile, like `Digging` (D-150).
- **The load curve is stored as multipliers of walk speed:** (50%, 1.0), (80%, 0.84), (100%,
  0.72), (150%, 0.44), and 0.32 beyond. That's the appendix's 5.0 → 4.2 → 3.6 → 2.2 → 1.6
  tiles/s, scaled to the profile's walk speed.
- **Ore counts come from a generator per world, seeded from the world seed.** It isn't saved, so
  a load starts a fresh sequence.
- **The ore-to-item mapping (`copper` → `copper_ore`) is a constant in `Digging`,** until
  content-schema's `OreType` is built.
- **`Ladder.can_climb` is the rule; `Actor.interact` asks it** and announces a new
  `World.climb_refused`, which `RefusalNotice` shows as "Too heavy to climb."
- **Placeholder values:** stone is worth 1, copper ore 6, timber 2; every stack holds 999.
  Nothing reads them yet.
- **The cursor draws the cost** ("4 timber") beside itself in the cursor's color.

---

## What surprised

**500 tests failed at once, and it was one missing re-import.** The new `Building` class wasn't
in Godot's class cache, so `world.gd` failed to load and every test that touched a world went
down. The tooling notes name this trap; the re-import was skipped once. The failure's size gave
it away: hundreds of failures from one change is a load failure, not hundreds of bugs.

**The 150% conflict was in the decisions, not the code.** Two answers that each made sense alone
couldn't both hold. Checking new decisions against the existing ones they touch caught it
before anything was built.

**The blank-test-world trap came back.** A test world of blank levels generated the real −2
when an actor reached −1, and the cross-level check rightly failed. It's the third time since
D-143. Every hand-built test world that an actor descends in needs its level below.

---

## What to do differently

1. **(Claude) Re-import after every new `class_name`, every time.** Better: a test helper or the
   test script could re-import first. Worth proposing to Derik.
2. **When two decisions name the same number, check them against each other.** The cap and the
   ladder rule both said 150%.
3. **A test-world helper that includes the level below.** `Worlds.with_levels` could add a blank
   level under the deepest one asked for, so arrivals never generate the real one. Worth doing
   next time a test needs it.

---

## Open, carried forward

- **By hand, for Derik:** a new game shows 20 / 60 kg; digging rock adds 3 kg, dirt nothing,
  copper 10–20 kg; walking slows as the pack fills; past 150% a ladder refuses with "Too heavy
  to climb."; ladders show and take 4 timber until there aren't 4; save and relaunch keep the
  pack.
- **A full pack can't be emptied** (accepted, D-156): shedding weight is 009.
- **Drops** (D-158's model) aren't built.
- **The "dragon bag" randomizer** (D-156) isn't built.
- **No inventory screen and no value-density sort** (ui-ux §5).
