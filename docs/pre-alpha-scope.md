# Pre-Alpha Scope

**Internal only. Not a demo, not a vertical slice for show. An experiment.**

---

## 1. The thesis

> **Is hauling material up a mountain — and engineering your way out of that problem —
> actually fun?**

Everything in this build exists to make that question answerable. Everything not needed to
answer it is cut, including things that are certainly in the final game.

This is the riskiest assumption in the design. If the answer is no, pillar P1 dies and the
project needs rethinking before another line of content is made. Finding that out cheaply is
the entire point of pre-alpha.

### What we are *not* testing
- Whether mining feels good (it will; this is a solved problem in the genre).
- Whether the art style works.
- Whether the story lands.
- Whether combat is satisfying.

---

## 2. World scope

**Surface + levels −1, −2, −3.** Three levels is the minimum depth at which hauling genuinely
hurts and the chute → winch → hoist ladder gets exercised end to end. Two would let the pillar
read as fine when it is not.

| Level | Included | Purpose in the experiment |
|---|---|---|
| Surface | Small bounded area, 2 cave mouths, ruins, one trader camp, one crop field | Exposure routing; the windmill site |
| −1 Rootshelf | Small, safe, fully procedural | Home base. Where hauled goods must arrive |
| −2 Greyseam | Medium, copper/tin/coal | The first real haul. Where chutes get invented |
| −3 Old Terraces | Larger, iron, **3 authored ruin POIs**, 1 gated region (`CRUSHED`) | Distance pain, blueprints, and one thing left behind |

Level −3's gated region is `CRUSHED`, not flooded — water is out of scope for pre-alpha, so the
gate is rubble. It must be a region the player **cannot** open,
to validate that "levels are open; regions are earned" ([D-012](./design-decisions.md)) reads
as intriguing rather than as a bug.

---

## 3. In scope

Consolidated from each system document's *pre-alpha subset*.

**World**
- Stacked level container with shared coordinate origin and working vertical alignment
- Procedural generation for 4 layers with region partitioning and access classes
- 3 authored ruin prefabs stamped into −3
- Generation validator enforcing the §3 guarantees of [world-and-generation.md](./world-and-generation.md)

**Digging & structure**
- Mine / breach / clear, tool tiers flint → bronze → iron, per-stratum hardness
- Support rule with depth-scaled R; timber props and cut stone columns
- Stable / Marginal / Failing states, telegraphed countdown, local collapse with rubble
- Buried-not-destroyed rule for built objects
- **Support overlay** with tints and radius rings

**Vertical logistics & power** *(the thesis — build this well)*
- Weight-limited inventory, no teleport
- Ladder, chute, hand winch, powered hoist
- Windmill, driveshaft, one level of line shaft, proportional brownout

**Light & exposure**
- Dark vision: monochrome low-detail outside light radius
- Ore identification gated on tile light level
- Torch, oil lantern with fuel, fixed brazier
- Exposure meter with four bands; three shade tiers as a per-tile flag
- Moving sun azimuth casting shadows from walls, ruins, canopy, and the mountain
- Ash paste, shade posts, awnings

**Building & living**
- Floors, walls, doors, workbench, hearth, smelter, forge, crates, braziers, bed
- Room detection with Rough / Snug / Fine comfort tiers
- Hunger with four states; 2 meals; cave fungus beds; compost from spoil; one surface crop

**UI & controls** *(gamepad-first, [D-026](./design-decisions.md))*
- Anchored grid cursor with clamp, at parity on gamepad and mouse
- Full gamepad map, including the reserved timber-prop button
- Hotbar + radial build menu; hold-to-paint auto-routing; rectangle select
- HUD: health, hunger, exposure (surface only), lantern fuel, carry weight, depth strip
- Inventory with weight bar, per-item weight, **sort by value density**
- Layer stack map with ghosted adjacent layers and persistent vertical anchors
- Colour-blind-safe support overlay encoding

**Creatures & death**
- Melee swing, dodge
- Root worm, cave cricket, seam lurker (light-avoidant), scrub hound
- Death → respawn at bed → Marrow-Ache tier 1

**NPCs**
- One travelling trader at a fixed surface camp
- Two or three Upper Shelf NPCs giving early objectives

---

## 4. Explicitly out of scope

Levels −4 through −7. Lift cars and ancestral lift cores. Pumps and drainage. Water beyond
"this region is impassable". The upward cascade and reinforced floors. Iron-braced columns and
ancestral arches. Flywheels, gearboxes, clutches, transmission loss. Weather variability (fix
wind at a constant). Cloaks, lenses, saplings. Ranged combat, blocking, guardians. Recruitment
and **the entire worker layer**. All water and drainage, including chamber connectivity and
shaft flooding. Co-op networking (but see §7). Title screen polish, audio
beyond function, final art.

---

## 5. The intended first session

Write the content so an unguided tester's first 60–90 minutes goes roughly like this. If it
does not, the build is wrong regardless of what the feature list says.

1. Wake on −1. Dig, find flint and fungus, make a workbench and a bed. Cosy, no pressure.
2. An elder points down. Breach the floor to −2. It is dark and the ore is grey.
3. Carry a lantern. The grey becomes copper. Fill your pack. **Realise you cannot carry it all.**
4. Trudge back up the ladder twice. Feel it.
5. Build a chute. Realise it only goes *down*. Feel that too.
6. Build the hand winch. It works, and it is tedious, and that is intentional.
7. Go outside at dawn for timber. Get caught by the sun. Learn what shade is for.
8. Reach −3. It is bigger, there is a ruined terrace, and half of it is behind rubble you have
   no way to shift.
9. Find a blueprint. Build a windmill on the surface, run a driveshaft down two levels, and
   power a hoist.
10. **Stand at the top of the shaft and watch ore come up without you.**

Step 10 is the moment the thesis is testing. Everything before it is setup.

---

## 6. Success criteria

Falsifiable, judged on 5–8 unguided testers.

| # | Criterion | Threshold |
|---|---|---|
| 1 | Testers build a chute **unprompted** before their 5th expedition | ≥ 4 of 5 |
| 2 | Testers describe hauling as *a problem they wanted to solve*, not *a chore* | majority, in their own words |
| 3 | Powering the first hoist is named as a session highlight | ≥ half |
| 4 | Testers site a smelter near the mine rather than at home, without being told | ≥ 2 of 5 |
| 5 | Nobody abandons a session out of backtracking fatigue | 0 |
| 6 | The gated region on −3 is described as intriguing, not broken | ≥ 4 of 5 |

Criterion 5 is the kill switch. If weight-limited hauling reads as tedium rather than as a
design problem, [D-013](./design-decisions.md) must be reopened — **and the answer is cheaper
early chutes, never bigger pockets.**

---

## 7. Milestones

Each milestone has an **exit criterion**: a testable statement, not a feeling. A work unit is
done when it contributes to an exit; a milestone is done when its exit passes.

UI work is assigned explicitly, because it is not a polish pass — the support overlay and the
layer-stack map are *mechanics*, and shipping them late invalidates the milestones that depend
on them.

| M | Name | Systems | UI in this milestone |
|---|---|---|---|
| **M0** | Foundation | Tile grid, stacked depths with shared origin, camera, save/load, actor-agnostic entity model | — |
| **M1** | The verb | Mine / breach / clear, tools, per-stratum hardness, spoil, weight-limited inventory | Anchored grid cursor at input parity; hotbar; carry-weight HUD |
| **M2** | Structure | Support rule, three states, telegraphed countdown, collapse, rubble, burial-not-destruction | Support overlay + overlay zoom; colour-blind-safe encoding; reserved prop button; rectangle select with overlay preview |
| **M3** | Depth | Procgen for 4 layers, regions and access classes, ladders and chutes, dark vision, lanterns, ore-ID gating | Tunnel-memory render; layer-stack map; depth strip; inventory weight bar + **sort by value density** |
| **M4** | Surface | Exposure, moving sun and cast shadows, shade tiers, cave mouths, timber and crops, trader | Exposure HUD (surface-only visibility) |
| **M5** | **The thesis** | Hand winch, windmill, driveshaft, line shaft, powered hoist, proportional brownout | Power/brownout readout |
| **M6** | Living | Building set, room detection and comfort, hunger and meals, bed, death, Marrow-Ache | Radial build menu; hold-to-paint auto-routing; hunger HUD; room/comfort readout |
| **M7** | Content & tune | Authored −3 ruins, blueprints, fauna, combat values, balance pass | Polish only |

### Exit criteria

| M | Exits when |
|---|---|
| **M0** | The six checks in [world-runtime §10](./tech/world-runtime-and-persistence.md) pass — including **no `Player` singleton anywhere in the codebase** and a rate machine accruing correctly across save/load |
| **M1** | A tester digs a 20-tile tunnel and fills a pack; measured dig times match the §4 formula within 5%; walk speed visibly degrades with load and ladders refuse above 150% |
| **M2** | An unsupported 20-tile span reliably telegraphs and collapses; a prop placed during the countdown cancels it every time; the overlay correctly predicts failure **before** the player digs; a buried workbench survives and is recovered by clearing rubble |
| **M3** | Four depths generate, validate and load; a shaft dug at (x, y) aligns across depths; a modified world round-trips through save/load; **a tester returns to base from an unexplored area using only the map, with no verbal hints**; ore cannot be identified unlit |
| **M4** | The sun sweeps and shadows move on a 2s refresh; a tester reaches a resource cluster at dawn and returns without going Sunstruck; the same trip at noon without shade reliably fails |
| **M5** | A surface windmill powers a hoist at −3 through a driveshaft; **ore accrues while the player is on another level and across a save/load**; adding a second hoist visibly browns out both |
| **M6** | Death → respawn at bed → Marrow-Ache, with comfort tier measurably changing recovery time; a 60-minute session ends with at least one completed structure |
| **M7** | The six success criteria in §6 are run against 5–8 unguided testers |

M0 must land the **actor-agnostic entity model** and the **shared coordinate origin**. These
are the two things that are expensive to retrofit and cheap to get right now
([D-004](./design-decisions.md), [world-and-generation §1](./world-and-generation.md)).

M3's map criterion is deliberately phrased as a *tester behaviour*, not a feature list — the
multi-level navigation risk is the one UX problem in this design that cannot be judged by
inspection.

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| Hauling reads as tedium, not challenge | Criterion 5 is a hard kill switch. Tune with cheaper chutes and shorter routes, never with capacity |
| Structural integrity feels like an arbitrary tax | Ship the overlay in M2, not as polish. It is the system's UI, not a nicety |
| Moving-shadow exposure is expensive to render performantly | Prototype the shadow pass in M4 in isolation before committing surface content |
| Three levels is not deep enough for the pillar to bite | Route lengths are tunable; if the pain is too mild, lengthen −2 → −1 travel before adding a level |
| Scope creep from the deferred worker layer | It is not in this build. Not a partial version, not a stub |
| Seven stacked maps leave players unable to find their own base | Prototype the layer stack map in M3 alongside procgen, not as a late menu ([ui-ux-and-controls.md §6](./ui-ux-and-controls.md)) |
