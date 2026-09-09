# UI/UX & Controls

**Gamepad is a primary input target, not a port** ([D-026](./design-decisions.md)). Mouse and
keyboard is an equal-quality alternative, not the assumed default.

---

## 1. Why gamepad-first is the right call here

Three arguments, in order of weight:

1. **It is proven for this exact shape of game.** Core Keeper — tile-based, dig-and-build,
   inventory-heavy — plays excellently on a pad. We are not pioneering.
2. **The audience is on handhelds.** Cosy survival-crafting is one of the strongest genres on
   Steam Deck. Designing for the pad first is the cheapest path to a good Deck experience, and
   the Deck's screen size also forces UI discipline we want anyway.
3. **Gamepad constraints make the mouse UI better.** Bigger targets, no hover-only information,
   no click-drags, no pixel precision. Every one of those is a usability win for mouse users
   too. The reverse retrofit — bolting a pad onto a mouse-designed build mode — is a known and
   expensive failure.

### Binding constraints on every UI in this project

- No interaction may require **pixel precision**.
- No information may be **hover-only**.
- No interaction may require a **click-drag**. Anchor-then-confirm instead.
- Every build placement is **grid-snapped** to a character-anchored cursor.
- Linear structures **auto-route**; the player never traces a path by hand.

---

## 2. Feasibility: the six hard problems

An honest look at where a game like this normally breaks on a pad, and the answer for each.

### 2.1 Precise tile placement → the anchored cursor
A single grid cursor, moved by the right stick, **clamped to a radius of ~5 tiles around the
character**, snapping tile-to-tile with an audible tick and a clear highlight. Mouse drives the
*same* cursor with the *same* clamp, so both inputs have identical reach and identical rules.
`R3` recentres the cursor on the character.

The clamp is not a limitation — it is what makes the stick feel precise, because the cursor
never has far to travel.

### 2.2 A large build catalogue → hotbar plus radial
Eight-slot hotbar on `LB`/`RB`. Hold `LT` for a **radial menu**: outer ring is category
(structural / surfaces / stations / logistics / light / comfort), inner selection is item, with
recents pinned. Radials are gamepad-native and perfectly usable with a mouse.

### 2.3 Walls, floors, chutes and line shafts → hold-to-paint with auto-route
Press to anchor, hold, move the cursor, and the game previews an **L-routed** run from anchor
to cursor with a live material cost. Release to commit, `B` to cancel. No dragging, no
precision, and it is genuinely faster than freehand placement on either input.

### 2.4 Planning a supported hall → rectangle select and column stamp
Anchor one corner, move the cursor, confirm the other — two presses, no drag. Within that
rectangle the game can:

- show the **support overlay** for the proposed excavation *before* you dig it,
- **stamp a valid column lattice** for the current depth and best available material.

This is the case where gamepad is *better* than mouse, and it should be built early because it
turns structural integrity from a tax into a design tool
([digging-and-structure.md §4](./systems/digging-and-structure.md)).

### 2.5 Emergency shoring → a dedicated face button
`D-pad Down` places a timber prop at the cursor immediately, from anywhere, regardless of what
is equipped. During a failure countdown the player must never be fumbling through a menu. This
binding is reserved and must not be reassigned to anything else by default.

### 2.6 Multi-level spatial understanding → the genuinely unsolved problem
See §6. This is the one real UX risk in the design and it deserves prototype time, not a
late-stage menu.

---

## 3. Control scheme

### Gamepad (Xbox labels)

| Input | Action |
|---|---|
| **Left stick** | Move |
| **Right stick** | Grid cursor (clamped, snapping) |
| **RT** | Primary — mine / attack / place |
| **LT** (hold) | Radial build menu |
| **A** | Interact — stations, ladders, doors, NPCs, pick up |
| **B** | Cancel / back / exit build mode |
| **X** | Swap tool (pick ↔ shovel ↔ hammer) |
| **Y** | Toggle build mode |
| **LB / RB** | Cycle hotbar |
| **L3** | Toggle support overlay |
| **R3** | Recentre cursor on character |
| **D-pad ↑** | Toggle lantern |
| **D-pad ↓** | **Place timber prop** (reserved, see §2.5) |
| **D-pad ←/→** | Quick food / quick heal |
| **View** | Map & depth stack |
| **Menu** | Inventory & crafting |
| **LB + RB** (hold) | Reserved |

### Mouse & keyboard

| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Grid cursor — **clamped to the same radius as the pad** |
| LMB | Primary |
| RMB | Interact |
| `E` | Build mode · `Q` radial · `1`–`8` hotbar |
| `F` | Place timber prop · `L` lantern |
| `Tab` inventory · `M` map · `V` support overlay |

Parity rule: **the mouse gets no reach, precision, or information advantage.** If a mouse user
can see or do something a pad user cannot, that is a bug in the design, not a feature.

---

## 4. HUD — present only what is currently true

The default screen should be close to empty. Meters appear when they are relevant and fade when
they are not.

| Element | Placement | Shown when |
|---|---|---|
| **Health** | Bottom-left, small | Below full, or in combat |
| **Hunger** | Bottom-left | Peckish or worse |
| **Exposure** | Top-centre, prominent | Only above ground, only above zero. **Never visible underground** |
| **Lantern fuel** | On the lantern icon | Lantern lit |
| **Carry weight** | Above the hotbar, always | Always — this is the pillar's meter |
| **Depth strip** | Screen edge, thin | Always. Which level you are on, at a glance |
| **Structure warning** | Diegetic first — dust, cracks, audio | Marginal or Failing ceiling nearby |

The exposure meter being **absent underground** is deliberate and important: the HUD itself
should feel different above and below, so coming home is a visual relief.

---

## 5. Inventory & the weight decision

Because weight is the central pressure ([D-013](./design-decisions.md)), the inventory screen's
real job is **helping the player decide what to leave behind.** It must answer that in seconds.

- A **weight bar**, not a slot count, as the headline figure.
- Per-item weight always visible — never hover-only.
- **Sort by value density (value per unit weight).** This single feature does more for the
  hauling loop than any amount of extra capacity, and it is the correct answer to "the pack is
  full" — better decisions, not bigger pockets.
- **Take-this preview:** highlighting a ground item shows the resulting weight before pickup.
- **Overweight is a slowdown, not a block.** You can always stagger home; you will just hate it.

---

## 6. The map & multi-level navigation

The hardest UI problem in the design. Seven stacked maps with no cross-level visibility is a
recipe for players who cannot find their own base.

Approach for pre-alpha:

- **Layer stack view.** One level shown at a time; `LB`/`RB` change layer. The layers
  immediately above and below render **ghosted underneath**, so vertical alignment is legible
  at a glance.
- **Vertical anchors persist across all layers.** Shafts, ladders, chutes, lifts and driveshafts
  draw at full brightness on *every* layer they pass through. These are the landmarks players
  will actually navigate by, and they are the one thing that makes the seven maps read as one
  mountain.
- **Depth strip on the HUD** — a thin always-visible column showing which level you are on and
  how many are below you.
- **Player-placed markers** with a small icon set, visible across layers.

Deferred, but likely worth it later: a **cross-section view** cutting the mountain along a
chosen axis to show shafts in elevation. Expensive, and the single most readable way to show
what the player has built. Revisit once the layer stack view has been tested.

---

## 7. Build mode

- Entering build mode dims the world slightly and shows the grid.
- Valid/invalid placement is shown by **shape and icon as well as colour**.
- Cost preview on the cursor, always, including for auto-routed runs.
- **Blueprint (ghost) placement:** place unaffordable structures as ghosts to be filled in later.
  Cheap to build, enormously useful for planning, and it is the natural hand-off point for the
  deferred worker layer — workers will complete ghosts.
- Removal uses the hammer with the same cursor and the same auto-route.

---

## 8. Accessibility

Not a late pass. Three items here are load-bearing because of choices already made:

1. **The support overlay must not rely on colour alone.** Green/amber/red is the primary
   encoding, but Stable/Marginal/Failing must also differ in **pattern and icon**. This overlay
   is a core mechanic, not decoration.
2. **Dark vision is desaturated by design**, so no critical information anywhere may be encoded
   in hue alone. Hazards must read by silhouette and motion.
3. **Full remapping on both inputs**, hold-vs-toggle options for every hold (overlay, radial),
   and adjustable UI scale for handheld screens.

Also: an option to reduce or disable screenshake, which this game will otherwise use a lot of.

---

## 9. Pre-alpha subset

- [ ] Anchored grid cursor with clamp, on both inputs, at parity
- [ ] Full gamepad map per §3, including the reserved prop button
- [ ] Hotbar + radial build menu
- [ ] Hold-to-paint auto-routing for walls, floors and chutes
- [ ] Rectangle select with support overlay preview
- [ ] HUD: health, hunger, exposure (surface only), lantern fuel, carry weight, depth strip
- [ ] Inventory with weight bar, per-item weight, **sort by value density**
- [ ] Layer stack map with ghosted adjacent layers and persistent vertical anchors
- [ ] Colour-blind-safe support overlay encoding

Cut: column lattice stamp, blueprint ghosts, cross-section view, player markers, UI scaling,
full remapping (ship a fixed sensible map for internal testers).
