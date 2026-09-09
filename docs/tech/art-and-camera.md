# Technical Art & Camera

Not art direction — that comes later and can be written while M0 is underway. This document
fixes only the things every asset and shader made afterwards depends on.

---

## 1. The interaction that had to be resolved first

Three numbers were set independently and turn out to constrain each other:

| | Value | From |
|---|---|---|
| Dark vision radius | 7 tiles | [D-010](../design-decisions.md) |
| Support radius R | up to 8 tiles | [D-014](../design-decisions.md) |
| Widest timber hall at −1 | 17 tiles | [tuning-appendix §9](../tuning-appendix.md) |

If the camera shows 30 tiles across and dark vision reaches 7, the player sees a 15-tile lit
circle in a mostly-black frame — atmospheric, and fine for mining. But it makes **planning a
17-tile hall impossible**, because you cannot see the thing you are designing.

Raising dark vision to match would flatten the mood and undo the light-as-civilisation idea.
So the answer is a third render state.

---

## 2. Tunnel memory — four render states per tile

> **A moleperson knows its own tunnels by feel.**

| State | What you see | Reached by |
|---|---|---|
| **Unknown** | Black | Never visited |
| **Remembered** | Dim structural outline — walls, floors, your own built structures. **No entities, no ore identity, no detail** | Excavated by you, or walked adjacent to |
| **Sensed** | Dark vision: full geometry and entities, desaturated cool grey, low detail | Within 7 tiles |
| **Lit** | Full colour, full detail, **ore identity legible** | Within a light source's radius |

Remembered state solves three problems with one feature:

1. **Hall planning works.** The excavation you are designing is visible in outline well beyond
   your vision radius, so the support overlay has something to draw on.
2. **Navigation works.** Your warren is legible in the dark. You do not get lost in your own base.
3. **It reinforces the theme.** Your tunnels are visible because *you dug them*; the mountain's
   untouched rock stays black. The map of the world is literally the record of your work.

Implementation: two bits per tile (`unknown / remembered / sensed / lit` is derived, not stored —
light and vision are computed, `remembered` is the only persistent bit alongside `visited`).

---

## 3. Camera

| Property | Value |
|---|---|
| **Tiles visible** | **≈30 × 17** — this is the *design constant* |
| Base tile art | **16 × 16 px** |
| Virtual resolution | **480 × 270** |
| Scaling | Integer where possible (1080p = 4×, 2160p = 8×); `canvas_items` stretch |
| Zoom | Fixed during play. **No player zoom control** |

**Tile count is the constant, not resolution.** No display may show meaningfully more of the
world than another — that would be a competitive and design inconsistency, and it would break
the careful relationship in §1.

Steam Deck (1280×800) does not scale integrally from 480×270. Accept a non-integer scale with a
pixel-snapped filter, and expose a **pixel-perfect toggle** that letterboxes at 2×. This is a
graphics-programmer call; the binding constraint from design is only that the tile count stays
≈30 × 17.

### Overlay zoom
Holding the support overlay (`L3`) zooms the camera out to **≈45 × 25 tiles**. This is the one
sanctioned zoom change, it exists specifically so a 17-tile hall fits on screen while planning,
and it is why the overlay is a first-class hotkey rather than a menu
([ui-ux-and-controls.md §2.4](../ui-ux-and-controls.md)).

### Multi-tile structures
Base tiles are 16×16, but windmills, lift cars, smelters, driveshafts and ancestral arches are
authored as **larger sprites spanning multiple tiles**. Detail goes where the player is meant to
look, without paying for a 32px grid everywhere.

---

## 4. The lighting pipeline

Two independent systems that must not be conflated in code:

### 4.1 Underground illumination
- A per-tile **light level** buffer (0–255), accumulated from light sources with radial falloff.
- The tile shader picks between three LUTs by light level: remembered outline → dark-vision grey
  → full colour, blending across the boundary so light *feels* like it spreads.
- **Ore identity is gated on light level ≥ 0.35** ([tuning-appendix §6](../tuning-appendix.md)).
  Below that the ore sprite draws with the generic grey-lump variant. This must be enforced in
  the *renderer*, not by hiding data in the UI — the player should never be able to read ore type
  off a tooltip in the dark.

### 4.2 Surface shade — projected occlusion, not 2D shadow casting
A top-down view has no height, so shadows cannot be raycast in the tile plane. Instead:

```
  Every surface occluder carries a HEIGHT.
  shadow_length = height × cot(sun_altitude)
  shadow_direction = sun_azimuth + 180°
```

A 6-tile-tall ruin wall at 30° sun altitude casts a shadow ~10.4 tiles long. Each occluder
stamps a projected footprint into a **shade grid** (one value per surface tile:
`direct / dappled / occluded`).

Critically: **the shade grid updates on a timer, not per frame.** The sun moves 15° per real
minute ([D-028](../design-decisions.md)), so a **2-second** refresh is over-precise already. This
turns what sounds like an expensive per-frame lighting problem into a cheap periodic grid stamp,
and it should be prototyped in isolation during M4 before any surface content is authored
([pre-alpha-scope §8](../pre-alpha-scope.md)).

Canopy stamps `dappled` rather than `occluded`; player-built awnings stamp `occluded`.

---

## 5. Colour rules

Full palettes and stratum styling are deferred. Three rules are not:

1. **Warm equals yours.** Lit, built, inhabited space is warm. Untouched mountain is cool grey.
   The entire emotional arc of the game is colour spreading into grey, so no unlit natural
   terrain may use warm hues.
2. **Depth reads through architecture, not tint.** Do not tint strata to distinguish them — the
   player should read depth from column density and construction style
   ([base-building.md §3](../systems/base-building.md)). Tinting would make that redundant and
   muddy the light system.
3. **No critical information in hue alone.** Dark vision is desaturated by design, so hazards,
   creatures and the support overlay must all read by silhouette, pattern and motion
   ([ui-ux-and-controls.md §8](../ui-ux-and-controls.md)).

---

## 6. UI layer

- HUD and menus render **unlit**, on a separate canvas layer, unaffected by the lighting pipeline.
- UI pixel scale is independent of world scale and larger — target legibility at Steam Deck size
  first.
- One pixel font, one weight, no anti-aliased text mixed with pixel art.

---

## 7. What is deliberately deferred

Stratum palettes · character and creature design · animation counts and frame budgets · tileset
autotiling rules · particle and screenshake tuning · any final art. None of these block M0, and
all of them are cheaper to decide once something is running.
