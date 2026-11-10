# Slice 011 checklist

Working list for [NOW.md](./NOW.md). **Agent mode for the whole slice** (Derik, 2026-11-09), on a
`slice-011` branch: Claude builds, one or more commits per section, the suite green before each;
Derik merges the PR and verifies by hand. Numbers in brackets are the brief's outcomes.

Ordered so the game runs at the end of every section: tools as items first (nothing visible
changes), then the hotbar (you can swap), then the inventory screen, then the rebinds.

Slice 010's checklist is in git history (last at the 010 close).

---

## A. Decided in planning

*Settled with Derik, 2026-11-09.*

- [x] Scope: tools in hand; reverses D-077 (D-173).
- [x] Pad A takes when there's nothing to interact with (D-167).
- [x] Speed is power × a class-and-kind multiplier; only a pick breaches (D-168).
- [x] Tools are pack items; only the player drops one (D-169).
- [x] One hotbar, tools outside build mode, buildables inside (D-170).
- [x] X stays breach; tools fill slots themselves; an empty slot is bare hands (D-171).
- [x] The inventory screen: focus, assigning, weights, the preview (D-172).
- [x] Breach needs the pick selected; build slots rearrangeable (D-174).
- [x] The numbers and the bindings in the brief, approved with it.

## B. Tools as items

- [x] Tools are items with a class and power, one owner (trap 2); `flint_pickaxe` and `shovel`
  item resources; bare hands as a class, not an item.
- [x] The class-and-kind multiplier table and tool weights in the profile (D-168).
- [x] New games start with the pick and the shovel in the pack.
- [x] Overflow never drops a tool (trap 3). [7]
- [x] Tests: the table for every class and kind; the pick's speeds unchanged except rubble; an
  overflow keeps tools. [1, 7, 9]

## C. The hotbar

- [x] Eight tool slots and eight build slots on every actor (D-045), saved with the pack;
  starting layout; old saves get it with a problem noted (trap 6). [8, 9]
- [x] The selected slot's tool, or bare hands, replaces `Actor.equipped` everywhere (trap 1).
- [x] Breach refused without a selected pick, with the notice (D-174). [2]
- [x] A tool entering the pack takes the first empty slot; dropping one empties its slot (trap 4).
  [6]
- [x] The bar at the bottom center under the carry bar; its contents follow build mode. [1, 3]
- [x] Selection: `1`–`8`, click, wheel, pad LB / RB; 010's build-item keys absorbed. [1, 3]
- [x] Tests: selection, the build-mode swap, the breach refusal, slot filling and emptying, NPCs
  dig with their own tool, save and old save. [2, 3, 6, 8, 9]

## D. The inventory screen

- [x] A focus highlight: D-pad, arrows, hover and click; drop one and stack act on the focus. [4]
- [x] A weight bar at the top; every row's weight; still sorted by value per kilo. [4]
- [x] Tools and Build sections; assigning the focused entry to a slot (trap 7). [4]
- [x] The take-this preview for drops in reach. [5]
- [x] Tests: focus movement and wrap, assigning, the preview's number. [4, 5]

## E. Rebinds

- [x] Take moves to pad A after interact (trap 5); keyboard `T` stays; the notice says it took. [5]
- [x] `project.godot`: hotbar slots, wheel, LB / RB; take off LB; inventory assign on Y.
- [x] Tests: A climbs at a ladder and takes elsewhere. [5]

## F. Done

- [x] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
- [x] `python scripts/coverage.py` run; uncovered lines looked at (010 closed at 96.6%).
- [ ] By hand: outcomes 1–8 walked in one sitting, launched outside the editor at least once.
- [x] Claude reviews the slice.
- [x] Claude writes `log/011-tools-in-hand.md`.
- [x] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Not in this slice, worth knowing

- **The radial menu** (LT), the **hammer** (removal) and the **lantern** (D-pad ↑).
- **Tool tiers in use, crafting and durability.**
- **Blueprints** (ui-ux §7).
- **Cut stone columns,** still the next support kind.
