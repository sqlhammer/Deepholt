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
