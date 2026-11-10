# 011 — Tools in hand

*Written by Claude, 2026-11-09.*

> Press 2 and the pick in your hands becomes a shovel: dirt flies, rock barely scratches. Open
> the pack with the pad alone, move the shovel to slot 5, see what the stone at your feet would
> weigh before you take it. Drop your pick, and you're digging with your hands.

**Result:** built in Agent mode on the `slice-011` branch. The suite passes: 1008 tests in 49
scripts, no skipped files. Coverage is 96.1% (010 closed at 96.6%). The gap is the hotbar's and
the inventory's drawing, a mouse click on a slot, and the notice's text paths, which headless
Godot can't reach. **No by-hand walk has been done, of this slice or of 008 to 010.**

---

## What got decided

Eight decisions, D-167 to D-174, all Derik's, settled in planning, plus the numbers and bindings
approved with the brief, each as its own question:

- **The scope** (D-173): tools in hand, reversing D-077, ahead of "Getting it home".
- **Pad A** interacts first and takes with nothing to interact with (D-167).
- **Speed** is power times a class-and-kind multiplier, and only a pick breaches (D-168).
- **Tools are pack items;** only the player drops one, never an overflow (D-169).
- **One hotbar,** with tools outside build mode and buildables inside it (D-170).
- **Pad X stays breach,** tools fill slots by themselves, and an empty slot is bare hands (D-171).
- **The inventory screen** has focus, assigning, weights and the preview (D-172).
- **Breaching needs the pick selected,** and build slots can be rearranged (D-174).
- **Numbers:** the pick is ×1 on rock and dirt and ×0.5 on rubble (0.8 s). The shovel is ×0.4 on
  rock, ×2 on dirt and ×1 on rubble (0.4 s, the tuning appendix's rubble time). Bare hands is ×1
  at power 8. The pick weighs 3 kg and the shovel 2.5 kg.

**Changed while building, not put to Derik.** He should look at the first of these:

- **The inventory's sections switch with the arrow keys and D-pad ←/→, not Tab and LB/RB.** The
  brief said Tab, but Tab is the key that opens and closes the inventory, so it can't also switch
  sections. ←/→ mirror ↑/↓, which move the focus, on both inputs. That also leaves LB/RB to do
  one job in the inventory: moving the slot being chosen. I caught this while building, not in
  planning. It's a slip in the brief I wrote.
- **A click on a hotbar slot with the inventory open assigns the focused entry** rather than
  selecting the slot. That matches the number keys (trap 7), and gives the mouse a way to assign
  without dragging.
- **The take notice:** "Took 2 Stone, 1 Copper ore." or "Nothing in reach to take." It only
  answers the take key and pad A, never auto-pickup.
- **Pad A in the inventory** still drops one (009's binding), except while choosing a slot,
  when it confirms. B cancels. Neither drops.
- **A second player spawned later starts empty, so they dig bare-handed.** Only a new game's
  first player gets the starting items (008's rule), and tools are starting items now.
- **An item id for each tool:** `flint_pickaxe` and `flint_shovel`. The pick's `ToolData` is the
  same file as before. Bare hands is a `ToolData` with no item (`bare_hands.tres`).
- **`ToolData.speed` is now `power`,** with a `tool_class`. The class enum isn't saved anywhere,
  since a tool is saved by its item id.
- **Hotbar slots are saved per actor** under `"hotbar"`: eight ids, eight kinds, and the two
  selections. A player loaded from a save with no `"hotbar"` is given the profile's starting
  tools, and the load's problems list says so (trap 6).
- **The carry bar moved up** to make room for the hotbar, and the notice moved above both.

---

## What surprised

**Setting the loaded hotbar before the loaded pack wiped every saved slot.** An actor is built
with an empty pack, so a hotbar given to it first was checked against that empty pack, and every
slot pointing at a tool it didn't hold yet was cleared. The round-trip test caught it. The load
now sets the pack first, and a comment on `Actor.hotbar` says why.

**A key tap in a test leaks into the next test.** In this Godot version, an action pressed and
released within one frame still reads as "just pressed" for the rest of that frame. Tests run
back to back in the same frame, so one test's tap fired pad A in the next. Waiting out a frame
broke the older climbing tests the other way. The new handler logic is now tested through
methods (`select_slot`, `step_slot`, `interact_or_take`, and `_input` with an
`InputEventAction`), and the bindings are tested from the input map. The cost: no test drives
"pad A confirms and doesn't drop" through `Input`. The order in `_inventory_mode` covers it, and
the walk should check it.

**The mouse wheel had to be read as events.** A wheel notch presses and releases in one frame,
which physics-tick polling can miss. All the hotbar's selection keys are read in `_input` for
that reason, so they behave alike.

**Polled clicks don't respect the GUI.** The hotbar on screen accepting a click doesn't stop
`Input.is_action_pressed("primary_action")` from seeing it. The handler asks whether the mouse
is over a slot before digging or placing.

---

## What to do differently

1. **(Claude) Check a brief's bindings against the keys the slice already uses, not just
   against `project.godot`.** The Tab clash was visible in the brief's own table.
2. **(Claude) Two commits for the build, not one per section.** Section B (tools as items, the
   hotbar's data, saves) is its own commit. Sections C to E share the input handler, and the
   handler calls the inventory's new methods with static types, so every split I tried left a
   commit that doesn't parse. 010's lesson was half applied. Building the handler's calls last
   would have let each section land alone.
3. **Walk 008 to 011 together.** Four slices of by-hand outcomes are stacked up now.

---

## By-hand walk (nothing here has been done)

From the brief, in order:

1. A new game: pick in 1, shovel in 2. Select the shovel with `2`, a click, the wheel or pad RB.
   Dirt digs faster with it, rock slower.
2. With the shovel selected, `R` / pad X says "Breaching needs a pick."
3. `B` swaps the bar to ladder and prop. Leaving build mode brings the tools back, still
   selected.
4. The inventory with the pad alone: the D-pad moves the focus and ←/→ switch sections. Move the
   shovel to slot 5 (Y, RB, A) and the ladder to build slot 3. On the keyboard, focus a tool and
   press a number. While choosing a slot, pad A puts the tool there and doesn't drop it.
5. Stand on drops: the preview shows the load after taking them. Pad A away from a ladder takes
   them, and the notice says what.
6. Drop the pick: its slot empties and you dig bare-handed. Walk back over it and it returns to
   the first empty slot.
7. Overflow with stone: only stone drops.
8. Save and relaunch: the slots, the selection and the build slots are kept.
