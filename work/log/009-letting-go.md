# 009 — Letting go

*Written by Claude, 2026-11-08.*

> Dig until your pack is full and the stone you can't carry falls at your feet. Walk past it
> later with room to spare and it comes back into your pack. Open the inventory, drop the stone
> you don't want, and take the ore you do, even past full, if you're willing to walk home slowly.

**Result:** built in Agent mode on the `slice-009` branch, in three commits: the plan, the
build, and this log. The suite passes: 909 tests in 47 scripts, no skipped files, no leak
warning. Coverage is 97.6% (008 closed at 97.6%). **The by-hand outcomes haven't been walked,
and neither have 008's.** Derik merged 008 untested so this slice could build on it.

---

## What got decided

Three decisions, D-160 to D-162, all Derik's, all settled before building:

- **The scope** (D-160): drops, dropping from the pack, auto-pickup, a take key, and a minimal
  inventory overlay. **Yields and auto-pickup fill the pack to 100%; past that is the take
  key's.** This amends D-158's "no cap" and its pickup limit of 150%.
- **Drops change through the world, per level, are saved and never decay, and are drawn like
  actors in the dark** (D-161).
- **The inventory is an overlay; nothing pauses** (D-162).
- **The bindings,** proposed in the brief and approved: `Tab` / Start for the inventory, `X` /
  pad A to drop one, `Z` / pad X to drop the stack (only while it's open), `T` / pad LB to take.
  LB is reserved in ui-ux for a hotbar that doesn't exist yet.

**Two conflicts caught in planning:**

- The 150% conflict came back. Overflow drops plus pickup to 150% would again have made "above
  150%, no ladders" impossible. Derik chose fill to 100% with a deliberate take key.
- Derik left the inventory screen out of scope but chose to drop from it. The plan built a
  minimal one, and said so.

**Choices made while building, not put to Derik.** He may want to look at these:

- **`Carrying.fits`** is the one answer to "how much of this fits under a limit", for yields
  and pickup.
- **What you drop stays down until you step off its tile.** The world remembers each actor's
  last drop tile (trap 3); the take key ignores that.
- **The take key takes from all nine tiles, whatever the load,** including what you just
  dropped.
- **Drops are drawn as small colored squares** (stone grey, copper orange, timber brown, unknown
  magenta), up to four to a tile, in `DropRenderer`.
- **The overlay is a plain text panel:** a marker on the selected row, then the count, name and
  stack weight, with a key hint at the top.
- **A drop outside its level, or a malformed one, is skipped with a warning on load; an unknown
  item is kept and reported as a load problem,** the same way packs handle one.
- **Two profile numbers:** `auto_fill_limit` (1.0) and `pickup_reach` (1).
- **The build went in as one commit,** not one per section: the input handler, the game scene
  and the tests touch all four sections.

---

## What surprised

**008's tests pinned 008's rules, and two of them changed.** "Yields are uncapped" and "an ore
vein yields 2–4 into the pack" both broke when D-160 sent overflow to the ground. They were
rewritten to state the new rule, not deleted. A test pinning a decision is the right failure
when the decision changes.

**Drop-then-pickup was the trap the brief named, and it would have fired.** A player who
dropped onto its own tile was in reach of it on the next step check. The remembered drop tile
solves it, with a test.

**The input handler's new branches can't be pressed by a test.** Like the rest of the handler,
they read live key state. The logic behind them is tested directly (`_inventory_mode`, the
world's requests); the key routing itself is the by-hand walk's.

---

## What to do differently

1. **(Claude) Keep commits per section even when files overlap.** Staging by hunk, or building
   section by section, would have kept the history readable. One commit for four sections is
   harder to review.
2. **When a decision amends an earlier one, grep the tests for the earlier one's number.** 008's
   "uncapped" test was found by a failing run; a grep for D-158 would have found it first.

---

## Open, carried forward

- **By hand, for Derik: 008 and 009 both.** For 009: a full pack's stone drops where it's dug;
  walking past a drop picks it up to 100%; `T` takes everything in reach; the inventory (`Tab`)
  lists items by value per kilo and drops one (`X`) or all (`Z`); drops show only where you can
  sense them or they're lit; save and relaunch keep them.
- **Drops never decay** (D-160); stone volume, and the "dragon bag" (D-156), wait until they're
  needed.
- **No take-this preview** on the ground (ui-ux §5).
- **Pad LB is contested** when the hotbar arrives.
