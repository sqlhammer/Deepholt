# M0-06 — Actor and component model

**Depends on:** M0-02 · **Feeds:** M0-09, M0-10
**Acceptance check:** §10.4 (an `Actor` with components, and **no `Player` singleton anywhere**)

## Goal

The rule from [D-004](../../../docs/design-decisions.md) made structural rather than aspirational:
**no system may assume a single actor.** The worker layer, when it arrives, should require no
changes here — that is the test, and this chunk is where it is won or lost.

## In scope

- One `Actor` base with a stable `actor_id`. The player, a recruited moleperson and a creature
  are all Actors with different component sets.
- Capabilities as **components**, added and removed at runtime:
  `Inventory`, `Locomotion`, `Health`. (`Exposure`, `Hunger`, `Afflictions` and `WorkAssignment`
  arrive with their own milestones and must need no change here.)
- **A creature-shaped actor carrying `Health` + `Locomotion` only.** This is the chunk's real
  test: it proves the codebase handles heterogeneous component sets, so nothing anywhere reaches
  through a component that may not be there. §6 already fixes this — *"a creature simply lacks
  most of them"*.

  Component queries and tests must be **parameterised over the component**, never written against
  `Inventory` specifically. `Exposure`, `Hunger` and `Afflictions` are the durable examples:
  creatures do not burn in sunlight, do not get hungry, and Marrow-Ache is a moleperson
  affliction ([D-007](../../../docs/design-decisions.md)).
- An `ActorRegistry` returning a **set** of actors, with queries by component and by position.
  Anything reading "the player's position" for gameplay must accept a set
  ([§6](../../../docs/tech/world-runtime-and-persistence.md)).
- An input-control component attached to *whichever* actor the player is driving, so control is
  a property of an actor rather than an identity.
- `builder_id` recorded on anything constructed. Storage is shared by default; ownership is
  recorded for later, not enforced now.
- No automated check for the singleton rule — it's enforced by code review against the
  [no player singleton](../../../docs/coding-standards.md#no-player-singleton) entry in the
  coding standards doc, which covers `get_player`, `Player.`, `PlayerSingleton`, an autoload
  named `Player`, `class_name Player`, and the two Godot-idiomatic singletons in disguise —
  `get_first_node_in_group("player")` and `get_node("/root/Player")` — as well as the
  scope rule from [D-045](../../../docs/design-decisions.md): `LocalActor` is permitted only
  in `src/render/` and `src/debug/`, and fails review anywhere else.

## Out of scope

Actual movement physics beyond debug-grade motion (M1 owns weight-limited locomotion). Health
values, damage, death and respawn (M6). Inventory capacity rules and weight (M1).

## Open question deliberately left open

**Whether creatures carry `Inventory` is not decided here, and does not need to be.** No
pre-alpha creature holds items — root worm, cave cricket, seam lurker and scrub hound neither
steal nor drop ([combat-and-fauna §6](../../../docs/systems/combat-and-fauna.md)) — so the
creature stand-in lacks it today. The carrion bird, which *does* steal from your pack, is cut
from pre-alpha; when it arrives it simply gets an `Inventory`, and that costs nothing. Being able
to make that call later, per creature, without touching any other system **is what the component
model is for**.

What must not happen is code that assumes every actor has one.

## Design constraints

- No `Player` singleton, no `get_player()`, no global that resolves to "the" character. This is
  also the one thing that would break co-op readiness ([§9](../../../docs/tech/world-runtime-and-persistence.md)).
- Two actors is the smallest number that catches a hidden singleton assumption. Every verification
  step below uses two.

## Automated checks

| Check | Expectation |
|---|---|
| spawn 2 actors, query by component | both returned; a creature-shaped actor lacking `Inventory` is excluded |
| add and remove a component at runtime | queries update accordingly |
| `actor_id` stable and unique across 100 spawns | pass |

## Human verification

1. Launch the debug scene and spawn **two** controllable actors on the same depth. → Both appear,
   with distinct `actor_id`s in the overlay.
2. Switch control between them with the debug key. → Whichever you drive moves; the other stays
   put and is still listed as a live actor.
3. Spawn a third actor with **`Health` + `Locomotion` only** (a creature stand-in). → The
   overlay's per-component lists each show two actors, not three, and nothing errors. Check at
   least two different components, not just `Inventory`.
4. Move actor A to another depth, leaving actor B behind. → The registry still reports both, with
   correct separate depths.
5. Search the codebase yourself for `get_player` and `Player`. → Nothing.
6. Search for `LocalActor`. → It appears **only** under `src/render/` (and `src/debug/`, if the
   debug camera uses it). Any hit under `src/world/`, `src/sim/`, `src/entity/` or `src/persist/`
   is a D-045 violation, whatever it is named, and should be caught in review.

## Exit checklist

- [ ] `Actor` + component model in place, components runtime-attachable
- [ ] Registry answers with sets, never a single actor
- [ ] Component queries parameterised over the component, not written against `Inventory`
- [ ] A `Health` + `Locomotion` actor coexists with full actors and breaks nothing
- [ ] Control is a component, not an identity
- [ ] `builder_id` recorded
- [ ] Reviewed against the no-player-singleton entry in `docs/coding-standards.md`: no match for
      `get_player`, `Player.`, `PlayerSingleton`, an autoload named `Player`, `class_name Player`,
      `get_first_node_in_group("player")`, or `get_node("/root/Player")`
- [ ] `LocalActor` confirmed outside `src/render/` and `src/debug/` nowhere in the codebase

## Discovered work

-
