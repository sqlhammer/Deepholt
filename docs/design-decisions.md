# Design Decision Log

Append-only. Each entry records a decision, the reasoning, and what it forecloses.
If a decision is reversed, add a new entry rather than editing the old one.

---

### D-001 — The world is a stack of discrete top-down levels
**Decided.** Each level is its own top-down map in Core Keeper's visual idiom; the player
occupies one at a time. Ladders, shafts, chutes and lifts connect them.

*Why:* preserves the target art style and camera, and makes vertical logistics a designed
system rather than a traversal convenience. A side-view cross-section would have read
verticality more clearly but abandons the entire visual reference.

*Forecloses:* continuous falling/gravity platforming; seeing the mountain in section.
*Open:* whether open shafts render a dimmed parallax of the level below (deferred, see D-011).

---

### D-002 — The mountain is a cone; deeper levels are wider
**Decided.** Level −1 is a small pocket. Each level down is substantially larger in playable
area. The widening stops beneath the mountain's footprint.

*Why:* free difficulty and scope pacing; "we are out of room" becomes an organic motive to
descend; gives the world a shape with a top, middle and bottom instead of an infinite plane.

*Forecloses:* Core Keeper-style unbounded lateral exploration at every depth.

---

### D-003 — Sunlight is a hazard; shade is a resource
**Decided.** Direct sun fills an exposure meter. Shade slows or stops it. Sun angle changes
across the day, so shade is *dynamic* and surface travel is a routing problem, not just a
timer. Modelled on V Rising's sunlight system. See [systems/light-and-sunlight.md](./systems/light-and-sunlight.md).

*Why:* inverts the genre's default light rule, makes "you are not human" mechanical rather
than cosmetic, and turns the surface into a raid target with its own infrastructure-based
progression curve that mirrors underground tunnelling.

*Forecloses:* casual daytime surface play; a surface designed without authored shade.

---

### D-004 — Solo-complete, co-op-shaped
**Decided.** Pre-alpha and shipping game are fully satisfying single-player. No system may
assume exactly one actor: world state, base ownership, saves and the later worker layer are
specified so drop-in co-op can be added without a rewrite.

*Why:* Core Keeper's audience is heavily co-op; retrofitting multiplayer is the classic
project-killing rewrite. Building it in pre-alpha would roughly double first-build cost.

---

### D-005 — Premise: descending into your own history
**Decided.** The molepeople are a diminished people. The deep warrens were abandoned
generations ago after an event at the base of the mountain; survivors retreated to the thin
upper level. The player digs *down* to re-settle, moving backwards through their own
civilisation's ruins. The bottom of the mountain is the reason they left.

*Why:* one authored asset does three jobs. A ruined lift shaft is a story beat, a logistics
upgrade, and a hand-crafted POI inside a procedural level. Recruitment stops being a system
and becomes *finding survivors*. Technology is **recovered from below**, not invented above,
which makes the descent the tech tree.

*Forecloses:* a blank-slate pioneer framing; molepeople as newcomers to this mountain.

---

### D-006 — Survival pressure: hunger, light, exposure. Nothing else.
**Decided.** Three managed pressures: **hunger**, **portable light/fuel**, and **sun
exposure**. No thirst, no temperature, no air quality.

*Why:* each of the three maps directly onto a pillar (living, digging, surfacing). Thirst and
temperature would add meters without adding decisions.

---

### D-007 — Death costs time, not property
**Decided.** Death drops nothing. No corpse run. Respawn at your bed with a lingering debuff
(working name **Marrow-Ache**) lasting roughly one in-game day: reduced movement speed,
excavation speed, and **manual** crafting speed. Repeat deaths while afflicted deepen the
debuff up to a capped tier.

*Why:* removes the genre's single most tedious ritual (walking back to your body) while still
making death sting. The punishment is a lost *day of productivity*, which is legible and
recoverable.

*Consequence to preserve:* because only **manual** crafting is slowed, the later
moleperson-worker layer makes death partly survivable through good workshop design. Death
becomes an argument for automation rather than a tax on inventory. Worker crafting must
therefore be immune to Marrow-Ache.

---

### D-008 — Combat is present but secondary
**Decided.** Simple melee/ranged action combat. Deep fauna and hazards make expeditions
risky and make lit, defended tunnels valuable. A small number of set-piece guardians gate
strata. Combat never becomes the reason to play.

*Forecloses:* Core Keeper-parity boss/weapon-tier progression as a headline system.

---

### D-009 — The surface is ruined and depopulated
**Decided.** No living society above. Scavengeable ruins, weather, wildlife, and a handful of
scattered survivors, hermits and wandering traders who serve as early NPCs, POI anchors, and
the source of recruitable outsiders later.

*Why:* cheap to build, atmospheric, explains the absence of outside help, and pairs with D-005
— the surface fell too. Both worlds are ruins; only one of them is yours.

*Forecloses:* faction politics, towns, a surface economy of scale.

---

### D-010 — Dark vision: light is capability, not survival
**Decided** (ratified; was Proposed). Molepeople see in the dark natively, but in low-detail
monochrome. Light restores colour and fine detail — and **ore cannot be identified by type
without it**. Unlit tunnels are navigable but not workable.

*Why:* makes light continuously desirable without ever being a frustration timer, and gives
the warren a striking visual identity: colour and warmth radiating out into grey stone.
Inverts Core Keeper a second time — there, light is required; here, light is *civilisation*.

---

### D-011 — Open shafts render the level below
**Deferred.** Revisit once a level is playable and we can judge whether spatial legibility
across levels is actually a problem.

---

### D-012 — Descent is gated by supply capability and recovered tech, at region level
**Decided.** You can reach and work any level once your tool can breach its floor. What you
cannot do is *expand into* certain regions of it without the relevant technology — drainage
for flooded regions, deep shoring for crushed and unstable ones, cutting or keys for sealed
ones. Principle: **levels are open; regions are earned.**

*Why:* keeps the vertical logistics pillar as the actual progression system, permits reckless
peeking ahead, and leaves the player a visible list of things to come back for. Avoids both
the shopping-list feel of pure tool gating and the pacing handover of boss gating.

*Constraint on generation:* ≥40% of every level is open on arrival, the descent point is
always reachable through open regions, and every level has at least one gated region.

---

### D-013 — Inventory is weight-limited; there is no teleport
**Decided.** Carry capacity is weight, ore is heavy, and there is no warp home or linked
storage.

*Why:* the entire vertical logistics pillar is downstream of hauling being annoying. If the
player can pocket 900 iron and warp home, chutes, hoists and lifts are decoration. **This
decision protects P1 and must not be softened without re-examining the pillar.**

*Watch item:* early-game backtracking. Monitor in playtest; the answer is cheaper early
chutes, never bigger pockets.

---

### D-014 — Structure: support radius, shrinking with depth
**Decided.** Every ceiling tile must be within R tiles of a support. R falls from 8 at −1 to
3 at −6. Better column materials add R back (timber +0 → ancestral arch +5).

*Why:* legible, cheap to compute, teachable with an overlay. Depth removes your architecture
and technology returns it, so progression is visible as *room shape* — a screenshot's depth
is readable from how densely it is pillared.

---

### D-015 — Collapse is telegraphed, local, and rarely cascades upward
**Decided.** 30–60s escalating warning, cancellable by placing a support. Failure fills tiles
with clearable rubble, damages actors, and **buries but never destroys** built objects. A
collapse of ≥25 contiguous tiles under an unreinforced floor may fail the floor above,
propagating **at most one level**. Reinforced Floor is a cheap buildable counter.

*Why:* punishing enough to teach the lesson the ancestors failed, never enough to ruin a save.
The cascade lets the player re-enact the disaster; the reinforced floor makes protecting your
home a known, affordable action.

*Keep:* deliberately over-digging to open a shaft is a legitimate emergent tactic. Do not
patch it out.

---

### D-016 — Power is mechanical, wind-sourced, surface-generated
**Decided.** Windmills on the surface drive a vertical driveshaft down through the levels,
distributed on each level by line shafts and belts. ~5% transmission loss per level. Overload
causes **proportional slowdown**, never hard cutoff. Flywheels bank surplus.

*Why:* gives the surface a permanent role beyond raiding, makes power a multi-level
construction project rather than a placed generator, and — with wind and sun both weather-
driven — makes a **clear calm day** the worst day in the game. One weather system, opposed
pressures in two places.

---

### D-017 — Water is region-level state, not a fluid simulation
**Decided.** Flooded regions drain as discrete projects in stages, not as per-tile fluid.

*Why:* fluid sim is a multi-month schedule risk with unpredictable physics bugs, and it does
not improve the interesting decision — *which region do I drain first and can I power it* —
which survives the simplification intact.

---

### D-018 — The ending is reconnection, not a boss
**Decided.** The bottom of the mountain holds a surviving molepeople community, cut off for
generations by rubble and water. The climax is breaking through to them with pumps, shoring
and a restored lift.

*Why:* makes the entire tech tree *the plot* rather than a means to it, and pays the descent
out in **people**, which is precisely what the deferred worker/settlement layer needs as fuel.

---

### D-019 — Tone is warm and adventurous throughout
**Decided.** Core Keeper's register at every depth. Ruins read as marvels to reclaim, not
graves. Nothing beneath the mountain hates you.

*Forecloses:* horror turns, hostile deep-molepeople, melancholy art direction.

---

### D-020 — Seven levels below the surface
**Decided.** Three approach strata (−1..−3), three disaster strata (−4..−6), one floor (−7).
Each level ~1.6× the playable area of the one above through −6; −7 breaks the pattern.

---

### D-021 — Food is two agricultures plus meaningful buffs
**Decided.** Underground fungus and grub culture, surface sun-crops, and cooked meals that
grant timed buffs. Hunger itself stays gentle and non-lethal for a long time.

*Why:* at least one meal buff (**hearty stew, + carry weight**) targets the central pillar
directly, so meal prep becomes expedition planning rather than a parallel meter minigame.
Surface crops also give the player a third way to interact with the sun mechanic.

---

### D-022 — Rooms are detected and scored; comfort speeds Marrow-Ache recovery
**Decided.** Enclosure detection scores rooms on light, materials, furniture and decoration.
Tiers Rough / Snug / Fine / Grand shorten post-death recovery, and later gate nothing but
recruitment appeal.

*Why:* decoration becomes insurance against your worst moments instead of vanity, and it is
the same score the deferred worker layer needs for "would someone want to live here?".

*Anti-coercion rule:* comfort must never gate progression, tech, or content.

---

### D-023 — The pre-alpha exists to test whether vertical logistics is fun
**Decided.** One thesis, one experiment. Surface + levels −1 to −3. Everything not required to
answer that question is cut, including things certainly in the final game.

*Why:* it is the riskiest assumption in the design and the one whose failure would invalidate
the most work. Testing it cheaply is the whole purpose of a pre-alpha.

*Kill switch:* if unguided testers abandon sessions from backtracking fatigue, [D-013](#d-013--inventory-is-weight-limited-there-is-no-teleport)
is reopened — and the answer is cheaper early chutes, never bigger pockets.

---

### D-024 — How outsiders become molepeople
**Open.** Gradual adaptation, a cultural rite, or nothing at all (they stay outsiders and
simply work for you). Has real tonal consequences and interacts with the sun mechanic, so it
is flagged rather than assumed. Must remain consistent with D-019 — warm, not body horror.
See [npcs-and-village.md §4](./npcs-and-village.md).

---

### D-025 — Outsiders become molepeople through spore sickness
**Decided. Supersedes the open question in D-024.**

Outsiders living underground accumulate spore load from the warren's fungus, progressing
Clear → Rattling → Fevered → Failing → **Coma** → **Immune**. A special cooked remedy
(clearlung broth) suppresses the illness — but suppression also suppresses adaptation. So the
player chooses per recruit:

- **Maintained:** permanent food upkeep, never adapts, **retains sun tolerance** and can work
  the surface at noon — something the player can never do.
- **Transitioned:** nursed through a coma, emerges a permanent moleperson with no upkeep, dark
  vision and dig aptitude, and sun-sensitivity forever.

*Why:* recruitment becomes a standing decision rather than a transaction, the surface becomes
permanently staffable only by people you are deliberately keeping sick, and it retro-explains
the species — molepeople are *made*, and sun-sensitivity is acquired immunity with a price.

*Tone guard:* the coma is a **nursing** sequence, telegraphed days ahead, made safe by
preparation, with a warm wake-up. Death requires genuine neglect. See
[npcs-and-village.md §4](./npcs-and-village.md).

*Knock-on:* clearlung broth ingredients should come partly from the surface, giving the
surface crop economy permanent relevance.

---

### D-026 — Gamepad is a primary input target, not a port
**Decided.** The game is designed for gamepad from the first UI mockup, with mouse and
keyboard as an equal-quality alternative rather than the assumed default.

*Why:* Core Keeper demonstrates a tile-based dig-and-build game can be excellent on a pad, the
Steam Deck audience for cosy survival-crafting is substantial, and gamepad-first constraints
(larger targets, no fine drags, no hover-only information) produce a better mouse UI anyway.
Retrofitting gamepad onto a mouse-designed build-mode is a known, expensive failure.

*Binding constraints:* no interaction may require pixel precision, hover-only information, or
a click-drag; every build placement is grid-snapped to a character-anchored cursor; linear
structures auto-route. See [ui-ux-and-controls.md](./ui-ux-and-controls.md).

---

### D-027 — Title: Deepholt
**Decided.** The game is **Deepholt**. A *holt* is an animal's den or lair, so the name reads
literally as "the deep den" — place-first, warm, Old English in register, and it carries the
descent without naming it.

**Tunnelkin** is recorded as the secondary favourite, held in reserve. It is the people-first
alternative — *kin* carrying found family, recruitment, and the deep cousins at the bottom of
the mountain — and would be the right pick if the project's centre of gravity shifts from the
place toward the settlement layer.

The git repository remains `Molepeople`; renaming it buys nothing.

---

### D-028 — One in-game day = 24 real minutes
**Decided.** 1 game hour = 1 real minute. 10 min night, 2 min dawn, 10 min day, 2 min dusk.
The sun sweeps **15° per real minute**.

*Why:* fast enough that a shadow visibly rotates during a two-minute errand, slow enough that a
route planned at the start of a trip is still valid at the end. Creates a natural work rhythm —
dig by day, surface by night — and gives players and developers trivial mental arithmetic.

*Downstream:* hunger, Marrow-Ache, crop growth and every exposure rate are expressed in game
days and inherit from this. Change this value and re-derive rather than patching leaves.

---

### D-029 — ~15 minutes of cumulative hauling before infrastructure
**Decided.** 5–6 loaded round trips before the hand winch is both affordable and wanted.

*Why:* long enough that the problem is unmistakable and the winch is earned; short enough to
stay clear of the criterion-5 tedium kill switch.

*Key insight:* this is **not** a fixed trip length. The mine face recedes from the shaft as the
player works it, so trips grow from ~90 s to ~250 s on their own. The pressure curve is
self-generating from geometry rather than imposed by a tuning constant, which makes it far more
robust to level-size changes.

*Tuning levers, in order:* winch cost → ore yield per tile → carry capacity. Never a bigger pack.

---

### D-030 — Stamina exists for combat only; the load curve carries weight
**Decided.** No movement stamina. Sprint is free. Combat actions (dodge, heavy swing) use a
stamina pool.

*Consequence:* with no drain bar to express a heavy pack, the **load/speed curve must carry the
entire feeling of weight** and is tuned harder than it otherwise would be — including a hard
rule that above **150% capacity you cannot climb a ladder**.

*Why that rule is acceptable under D-013:* it is a legible physical limit, not a UI error, and
it is not a block on progress — stairs, chutes and lifts all remain available, and dropping
something is always an option.

---

### D-031 — Smelting saves ~70% of haul weight (3 ore → 1 ingot)
**Decided.** 15 kg of ore becomes a 4 kg ingot.

*Why:* makes the forward processing camp unambiguously correct and turns "site the smelter at
the mine face" into the best emergent discovery in the design. It stays honest because the
smelter and its fuel must be hauled down first.

*Rule:* **do not tutorialise this.** Players finding it themselves is the payoff.

---

### D-032 — Sprint removed. One movement speed.
**Decided. Amends D-030.** There is no sprint. Base walk **5.0 tiles/s**, raised from 4.0 because
it is now the only gear. Stamina remains, for combat actions only.

*Why:* sprint served no purpose the design needed. Removing it makes **load the sole input to
movement speed**, so every speed change the player ever feels is information about their pack.
That is a strict gain in legibility for the game's central pressure.

*Consequences handled:*
1. **Base speed raised to 5.0** so the empty return leg — the least interesting part of a haul —
   does not become dead time. The loaded leg is unaffected, since D-030's curve already removed
   sprint above 80% load.
2. **No common creature may exceed the player's unloaded walk speed**
   ([combat-and-fauna.md §1](./systems/combat-and-fauna.md)). Without sprint, disengaging depends
   entirely on relative speed, and combat must stay optional.
3. `L3` reassigned from sprint to the support overlay toggle, retiring the awkward `LB+RB` chord.
4. Hunger's Empty state penalty changed from "cannot sprint" to −15% walk speed.

---

### D-033 — Tunnel memory: four render states per tile
**Decided.** Tiles are **Unknown** (black), **Remembered** (dim structural outline, no entities or
ore identity), **Sensed** (dark vision, 7 tiles), or **Lit** (full colour, ore legible).

*Why:* resolves a genuine conflict between dark vision (7 tiles), support radius R (up to 8) and
the widest timber hall (17 tiles) — you could not see the thing you were designing. Raising dark
vision would have flattened the mood; a third state solves hall planning, base navigation, and
theme at once. Your tunnels are visible **because you dug them**; untouched rock stays black, so
the map of the world is the record of your work.

*Persistent cost:* one bit per tile.

---

### D-034 — Camera shows ≈30×17 tiles; tile count is the design constant
**Decided.** 16×16 px base tiles, 480×270 virtual resolution, integer scaling where the display
allows. No player zoom control. Holding the support overlay is the one sanctioned zoom, out to
≈45×25 tiles so a 17-tile hall fits on screen while planning.

*Why:* the relationship between visible area, dark vision radius and support radius is load-
bearing (D-033). No display may show meaningfully more world than another.

---

### D-035 — No tile streaming system; the whole world stays resident
**Decided.** ~573,000 tiles across eight depths at 8 bytes each is **~4.6 MB**. Hold every level
resident for the session. Cull rendering and node instantiation, never data.

*Why:* removes an entire subsystem, an entire bug class, and weeks of schedule, on the strength
of arithmetic that should have been done before assuming streaming was needed.

---

### D-036 — Off-level machines use deterministic accrual, not background ticking
**Decided.** Machines store `last_evaluated_tick` and a rate; output is computed lazily on query,
on player arrival, or on a power-network event. Nothing ticks off-screen.

*Why:* a powered hoist must keep hauling while you are three levels away — that is the entire
point of the hoist. Accrual is **exact** (not approximate) as long as power is constant between
events, which it is.

*Design constraint decided here:* when variable weather arrives, **wind must be a stepped value
changing on discrete events**, not a continuous curve, or accrual stops being exact.

*Also:* nothing that can threaten the player simulates where the player cannot see it.

---

### D-037 — One TuningProfile resource holds every global constant
**Decided.** All tuning-appendix globals live in a single swappable Godot `Resource`. Saves record
`tuning_profile_id`.

*Why:* playtest variants become a one-file swap with no rebuild, and playtest feedback stays
traceable to the numbers it was played under — without which data from a since-retuned build is
worthless. A magic number hardcoded in a script is a bug even when the value is correct.

---

### D-038 — A content validator enforces the derived invariants in CI
**Decided.** Build fails on unresolved ids, items missing weight or value, creatures faster than
the player, non-monotonic support radii, unreachable recipes, and — most importantly — **the
digging invariant**: every stratum's tier-appropriate tool must dig in 0.5–0.7 s, and the breach
ladder must resolve to exactly one tool tier per depth.

*Why:* the breach ladder is trustworthy because it is *derived*. A validator is what keeps it
derived as values drift.

---

### D-039 — Water spreads by chamber connectivity; regions become generation-time only
**Decided. Amends D-012 and refines D-017.**

Runtime water occupies a **chamber** — a connected component of open space. Breach a wall into a
flooded chamber and the water comes through; seal a bulkhead and it stops. Generation still
partitions levels into regions and still decides where water sits, but it then **realises that
boundary as physical geometry** — rock, ancestral bulkheads, sealed doors — and discards the tag.
There is no `FLOODED` access class at runtime.

*Why:*
1. **Legibility.** A region boundary was invisible metadata; a wall is not. The player can always
   see why water is where it is.
2. **Agency.** Draining becomes a puzzle — find the openings, seal them, *then* pump. Bulkheads
   and doors become critical infrastructure instead of decoration.
3. **It connects collapse to flood.** Over-digging into a flooded chamber, or a cave-in that fails
   a wall beside one, brings the water to you — the ancestors' disaster, re-enactable by the
   player. These two systems previously did not talk to each other at all.
4. It reuses the flood-fill already being written for room comfort scoring.

*What this does **not** do:* it removes one access class out of five, not the region system.
`UNSTABLE`, `SEALED` and `CRUSHED` are not connectivity-based, and regions still carry carve
params, decoration, ore and fauna tables and the generation guarantees.

*Costs accepted:*
- A **new geometric generation guarantee** — every water body must be provably enclosed, verified
  per seed by the content validator. This is the principal new cost.
- Connectivity maintenance is asymmetric: mining merges components (cheap, union-find), sealing
  splits them (expensive, bounded flood-fill budgeted across frames).

*Naming discipline:* **Room** = built, enclosed, comfort-scored. **Chamber** = any connected open
volume, used for water. Same algorithm, separate concepts, separate names — or a natural cavern
ends up with a comfort score.

*Hard line against scope creep:* `drain_stage` is **per water body, never per tile**. Connectivity
raises the player's expectation that water behaves physically — finding its level, pooling,
flowing downhill — and that expectation is the most likely route back into the fluid-simulation
hole D-017 exists to avoid. Refuse it.

*Required:* walls adjacent to water must be telegraphed unmistakably — damp discoloration,
seepage, dripping audio, a distinct struck-rock sound — and flooding must always be recoverable by
pumping. A flood is a setback, never a lost save.

*Deferred, not precluded:* water travelling down player-dug shafts to lower depths. Excellent —
it would make bulkheads at lift landings essential and tie water directly to pillar P1 — but out
of pre-alpha.

*Pre-alpha impact:* none. All water is out of scope; the gated region on −3 is `CRUSHED`.

---

### D-040 — D-010 ratified
**Housekeeping.** D-010 (dark vision: 7 tiles, desaturated monochrome, light restores colour,
detail and ore identity) was carried as *Proposed* while four later decisions and three technical
documents came to depend on it. It is now **Decided**, unchanged. Recorded here so the promotion
is visible in the log rather than being a silent edit.

---

### D-041 — Surface scope: summit and upper slopes now, mountainside later
**Decided.** The pre-alpha and first playable surface is a bounded ring around the top of the
mountain, radius ~90 tiles (~25,400 tiles), with all cave mouths at similar elevation. The full
mountainside down to the base is a **planned post-pre-alpha expansion**.

*Why:* defers a large content bill without foreclosing the better version. The mountainside — cave
mouths at genuinely different elevations, long shaded descents — is where the sun mechanic gets
its fullest expression, and it should happen, just not first.

*Binding constraints so the expansion is not a rewrite:*
- **Surface bounds are a generation parameter, never a baked constant.**
- **Nothing may assume all cave mouths share an elevation.**
- The tile-count arithmetic in [world-runtime §1](./tech/world-runtime-and-persistence.md) has
  headroom: even a fourfold surface keeps the whole world under 8 MB, so
  [D-035](#d-035--no-tile-streaming-system-the-whole-world-stays-resident) still holds.

*Corrects:* an earlier ~101,700-tile surface figure that was asserted in the runtime document
without a design decision behind it.

---

### D-042 — Every milestone has a testable exit criterion
**Decided.** M0–M7 each exit on a stated, observable condition rather than on judgement
([pre-alpha-scope §7](./pre-alpha-scope.md)). UI work is assigned to specific milestones, because
the support overlay and the layer-stack map are mechanics, not polish, and shipping them late
would invalidate the milestones that depend on them.

*Note:* M3's exit is phrased as a **tester behaviour** — returning to base from an unexplored area
using only the map, with no verbal hints — because multi-level navigation is the one UX risk in
this design that cannot be judged by inspection.

---

### D-043 — Primary display target is 1920×1080 desktop; every other display is compatibility
**Superseded by [D-044](#d-044--steam-deck-is-the-primary-display-target-virtual-resolution-is-512320).**
Recorded as decided, then reversed the following day in favour of a Steam Deck-native target.
The reasoning below about *having* one canonical display still holds; only the display changed.

**Decided.** The build is optimised for **desktop play at 1920 × 1080**, the standard 16:9
desktop resolution. This sharpens [D-034](#d-034--camera-shows-3017-tiles-tile-count-is-the-design-constant)
rather than reversing it: 480 × 270 × **4 = exactly 1920 × 1080**, so the primary target is the
clean integer-scale case and costs nothing. Every other display is a compatibility case, tuned so
the ≈30 × 17 tile constant still holds — and none may show more world than 1080p does.

*Why:* the relationship between visible area, dark vision radius and support radius is load-
bearing (D-033, D-034) and has to be judged on one canonical display. "Integer scaling where the
display allows" left it ambiguous which display the design was *right* on. Now there is one
resolution the game is tuned for, and others are accommodated.

*Consequence:* Steam Deck's 1280 × 800 is no longer a co-equal target. It stays supported — it is
16:10 and does not scale integrally — through a pixel-snapped non-integer scale plus a
pixel-perfect toggle that letterboxes at 2×. That is compatibility work, tested after the primary
target, and it may not constrain the primary target.

*Does not change:* [D-026](#d-026--gamepad-is-a-primary-input-target-not-a-port). Gamepad-first is
an **input** decision and stands. A desktop-optimised game with a gamepad-first UI is precisely
Core Keeper's shape, and the pad constraints — no pixel precision, no hover-only information —
remain usability wins for mouse users. If desktop-first is meant to demote the pad, that is a
separate decision and needs its own entry.

*Forecloses:* ultrawide (21:9) as a design target — it would show more world laterally and break
D-034; resolution-dependent UI density; any layout that only reads correctly below 1080p.

---

### D-044 — Steam Deck is the primary display target; virtual resolution is 512×320
**Decided. Supersedes [D-043](#d-043--primary-display-target-is-19201080-desktop-every-other-display-is-compatibility)
and amends [D-034](#d-034--camera-shows-3017-tiles-tile-count-is-the-design-constant).**

The build targets **Steam Deck, 1280 × 800, 16:10**. Virtual resolution is **512 × 320**, which
is 16:10 exactly and scales to the Deck at **2.5×, filling the screen with no bars**. Base tile
art stays **16 × 16 px**. The design constant becomes **≈32 × 20 tiles**.

*Why the constant moves from ≈30 × 17:* 30 columns is the load-bearing number — it is what makes
a 17-tile timber hall plannable against a 7-tile dark-vision radius (D-010, D-014, art-and-camera
§1). 17 rows was never designed; it is simply what 16:9 yields at 30 columns. Moving to 16:10
changes only the number that was arithmetic. Columns go 30 → 32, comfortably safe; rows go
17 → 20, which costs some of the lit-circle framing (the dark-vision disc covers ~28% of the
frame rather than ~35%) and buys hall-planning headroom.

*Why 16 × 16 art is retained, and why it is not merely convenient:* open-source pixel tilesets
cluster at 16 × 16 and 32 × 32. A 20 × 20 grid — which would have bought integer 2× scaling on the
Deck — puts every downloaded asset through a ×1.25 resample that doubles every fourth pixel row,
destroying 1px outlines, dithering and autotile sets. Separately, 16 px is the *right* size for
this screen: 32 px art needs a 960 px-wide viewport for ~30 columns, which upscales to the Deck at
a weak 1.33×, while 16 px lands in the healthy 2.5× range.

*The cost, accepted deliberately:* 2.5× is not an integer scale. Plain nearest-neighbour
alternates 2 px and 3 px blocks that crawl when the camera pans, so a **pixel-art upscale shader**
(edge-filtered nearest / sharp-bilinear) is mandatory and is built in M0, not discovered later.

*The second cost, accepted deliberately:* 16:9 desktops **pillarbox**. At 1920 × 1080 the game
renders 1728 × 1080 with ~96 px bars each side. Showing more world on a wider screen is forbidden
by D-034 and is not an option. Desktop is a supported display, not the tuned one.

*Forecloses:* integer-scale purism as a project value; a 20 px or 32 px base grid; ultrawide as
anything but a pillarbox; UI density tuned for a desktop monitor — **UI legibility is judged at
Deck size**, which reverses the note D-043 left in ui-ux-and-controls §1.

*Does not change:* [D-026](#d-026--gamepad-is-a-primary-input-target-not-a-port). Gamepad-first
was always the input decision, and the display target now agrees with it rather than pulling
against it.

---

### D-045 — "No player singleton" carves out the presentation layer
**Clarifies D-004.** The rule is that **simulation** code must take an actor — or a set of actors
— as a parameter. It is *not* a ban on knowing which actor is locally controlled: camera, HUD and
input routing legitimately need a `LocalActor` reference, and that is correct.

*Why the clarification was needed:* as originally written, the constraint read as an absolute
prohibition, from which a developer could reasonably conclude they may not have a camera target.

*Rationale for the underlying rule, now recorded in
[world-runtime §6](./tech/world-runtime-and-persistence.md):* a singleton is an assumption baked
into every call site, and it collapses six distinct questions — union of all actors, any actor,
per actor, nearest actor, one specific actor, N actors — into a single accessor that nothing can
help you disentangle later. The retrofit cost is not one refactor; it is hundreds of small
judgement calls spread through gameplay code.

*Specific dependency:* D-007's requirement that worker crafting be immune to Marrow-Ache is only
cleanly expressible if affliction is a component on an actor. Under a singleton it degrades into
a special case inside crafting — which is how that guarantee silently stops holding.

*Review smell tests:* a global named `player`; a function needing actor state that takes no actor
argument; `if actor == player` in gameplay code; any singleton access outside presentation.

---

### D-046 — Levels reach the screen through a data texture and a shader, not `TileMapLayer`
**Decided.** A level is drawn as textured quads whose shader reads per-tile data from a texture —
one texel per tile — and draws tile art out of an atlas. Godot's `TileMapLayer` is not used for
world terrain.

*Why — two reasons, either weaker alone:*
1. **The route is the lesson.** The project runs learn-deeply-first
   ([WORKING-AGREEMENT §7](../work/WORKING-AGREEMENT.md)), and owning the path from tile data to
   pixels is worth more than having it handed over.
2. **It is where rendering is headed anyway.** Tunnel memory's four per-tile render states
   ([D-033](#d-033--tunnel-memory-four-render-states-per-tile)), a per-tile light buffer that
   chooses each tile's look, and ore identity hidden in the renderer rather than the UI
   ([art-and-camera §2, §4.1](./tech/art-and-camera.md)) are all a per-tile value reaching a
   shader. This route carries that natively. `TileMapLayer` has no per-cell shader input and would
   need a side-channel state texture to get there — the same mechanism this route is built on.

*Considered:* `TileMapLayer`, used either as the tile store or as a mirror of separate tile data —
fastest to first pixels, with editor painting, quadrant culling and terrain autotiling included.
It was the initial preference and a close call. Also described and not pursued: a node per tile,
`_draw()` / `RenderingServer` canvas items, `MultiMeshInstance2D`, and generated chunk meshes.

*Costs accepted deliberately:*
- **No editor tile painting.** Hand-made levels need their own authoring format, which procgen
  replaces in M3.
- **Autotiling is hand-built** when the art calls for it.
- **Culling is as coarse as the quads.** Nothing batches or culls per region automatically.
- **Rendering faults live in texture contents and shader maths**, not in inspectable nodes. The
  debug overlay's job of separating *what the world believes* from *what the screen shows* is how
  they get diagnosed.

*Forecloses:* `TileSet`-generated collision, navigation and occlusion for terrain — anything that
needs those derives them from tile data. `TileMapLayer` scene tiles as a way to place structures.

*Open:* how tile data is encoded into textures, how an id finds its atlas region, how much of a
level one quad covers, and how a changed tile reaches the GPU.

---

### D-047 — A level has at least two tile layers: the ground, and what sits on it
**Decided.** Every cell on a level has a **ground** — the kind of material underfoot — and a
**top** — what occupies the space over that ground: minable rock, open space, or something built.
Building over ground does not replace it. A built floor looks different and has its own
properties, and the ground it was laid on is still known.

*Why:* what the mountain was made of is information the world keeps. Collapsing "what is here"
into a single value per cell would make every build destroy it.

*Two is a minimum, not a ceiling.* Known pressure toward more: burial-not-destruction leaves a
built object and rubble in the same cell ([digging-and-structure §5](./systems/digging-and-structure.md));
base-building stands walls, doors and props on built floors
([base-building](./systems/base-building.md)); ore sits inside rock. How those are represented
is not decided here.

*Open:* where tile data lives and in what shape; which kinds exist; how *open*, *never set* and
*out of bounds* are told apart.

---

### D-048 — Tile data is flat byte arrays in simulation, and the only truth
**Decided.** Each level's tiles live in a `RefCounted` under `src/world/` — not a Node. Each
layer ([D-047](#d-047--a-level-has-at-least-two-tile-layers-the-ground-and-what-sits-on-it)) is
one flat `PackedByteArray` covering the square around the level's radial bounds, indexed
`(y + r) * width + (x + r)`. Each byte is a kind id into a table of kind definitions. Everything
else that shows tiles — including the render textures of
[D-046](#d-046--levels-reach-the-screen-through-a-data-texture-and-a-shader-not-tilemaplayer) —
is derived from this data and never read back as truth. Access goes only through small read and
write functions.

*Why:* simulation must not depend on presentation ([coding-standards](./coding-standards.md)),
so tile truth cannot live in anything that draws. A plain object lets tests build and mutate a
level with no scene and no art. Keeping access behind functions means widening ids, adding fields
or chunking later changes only those functions. A byte per tile per layer is already close to
what a data texture holds.

*Deferred, not foreclosed:* 32×32 chunking and the fuller per-tile record in
[world-runtime §3](./tech/world-runtime-and-persistence.md). Nothing in slice 001 reads them, and
pre-alpha scope rules out stubs for them.

*Open:* which kinds exist, and how *open*, *never set* and *out of bounds* are told apart.

---

### D-049 — Hand-made levels are authored as text grids with a single origin marker
**Decided.** A hand-made level is a text grid, one character per tile, read through a table that
maps each character to kinds for the layers of
[D-047](#d-047--a-level-has-at-least-two-tile-layers-the-ground-and-what-sits-on-it). One
dedicated character marks an **open tile on rock ground** that is also the level's **`(0, 0)`**.
It appears **exactly once** per grid; every other tile's coordinates are measured from it.

*Why:* text needs no tooling, reads as the layout it describes, diffs cleanly, and lets tests build
a level from an inline string. Putting the origin in the grid itself means the file says where it
sits in world coordinates, rather than that living in a separate offset.

*Binds:* all depths share one origin at the mountain's axis, and each level's bounds are a disc
around it ([world-runtime §2](./tech/world-runtime-and-persistence.md)). The marker is therefore
the axis — where it sits in each file is what aligns one level over another.

*Considered:* a PNG painted in an image editor, one pixel per tile. Easier to paint large or
irregular shapes; harder to diff or write inline in a test.

*Replaced by:* procgen in M3, for generated levels.

*Open:* the actual characters; what the loader does with zero or several markers.

---

### D-050 — A level grid without exactly one origin marker fails to load
**Decided. Closes one open question in
[D-049](#d-049--hand-made-levels-are-authored-as-text-grids-with-a-single-origin-marker).** A
grid with no origin marker, or with more than one, is rejected: the level does not load. Both
cases are covered by unit tests.

*Why:* every coordinate in the level is measured from the marker, so without exactly one there is
no correct way to place the level — and guessing would put it somewhere plausible and wrong.

---

### D-051 — Slice 001's tile kinds and grid characters
**Decided. Closes the open characters question in
[D-049](#d-049--hand-made-levels-are-authored-as-text-grids-with-a-single-origin-marker).**
One ground kind and three top kinds:

| Char | Ground | Top |
|---|---|---|
| `.` | rock | open |
| `#` | rock | minable rock |
| `c` | rock | minable copper node |
| `0` | rock | open — and the level's `(0, 0)` origin marker ([D-050](#d-050--a-level-grid-without-exactly-one-origin-marker-fails-to-load)) |

*Why:* start very small. Enough to tell open from solid at a glance, and one ore so there is
something other than rock to dig.

*Retrofit cost named at the time:* copper here is a **top kind of its own**, not rock carrying an
ore value. The fuller tile record keeps ore separate from terrain
([world-runtime §3](./tech/world-runtime-and-persistence.md)), and ore identity must be hidden by
the renderer in the dark ([art-and-camera §4.1](./tech/art-and-camera.md)) — so this is expected
to be reshaped when either arrives.

*Open:* what a grid character outside this table means, and how *never set* and *out of bounds*
read.

---

### D-052 — One text grid per tile layer; ore is a value on rock, not a kind
**Decided. Amends [D-049](#d-049--hand-made-levels-are-authored-as-text-grids-with-a-single-origin-marker)
and [D-051](#d-051--slice-001s-tile-kinds-and-grid-characters).**

- A hand-made level is authored as **one text grid per tile layer**, not one grid whose characters
  each encode a combination of layers.
- **The text grid is a short-term authoring format.** It does not shape the tile data design or
  any architecture decision; a loader translates it into tile data.
- **`c` is minable rock carrying a copper ore value** — not a top kind of its own. This replaces
  D-051's copper row, and the retrofit cost D-051 named no longer applies.

*Why one grid per layer:* in a single grid, characters stand for combinations, and combinations
multiply with every new ground kind, top kind or ore. Separate grids keep each layer's vocabulary
small and each layer visible on its own.

*Costs accepted deliberately:* grids must line up cell for cell, and a short or long row in one
grid shifts only that layer; the loader has more ways to fail and more to validate.

*Open:* whether ore is its own grid or a character in the top grid; the characters each grid
uses; which grid carries the origin marker (exactly one is still required,
[D-050](#d-050--a-level-grid-without-exactly-one-origin-marker-fails-to-load)); what grids of
mismatched dimensions do; and where an ore value lives in tile data, since
[D-048](#d-048--tile-data-is-flat-byte-arrays-in-simulation-and-the-only-truth) holds one kind
byte per layer and nothing else.

---

### D-053 — Ore has its own grid; every grid carries the origin marker
**Decided. Amends [D-050](#d-050--a-level-grid-without-exactly-one-origin-marker-fails-to-load)
and closes open questions in [D-052](#d-052--one-text-grid-per-tile-layer-ore-is-a-value-on-rock-not-a-kind).**

- **Ore is authored in its own grid**, alongside the ground and top grids.
- **Every grid carries exactly one origin marker.** The markers are how the grids line up with
  each other: each grid's coordinates are measured from its own marker. A grid with none, or with
  more than one, fails to load — so D-050's rule now applies per grid.
- **The origin marker only ever means empty space.** The origin tile is always open, with no ore.

*Why:* aligning grids by a shared marker, rather than by position in the file, means a grid's
alignment is stated inside the grid itself.

*Deferred:* what grids of different dimensions or extents do.

*Open:* what the marker means in the ground grid, where there is no empty ground; and where an
ore value lives in tile data.

---

### D-054 — Ore is a third byte array; the ground grid's origin marker is rock
**Decided. Amends [D-048](#d-048--tile-data-is-flat-byte-arrays-in-simulation-and-the-only-truth)
and closes the open questions in [D-053](#d-053--ore-has-its-own-grid-every-grid-carries-the-origin-marker).**

- **Ore lives in a third `PackedByteArray` per level**, the same shape and indexing as the ground
  and top arrays in D-048. Each byte is an ore id. Like the others, it is the truth; render
  textures are derived from it.
- **In the ground grid, the origin marker means rock** — for now. In the top and ore grids it
  means empty.

*Why a separate array rather than packing ore into the top byte:* it follows the pattern already
chosen for layers, matches the separate ore grid, and keeps one meaning per byte.

---

### D-055 — Malformed grids are a hard failure
**Decided.** An unrecognised character or a ragged line in any level grid throws an error and the
level does not load. There is no partial load, no substitution and no best guess.

---

### D-056 — Grid characters, and ore only inside minable rock
**Decided. Closes the characters question in
[D-053](#d-053--ore-has-its-own-grid-every-grid-carries-the-origin-marker).**

| Grid | Char | Means |
|---|---|---|
| Ground | `r` | rock |
| Top | `.` | open |
| Top | `#` | minable rock |
| Ore | `.` | no ore |
| Ore | `c` | copper |
| All | `0` | origin — rock in the ground grid, empty in top and ore ([D-054](#d-054--ore-is-a-third-byte-array-the-ground-grids-origin-marker-is-rock)) |

`.` means *nothing on this layer*; `#` is solid mass; letters are materials.

**Ore must sit in a `#` tile.** An ore character over anything else in the top grid is a hard
failure, as [D-055](#d-055--malformed-grids-are-a-hard-failure): the level does not load.

---

### D-057 — Reads outside a level's tile data return a sentinel
**Decided.** Reading a tile at a coordinate the level's data does not cover returns a reserved
sentinel value rather than erroring or pretending to be an ordinary kind. Callers check for it
where it matters.

*Considered:* an error on the read; a default kind such as solid rock; a separate validity check
callers must make first; a found-or-not result.

*Open:* the sentinel's value; whether *outside the array* and *inside the array but outside the
level's radial bounds* return the same sentinel or different ones.

---

### D-058 — Sentinel values: 999 outside the array, 998 outside radial bounds
**Decided. Closes the open questions in
[D-057](#d-057--reads-outside-a-levels-tile-data-return-a-sentinel).** A tile read at a
coordinate outside the level's arrays returns **999**. A read inside the arrays but outside the
level's radial bounds returns **998**. The two cases are distinguishable.

*Note:* both exceed a byte, so they exist only as values a read returns — they are never stored in
the tile arrays of [D-048](#d-048--tile-data-is-flat-byte-arrays-in-simulation-and-the-only-truth).

---

### D-059 — Sentinel values revised to 255 and 254
**Decided. Supersedes [D-058](#d-058--sentinel-values-999-outside-the-array-998-outside-radial-bounds).**
A tile read outside the level's arrays returns **255** (the maximum of a byte). A read inside the
arrays but outside the level's radial bounds returns **254**.

*Consequence:* both now fit in a byte, so they share the id space of the tile arrays in
[D-048](#d-048--tile-data-is-flat-byte-arrays-in-simulation-and-the-only-truth) and
[D-054](#d-054--ore-is-a-third-byte-array-the-ground-grids-origin-marker-is-rock). **254 and 255
are reserved on every layer** — no ground, top or ore kind may use them.

---

### D-060 — The authored unit is a placeable prefab, and the marker is its anchor
**Decided. Amends [D-049](#d-049--hand-made-levels-are-authored-as-text-grids-with-a-single-origin-marker)
and [D-053](#d-053--ore-has-its-own-grid-every-grid-carries-the-origin-marker).**

- **What a person authors is a prefab, not a level.** A prefab is a block of tiles stamped into a
  level at a world coordinate. A level is what you get after stamping zero or more of them into
  the default fill.
- **The `0` marker is the prefab's own anchor**, not world `(0, 0)`. Stamping supplies the world
  coordinate the marker lands on. D-053's rule that the markers are how the layer grids line up
  with each other is unchanged — they still align to each other by marker.

*Why:* authoring does not end at procgen. Generation's fourth step stamps **authored prefab
chunks** at region centres and junctions ([world-and-generation §4](./world-and-generation.md)),
the target is roughly **30% authored by area** on ruin strata, and three authored ruin prefabs
are in pre-alpha scope at M3 with their content at M7
([pre-alpha-scope](./pre-alpha-scope.md)). A format whose marker means world `(0, 0)` cannot
express a thing that gets placed somewhere, so that meaning had to go before content exists in it.

*Unchanged:* all depths still share one origin at the mountain's axis
([world-runtime §2](./tech/world-runtime-and-persistence.md)). This is about what a prefab's
marker means, not about the coordinate space.

*Deferred:* rotation and variants, both of which `POIPrefab` will need
([content-schema §3](./tech/content-schema.md)) and neither of which is built. Also deferred,
deliberately: whether one text grid per layer survives more layers
([D-047](#d-047--a-level-has-at-least-two-tile-layers-the-ground-and-what-sits-on-it) names the
pressure). Three grids stand.

---

### D-061 — Authored tile content is a `.tres` resource with a stable id, indexed by a registry
**Decided. Amends [D-049](#d-049--hand-made-levels-are-authored-as-text-grids-with-a-single-origin-marker).**
A prefab is a Godot `Resource` at `res://content/tile_prefab/<id>.tres`, carrying a stable
snake_case `id` and its three layer grids as multi-line text. A registry autoload indexes them by
id at startup; an unknown id is an error at the lookup.

*Why:* the project already settled that content is authored as custom `Resource` types with a
registry and stable never-renamed ids, explicitly rejecting bespoke loaders
([content-schema §1, §6](./tech/content-schema.md)). A loose text file outside that system would
have been a second content pipeline for no gain. The grids stay plain text **inside** the
resource, so D-049's reasons for text — diffs cleanly, reads as the layout it describes, states
itself inline in a test — all survive.

*Consequence:* ids are referenced by saves and are never renamed, only deprecated
([content-schema §1](./tech/content-schema.md)).

---

### D-062 — A prefab is a partial fill; unmentioned tiles keep the level's default
**Decided. Supersedes the ragged-line half of
[D-055](#d-055--malformed-grids-are-a-hard-failure).**

- **A prefab covers only what it was authored to cover.** Any tile it does not mention keeps the
  level's default — rock ground, minable rock top, no ore. A short or ragged row is therefore
  legal, not a failure.
- **The unrecognised-character half of D-055 stands.** An unrecognised character, a grid without
  exactly one anchor marker, or ore over a stated non-`#` top tile is still a hard,
  all-or-nothing failure: nothing is written.

*Why:* a prefab is by definition a fragment of a level, so "the grid didn't say" is its normal
state rather than a malformed one. Requiring a complete grid would mean hand-typing a 181 × 181
grid three times to author the surface, which is not authoring.

*Consequence:* ore over a tile the **top grid never mentions** is allowed, because that tile
defaults to minable rock, which is what
[D-056](#d-056--grid-characters-and-ore-only-inside-minable-rock) requires ore to sit in. Ore
over a top character that *is* stated and is not `#` still fails.

*Open:* the non-authored remainder of a level is currently solid rock. Everything beyond the
authored pocket wants generation, not a default fill — that is M3's problem, not this one.

---

### D-063 — A render quad covers one whole level, not the camera's view
**Decided.** One `MeshInstance2D` quad per resident level, sized to that level's own array
(2896 px square at Surface, 6640 px at the Crush), holding a data texture the same shape as the
array. The camera pans over it with an ordinary `Camera2D`/`Node2D` transform. Only the current
depth's quad needs to exist under `GameViewport`; the other seven stay pure data until the player
changes depth.

*Why:* the alternative — a fixed, viewport-sized quad with a scroll-offset uniform standing in
for camera position — duplicates a coordinate system Godot already provides for free, and turns
the C-6 trap (two coordinate systems meeting) into three by adding a shader-only offset alongside
the array's centred indexing and the texture's top-left origin. A whole-level quad also avoids a
sliding-window data texture: the texture is built once per level, matches the array 1:1, and a dig
updates a single texel — no resampling as the camera scrolls. GPU cost is unaffected either way;
2D rasterization already clips a quad to what's actually on screen, which is what D-046's
"culling is as coarse as the quads" already accepted.

*Consequence:* per-tile changes reach the render texture as a single-texel update, not a windowed
re-upload — the mechanism section E's dig verb can rely on. The camera becomes a genuine
`Camera2D`, not a value pushed to a shader uniform by hand.

---

### D-064 — A tile id finds its art through a per-layer table, not by being an atlas index
**Decided** (by Claude, at Derik's request — first half of the *how an id becomes pixels*
fork; combining ground and top is still open). Each layer has a 256-entry table, indexed by the
byte the layer holds, giving the atlas cell that draws it. The table reaches the shader as a
`uniform int[256]` built in `src/render/`. Any byte without an entry draws a dedicated, loud
*missing art* cell. The atlas is read with `texelFetch` at integer texel coordinates.

*Why:* an id is a kind, not a picture. Ids are not guaranteed contiguous, the same number means
different kinds on different layers, and 254 needs a deliberate look of its own, which the
atlas-index-equals-id scheme would need a 255-cell atlas to provide
([D-059](#d-059--sentinel-values-revised-to-255-and-254)). Autotiling will also map one id to
many cells ([D-046](#d-046--levels-reach-the-screen-through-a-data-texture-and-a-shader-not-tilemaplayer)),
and ore must draw as a generic lump below a light threshold
([art-and-camera §4.1](./tech/art-and-camera.md)). Both of those change what the table answers,
not the shader's arithmetic. `texelFetch` cannot land on a neighbouring cell, so the half-texel
inset that normalised atlas UVs need does not exist here.

*Considered:* the id used directly as the cell index; a 256 × 1 lookup *texture* instead of a
uniform array. The texture scales to several tables (§4.1 already speaks of three) and is the
likely successor once render states arrive; a uniform array is plainer to read today.

*Found while building it:* a `QuadMesh` drawn by a `MeshInstance2D` has its UV.y running
bottom-to-top, because it is a 3D mesh. C-2's checkerboard is symmetric under that flip and could
not show it; the first asymmetric atlas cell did. The tile shader flips it explicitly.

---

### D-065 — Each layer is its own R8 data texture, built through the reads; changes reach it from the truth
**Decided** (by Claude, at Derik's request).

- **Format.** One `Image.FORMAT_R8` texture per layer, the same square as the layer's array, so
  texel `(column, row)` is array index `row * width + column`. No mipmaps, no `source_color`.
  The shader reads it with `texelFetch` at the integer tile and decodes `int(r * 255.0 + 0.5)`.
- **Built through the read functions**, not by copying the array. The array stores the default
  kind outside the radial bounds; only a read returns 254 there
  ([D-059](#d-059--sentinel-values-revised-to-255-and-254)). The texture shows what the world
  answers, so the screen and `F3` can never disagree about where the level ends.
- **When a tile changes** (not built yet; section E's dig verb consumes this): the renderer for
  that level hears about it **from the level's tile data**, as a notification naming the tile
  and nothing about who changed it, and rewrites that texel. Changes within one frame are
  gathered into one upload. A renderer that is created later, such as on a depth change
  ([D-063](#d-063--a-render-quad-covers-one-whole-level-not-the-cameras-view)), builds from the
  truth and needs no history.

*Why the format:* it is the shape the arrays already have
([D-048](#d-048--tile-data-is-flat-byte-arrays-in-simulation-and-the-only-truth)). A changed
byte on one layer touches one texture, and none of the others. Packing three layers into one
RGB8 texel saves two texel reads per pixel, which costs nothing anyway. In exchange it means
interleaving all three arrays on every build and reading the two untouched layers on every
change. Integer textures (`usampler2D`) would skip the float decode, but `Image` has no 8-bit
integer format. R8 plus rounding is the portable route, and the round trip is tested for all
256 values.

*Why the update path:* the cheap version is for whoever changes a tile to poke the screen as
well. That works for one actor on the one level being drawn. It fails, silently, the first time
a tile changes some other way: another actor (no system may assume there is exactly one, pillar
[P5](./game-overview.md), rule [D-045](#d-045--no-player-singleton-carves-out-the-presentation-layer)), a level that is resident
but not drawn, or any later system that rewrites tiles. The screen then shows a world that no
longer exists, which is exactly the disagreement `F3` exists to catch. A notification that
starts at the truth covers every writer without any of them knowing a renderer exists, and keeps
simulation independent of presentation.

*Binds:* section E's *how anything else learns a tile changed*: it starts at the tile data,
not at the dig verb. *Who* may change a tile is still open.

*Costs accepted:* building through reads is one call per tile: 92 ms at Surface, 580 ms at the
Crush, on every depth change. A bulk read on the tile data is the fix if that hitch is felt. An
upload re-sends the whole layer texture (32 KB at Surface, 172 KB at the Crush). That is cheap
at one upload per frame at most, and partial uploads wait for a profiler to ask.

*Considered:* uploading the raw array and masking the disc in the shader (a second copy of the
radial-bounds rule); RGB8/RGBA8 packing; editing the texture on the GPU (`DrawableTexture`),
which makes the GPU copy something that could drift from the truth.

---

### D-066 — Layers are painted in order, and each layer's art decides what it covers
**Decided** (by Claude, at Derik's request — second half of the *how an id becomes pixels*
fork; [D-064](#d-064--a-tile-id-finds-its-art-through-a-per-layer-table-not-by-being-an-atlas-index)
is the first). Each layer draws its cell for the tile, and the cells are painted ground first,
then top, then ore. Each one is laid over what is already there by its own alpha. The shader
holds no rule about which kinds hide which. "Open" is a fully transparent top cell, so the ground
shows. Minable rock is opaque and hides the ground. Copper is an overlay that is transparent
except for its flecks. Outside the radial bounds only the ground draws (its hatched cell), and
the layers above draw nothing.

*Why:* this is the step that adds the third and fourth layers
([D-047](#d-047--a-level-has-at-least-two-tile-layers-the-ground-and-what-sits-on-it)
calls two a minimum, not a ceiling — rubble beside a built object, walls standing on built
floors). With painting in order, a new layer is one more line of the same thing, and the question
"does X hide Y" moves out of shader branches and into art, where it can be redrawn. Whether any
top kind is *partly* transparent is then a drawing decision, not a code change.

*Consequence:* ore draws over whatever the top drew, so the tile data has to keep ore out of
open floor. [D-056](#d-056--grid-characters-and-ore-only-inside-minable-rock) already enforces
that at load time. Section E's dig has to keep it true, by clearing ore when it opens a tile or
by deciding otherwise on purpose.

*Considered:* rules in the shader per pair of kinds (`if top is open, draw the ground`). That
reads clearly with two layers and becomes a table of special cases at four.

---

### D-067 — Tile (x, y) covers level pixels 16x to 16x + 16; world (0, 0)'s corner is the level's origin
**Decided** (by Claude, at Derik's request). In a level's own 2D space, tile `(x, y)` covers
pixels `16x` to `16x + 16` across and `16y` to `16y + 16` down. +y is down the screen, the same
direction as the arrays' rows and the prefab grids' lines. World `(0, 0)` therefore has its
**top-left corner** on the level node's origin. Its centre is at `(8, 8)`. A pixel goes back to
a tile by **floor** division, never by truncating: `int(-5 / 16)` is 0, but the tile is −1.

*Why:* it is the convention Godot's own grids use, so camera, actor and mouse code written later
will look like the examples in Godot's documentation. Every tile, the origin included, is then
the same kind of thing: a cell with a corner at a multiple of 16. The alternative is centring
tile `(0, 0)` on the origin, which is what an untouched `QuadMesh` does with an odd-width level.
That makes the origin a special case, and every conversion carries a half-tile offset.

*Consequence:* the level quad is shifted half a tile from where a `QuadMesh` puts it by default
(`center_offset`). Section D's actor turns its position into a `WorldPos` with the floor rule,
and the place it goes wrong is negative coordinates, which is half of every level. `F3`'s tile
window is the check: its `0` is the tile drawn at the camera's centre when the camera sits on
`(8, 8)`.

---

### D-068 — An actor is a plain node with a feet box, a stored depth, and an intent
**Decided** (by Derik, in code during slice 001 section D; recorded by Claude afterwards).

- **A `Node2D`, not a physics body.** Blocking is a function of tile data
  ([D-046](#d-046--levels-reach-the-screen-through-a-data-texture-and-a-shader-not-tilemaplayer)),
  so the actor has no `CharacterBody2D`, no collision shape and no `move_and_collide`.
- **It collides through a feet box.** An exported `Rect2` measured from the actor's origin,
  narrower than a tile so it fits a one-tile tunnel. `TileCollision.move_box` moves it against
  the level's tile data one axis at a time, X then Y, and snaps a blocked axis flush to the
  wall. Only `OPEN` tiles are passable: everything else blocks, including the sentinels outside
  the level ([D-059](#d-059--sentinel-values-revised-to-255-and-254)).
- **Depth is stored; the tile is computed.** Pixels can't say which level an actor is on, so
  `depth` is its own value, and setting it looks up `current_level`. `current_WorldPos` is never
  set directly. It is worked out from position and depth, using the tile under the **feet box's
  center** and the floor rule of
  [D-067](#d-067--tile-x-y-covers-level-pixels-16x-to-16x--16-world-0-0s-corner-is-the-levels-origin).
  Depth starts at −1, and entering the tree without `setup()` fails an assert.
- **It moves by intent.** `move(intent)` stores a direction. `_physics_process` applies
  `intent × speed × delta`. The actor never asks where an intent came from.
- **It announces tile changes** as `actor_worldpos_changed(actor, old_pos, new_pos)`, emitted
  after its state is updated.

*Why:* one copy of the world. A physics body would need a second, physics copy of the tiles,
rebuilt on every dig, which is the drift problem
[D-065](#d-065--each-layer-is-its-own-r8-data-texture-built-through-the-reads-changes-reach-it-from-the-truth)
avoided for rendering. Measuring the tile from the feet means collision, `F3` and digging agree
on where the actor stands. Storing depth instead of a cached `WorldPos` removes the only way to
compute a position from a missing one. Intent keeps the actor indifferent to whether a keyboard,
a network peer or a worker's AI is driving it (pillar [P5](./game-overview.md)).

*Costs accepted:* a destination check only, so one tick's movement must stay under 16 px (about
1.4 px at walking speed). Fixed X-then-Y order gives a slight sideways bias at outer corners.
No slopes, rotated shapes or actor-against-actor blocking. `current_level` is found once, when
depth is set, so levels must be in the tree before actors.

*Considered:* `CharacterBody2D` with `move_and_slide` against generated tile colliders; testing
both axes from the starting box (lets a diagonal clip a corner tile); the tile under the
actor's origin rather than its feet.

---

### D-069 — Input reaches an actor through an input handler in presentation
**Decided** (by Derik, in code during slice 001 section D; recorded by Claude afterwards).
An `InputHandler` in `src/input/` is **presentation**. Whatever spawns the locally controlled
actor creates one and gives it that actor. Every physics tick it polls held movement with
`Input.get_vector("move_left", "move_right", "move_up", "move_down")` and passes the result to
`actor.move()`. Movement actions are the project's own (`move_*`), bound to WASD and the left
stick, not Godot's `ui_*` actions. The same spawner points the camera at the actor and tells
the debug overlay to watch it.

*Why:* held movement is state, not an event. Polling every tick gives smooth movement and stops
on release, where reading key events stutters on OS key repeat. `get_vector` keeps analog
magnitude, applies the deadzone, and caps diagonals at length 1. Input stays out of the actor
and out of simulation, as the source layout requires, and a handler is given its actor
instead of finding one, so nothing resolves to *the* character
([D-045](#d-045--no-player-singleton-carves-out-the-presentation-layer)). A second local or
networked player is another handler or another source of intents, not a change to the actor.

*Open:* one-shot actions such as dig arrive in section E and are events, not held state.

*Considered:* `_input` key events setting a one-shot direction that the actor clears each tick
(stutters, loses analog and diagonals); `ui_*` actions (clash with UI focus navigation once
menus exist); the camera as a child of the actor (ties it to one actor).

---

### D-070 — The level edge stops an actor like rock; its look is deferred
**Decided** (by Derik, slice 001 section D). An actor cannot walk past a level's bounds, and
that is the whole requirement. It holds today because only `OPEN` tiles are passable
([D-068](#d-068--an-actor-is-a-plain-node-with-a-feet-box-a-stored-depth-and-an-intent)), and
reads outside the level return sentinels, not `OPEN`
([D-059](#d-059--sentinel-values-revised-to-255-and-254)). The edge keeps the shape
`is_in_bounds` gives it at tile granularity, `distance <= radius`: a one-tile spike at north,
south, east and west, and staircases on the diagonals.

*Why:* the brief asks for the edge to do something deliberate, not to crash or let the actor
walk into undefined space. A stop does that. Anything more is presentation, and nothing yet
needs it.

*Deferred:* making the outside of the level **look** like something that can't be dug or
walked into. Today it shows the hatched outside-level ground cell
([D-066](#d-066--layers-are-painted-in-order-and-each-layers-art-decides-what-it-covers)).
Under [pre-alpha-scope §4](./pre-alpha-scope.md) it gets no stub.

*Open:* whether the outermost ring of rock can be dug away, leaving an actor standing directly
against the edge. That is part of section E's rules for digging what cannot be dug.

*Considered:* a visible boundary tile kind at the rim; feedback on bumping the edge; a rounder
disc (`distance <= radius + 0.5`), which removes the cardinal spikes.

---

### D-071 — Pre-alpha dig progress belongs to the digging actor and resets on release
**Decided** (by Derik, slice 001 section E). Digging takes time while the primary action is
held ([tuning-appendix §4](./tuning-appendix.md)). For pre-alpha, progress is kept **per
actor**, for the tile it is digging, and **resets to zero when the actor lets go** of the
button. The tile opens when progress reaches its dig time. Progress is temporary: it is not
part of the tile data and is not saved.

*Why:* the simplest version that makes digging take time, and progress is also what limits how
fast tiles can be dug, so no separate cooldown is needed. Keeping progress on each actor still
honors the rule that no system assumes a single actor (pillar [P5](./game-overview.md)). Two
actors simply don't combine their effort yet.

*Deferred:* combining effort on one tile in co-op. Whether tiles keep partial progress, which
would remove the reset on release, will be reconsidered later.

*Open:* what happens when the target tile changes while the button is still held (moving, or
re-aiming). Reset as on release, or keep digging the original tile.

---

### D-072 — Dig progress also resets when the target tile changes
**Decided** (by Derik, slice 001 section E). Closes the open question in
[D-071](#d-071--pre-alpha-dig-progress-belongs-to-the-digging-actor-and-resets-on-release).
If the tile being dug changes while the button is still held, progress resets to zero and
starts again on the new tile. Progress never carries from one tile to another.

*Why:* the same reset as letting go, so there is one rule. It also stops progress built up on
one tile being spent on another.

---

### D-073 — Mining reach is one tile from the actor's current tile
**Decided** (by Derik, slice 001 section E). An actor can only dig a tile next to the tile it
is standing on, which is its feet tile
([D-068](#d-068--an-actor-is-a-plain-node-with-a-feet-box-a-stored-depth-and-an-intent)). This
holds whatever picks the target: facing direction now, and the grid cursor from milestone M1
([ui-ux-and-controls §2.1](./ui-ux-and-controls.md)). The cursor's roughly 5-tile clamp sets
how far the cursor can move, not how far a dig can reach.

*Why:* you dig what you can touch. It keeps mining physical, close to the face you are working.

*Open:* whether "next to" means 4 neighbors or 8. Diagonal digs leave open tiles that touch only
at a corner, which an actor can't walk between.

---

### D-074 — Mining reach is 4-way; no diagonal digs
**Decided** (by Derik, slice 001 section E). Closes the open question in
[D-073](#d-073--mining-reach-is-one-tile-from-the-actors-current-tile). The diggable tiles are
the four that share an edge with the actor's feet tile: up, down, left and right. An aim
direction is snapped to whichever axis it leans on more.

*Why:* a diagonal dig can leave two open tiles that touch only at a corner. They look connected,
but an actor can't walk between them
([D-068](#d-068--an-actor-is-a-plain-node-with-a-feet-box-a-stored-depth-and-an-intent)
collides one axis at a time). Systems that count neighbors by shared edges, such as support and
chamber connectivity, would also have to handle corner-only gaps.

*Consequence:* aiming near a diagonal sits on the boundary between two targets, and under
[D-072](#d-072--dig-progress-also-resets-when-the-target-tile-changes) every switch resets
progress. Targeting needs a dead zone or hysteresis so the target doesn't flicker there.

---

### D-075 — Aim targeting uses a dead zone, hysteresis, and keeps facing without input
**Decided** (by Derik, slice 001 section E). Answers the consequence in
[D-074](#d-074--mining-reach-is-4-way-no-diagonal-digs). The target tile comes from the
actor's **facing**, one of the four directions, and facing changes only when aim input clearly
asks for it:

- **Dead zone.** Aim input too small to trust is ignored: a stick pushed less than about 0.5,
  or a mouse within about half a tile of the actor, where its direction is mostly noise.
- **Hysteresis.** Facing switches to a new direction only once the aim is clearly inside it,
  about 10–15° past the 45° boundary. Between the two, the current facing holds.
- **No input keeps facing.** With no aim input, or only input inside the dead zone, the
  actor keeps the facing it had. It does not drop to having no target.

The numbers are starting values, to tune by feel.

*Why:* under [D-072](#d-072--dig-progress-also-resets-when-the-target-tile-changes) every
change of target resets dig progress. Without these, a wobbling stick or a drifting mouse near a
diagonal would flip the target between two tiles and make digging feel broken exactly where
players aim most loosely.

*Open:* whether movement also sets facing when there is no aim input (so a gamepad player with
the right stick centered digs the way they last walked), and which way a newly spawned actor
faces.

---

### D-076 — Walking sets facing when there is no aim input; new actors face down
**Decided** (by Derik, slice 001 section E). Closes the open questions in
[D-075](#d-075--aim-targeting-uses-a-dead-zone-hysteresis-and-keeps-facing-without-input).

- **Aim outranks movement.** When aim input is outside the dead zone, it sets facing. When it
  isn't (such as a gamepad's right stick centered), the movement direction sets facing,
  snapped 4-way with the same dead zone and hysteresis.
- **A newly spawned actor faces down.**

*Why:* a player who walks towards a wall and presses dig expects to dig that wall, on either
input. Down is the direction a top-down character conventionally faces at rest.

*Consequence:* walking diagonally on a keyboard is exactly 45°, the boundary itself.
Hysteresis keeps whichever facing the actor already had, so the target doesn't flicker, but it
does mean a diagonal walk keeps the previous facing rather than choosing one.

---

### D-077 — One fixed tool stays in pre-alpha; tools are not expanded
**Decided** (by Derik, slice 001 section E). The actor's dig speed comes from a `ToolData`
resource held in `equipped`, preloaded as a single stone pickaxe. It stays. Pre-alpha does not
expand tools: no tiers in use, no equipping, no swapping, no further tools.

*Why:* it is already built and works, and it puts dig speed where the M1 tools system will look
for it.

*Exception recorded:* [pre-alpha-scope §4](./pre-alpha-scope.md) says deferred systems get no
stubs. This is a deliberate, bounded exception to that rule: one fixed tool and nothing that
selects between tools. Anything that would select or change tools still waits for M1.

---

### D-078 — World is the only thing that changes tiles at runtime
**Decided** (by Derik, slice 001 section E). `World` is the only thing that changes tiles at
runtime. Anything wanting a change emits a request signal to `World`. `World` checks the tile's
current state, changes it through `LevelTiles` (which tells the renderer, per
[D-065](#d-065--each-layer-is-its-own-r8-data-texture-built-through-the-reads-changes-reach-it-from-the-truth)),
and then announces the result (`tile_dug`, or a refusal). Prefab loading writes tiles directly,
before play begins.

For digging: `CapabilityDig` emits `dig_requested(actor, tile)`; `World` refuses with
`dig_refused(actor, tile)` or opens the tile and emits `tile_dug(actor, tile)`.

*Why:* one gatekeeper for every runtime change. Digging now, building and collapse in M2, water
and co-op later all pass through it, so rules about changing a tile (support, ore, host
authority in co-op) live in one place rather than in each system that changes tiles. Diggers
decide when a dig is finished but never write tiles. The request is a signal, per the
[coding-standards](./coding-standards.md) preference for signals between nodes, and it is kept
separate from the announcement so nothing reacts to a change that `World` then refuses.

*Consequences:* `World` re-checks the tile when the request arrives, because it may have changed
since digging began, and finds the level from the tile's own depth, not the level on screen.
`tile_dug` is a gameplay event; the renderer listens to `LevelTiles`' own change notification,
which covers every change, not only digs. `World` never listens to its own announcement.

*Costs accepted:* `LevelTiles`' setters are public, so code can still change a tile without
passing through `World`. That is held by convention and review, not by the language.

---

### D-079 — Dug ore is discarded until M1
**Decided** (by Derik, slice 001 section E). When a dig opens a tile, its ore is cleared and
nothing is given to the actor. Digging copper simply removes it.

*Why:* items and inventory are milestone M1. Under [pre-alpha-scope §4](./pre-alpha-scope.md),
dropped ore gets no stub before then. Clearing the ore is still required, because ore draws over
whatever the top layer shows
([D-066](#d-066--layers-are-painted-in-order-and-each-layers-art-decides-what-it-covers)).

*Deferred:* ore dropping as an item when inventory arrives in M1.
