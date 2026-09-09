# NPCs, Outsiders & the Village Layer

---

## 1. Three populations

| Population | Where | Arrives | Role |
|---|---|---|---|
| **The Upper Shelf** | −1 | From the start | Your people. A few dozen families on the summit shelf. Source of early direction, the first trader, and mild scepticism about your project |
| **Wanderers** | Surface | Early–mid | Scavengers, hermits, a travelling trader picking over a ruined world. Small vendor lists, POI anchors, and the first **recruitable outsiders** |
| **The Deep Warren** | −6/−7 | Endgame | Cut off for generations. Their own tools, culture, and opinion of you. The best recruits in the game ([story-and-setting.md](./story-and-setting.md)) |

---

## 2. Non-resident NPCs — the early game

These NPCs never join your warren. They exist to make the world feel inhabited and to give the
player somewhere to *go*.

- **The travelling trader.** Appears at a surface camp on a rotation. Buys ore and surplus,
  sells a short rotating list — rope, seeds, oil, the occasional blueprint. Critically, a
  trader is a **reason to haul things up**, which reinforces the central pillar rather than
  bypassing it. Trades are by weight and bulk, so the trip is the cost.
- **The hermit in the broken tower.** A fixed surface POI. Sells nothing; knows things. Points
  at ruins, explains a technique, comments on how deep you have gotten.
- **Upper Shelf elders.** Give the early objectives that teach the loop without a tutorial
  voice: *"nobody has been down past the second seam since my father's time."*

**Rule:** no NPC ever sells a shortcut around a pillar. Nobody sells you a lift, teleport, or
carry-capacity upgrade that trivialises hauling.

---

## 3. The village / worker layer — deferred

Explicitly **out of scope for pre-alpha and the first playable**. It is recorded here so the
earlier systems are not built into a corner.

Intended model, loosely Palworld-shaped: recruited molepeople live in your warren, have
aptitudes, and are assigned to stations or zones where they handle upkeep and production.

### Constraints already fixed by earlier decisions

These are **binding** on whoever designs this layer later:

1. **Workers are immune to Marrow-Ache.** A good workshop is therefore partial insurance
   against death, and death becomes an argument for automation rather than a tax on inventory
   ([D-007](./design-decisions.md)).
2. **Workers never excavate new space.** They haul, process, farm, maintain and tend. They do
   not dig your warren for you — the player always holds the shovel, or the core fantasy is
   gone ([core-loops.md §5](./core-loops.md)).
3. **Workers need rooms.** Recruitment and retention key off the room comfort score that
   [base-building.md §2](./systems/base-building.md) already computes. No second happiness
   system.
4. **Nothing may assume a single actor.** Worker code must be actor-agnostic so co-op does not
   require a rewrite ([D-004](./design-decisions.md)).
5. **Automation targets tedium, not authorship.** The test for any proposed worker job: does
   removing it from the player delete a decision, or delete a chore? Only chores qualify.

### Recruitment sources
- Surface wanderers, who must be persuaded and then **become** molepeople (see §4).
- Upper Shelf families, who move down as your warren becomes better than theirs.
- The Deep Warren, at the end — the most skilled, and the narrative payoff for reconnection.

---

## 4. Spore sickness — how an outsider becomes a moleperson

*Resolved: [D-025](./design-decisions.md). Part of the deferred worker layer, but specified
here because it retro-explains the entire species.*

Molepeople are not a separate people. They are what outsiders **become**. Sun-sensitivity is
not biology — it is acquired immunity, and it has a price.

### The illness

An outsider living underground accumulates **spore load** from the fungus the warren is built
on. It progresses on a slow clock, accelerated by proximity to fungus beds and compost, slowed
by ventilation and room comfort.

| Stage | Effect |
|---|---|
| **Clear** | No effect. Newly arrived |
| **Rattling** | A cough. −10% work speed |
| **Fevered** | −30% work speed. Visibly unwell; will mention it |
| **Failing** | −60% work speed. Stops taking new assignments |
| **Coma** | No work. **Must be fed daily or they die** |
| **Immune** | Recovered. Full work speed, permanently — and sun-sensitive forever |

### The two paths — and the standing decision

The special cooked remedy (working name **clearlung broth**) temporarily pushes spore load back
down. But suppressing the illness also suppresses the adaptation, so:

| | **Maintained** | **Transitioned** |
|---|---|---|
| You do | Keep them dosed, indefinitely | Let it run, nurse them through the coma |
| Costs | Permanent production upkeep — ingredients, cooking time, delivery | A risky, frightening stretch where they are a liability |
| They keep | **Sun tolerance** | Nothing of their old self |
| They gain | Nothing permanent | Immunity, dark vision, dig aptitude, no upkeep ever again |
| Best at | **Surface work at noon — which the player can never do** | Everything below ground, forever |

This is the design's payoff: **the surface is permanently staffable, but only by people you are
deliberately keeping sick.** Neither path is strictly better, the choice is per-recruit, and it
can be reversed up until the coma begins.

### The coma, and keeping this warm

The coma is a **nursing** sequence, not a horror one — you are keeping someone alive through a
fever, which is squarely inside [D-019](./design-decisions.md)'s register. Rules that keep it
from being cruel:

- It is **telegraphed for days** in advance. Nobody is surprised by it.
- Preparation genuinely works: a well-fed recruit, a high-comfort room, and stocked food make
  a successful transition the overwhelmingly likely outcome.
- Feeding is a **daily** touch, not a constant one — a chore you remember, not a leash.
- Waking up is a proper moment: a name, a thank-you, and a new moleperson in your warren.
- Death is possible but should require genuine neglect. This must never feel like a coin flip
  on someone the player has grown attached to.

### Consequences elsewhere
- The Deep Warren has been transitioning people for generations, and knows things about the
  process that the Upper Shelf has forgotten. Good endgame material.
- Clearlung broth is a reason for the **surface crop economy** to matter permanently — its
  ingredients should come at least partly from above.
- The player character is already immune and never experiences any of this. It is a system you
  administer to others, which is exactly what makes it interesting.

---

## 5. Pre-alpha subset

- [ ] One travelling trader at a fixed surface camp, with a short buy/sell list
- [ ] Two or three Upper Shelf NPCs on −1 giving early objectives

Cut: the hermit, trader rotation, all recruitment, the entire worker layer, the Deep Warren.
