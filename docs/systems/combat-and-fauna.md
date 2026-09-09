# Combat & Fauna

Combat is **present but secondary** ([D-008](../design-decisions.md)). It exists to make
expeditions risky and to make lit, defended, well-built tunnels *worth building*. It is never
the reason to play, and it never gates descent.

---

## 1. Design constraints

1. **Combat serves excavation.** Every creature should make the player think about
   infrastructure — lighting, chokepoints, doors, routes — not about builds and rotations.
2. **Nothing hates you.** Tone is warm ([D-019](../design-decisions.md)). The mountain's fauna
   is *ecology*, not an army. Creatures are territorial, hungry, startled, or defending
   something. Several are neutral until provoked.
3. **No stat wall.** Weapon tiers exist but progression through the mountain is never a DPS
   check.
4. **You can always disengage.** There is no sprint ([D-032](../design-decisions.md)), so
   fleeing depends entirely on creature speed. **No common creature may exceed the player's
   unloaded walk speed**; the fastest may match it, and only briefly. A player who decides to
   leave must be able to leave — otherwise combat stops being optional, which contradicts this
   whole document.
5. **Light is a weapon.** Some deep fauna will not enter lit tiles. This is deliberate: it
   makes light infrastructure and defence infrastructure the same investment
   ([light-and-sunlight.md §3.2](./light-and-sunlight.md)).

---

## 2. The verbs

Deliberately small.

| Verb | Notes |
|---|---|
| **Melee swing** | Directional, chunky, shares feel with mining |
| **Ranged** | Sling or thrown; limited ammo, mostly for softening |
| **Dodge / roll** | Short i-frames |
| **Block** | Later tier, optional |
| **Environmental** | Collapsing a ceiling on something, closing a door, luring into light |

The environmental column should always be the most satisfying option available.

---

## 3. Fauna by stratum

| Stratum | Creature | Behaviour |
|---|---|---|
| Surface | **Scrub hound** | Pack predator, active at dusk and night — the cost of the safe travel window |
| Surface | **Carrion bird** | Harasses, steals from your pack. Annoying, not dangerous |
| −1 Rootshelf | **Root worm** | Neutral. Attacks only if you dig into its burrow |
| −2 Greyseam | **Cave cricket** | Swarming, weak, drawn to noise. Mining attracts them |
| −2 | **Seam lurker** | Ambushes from unlit tiles. **Will not enter lit ones** — the teaching creature for light-as-defence |
| −3 Terraces | **Rubble crab** | Armoured, slow. Nests in collapse debris; punishes sloppy excavation |
| −4 The Works | **Rust hound** | Fast, hunts in the big open halls where you cannot use chokepoints |
| −5 Drowned | **Something large in the water** | Avoid, do not fight. Drain the region and it leaves |
| −6 The Crush | **Pale digger** | Burrows through walls. Ignores your chokepoints entirely and forces a rethink |

Note the intent: **each stratum's creature attacks a different piece of your infrastructure.**
Crickets punish noise, lurkers punish darkness, crabs punish bad digging, rust hounds punish
big rooms, pale diggers punish relying on walls. Combat is a critique of your base.

---

## 4. Guardians

A small number of authored set-piece encounters, **none of which block descent**. They guard
*regions* and rewards, never stairways ([D-012](../design-decisions.md)). Fighting one is
always optional; there is always an engineering answer that avoids it.

---

## 5. Death

No item loss, no corpse run. Respawn at your bed with **Marrow-Ache** for roughly one in-game
day: reduced movement, excavation, and manual crafting speed. Dying while afflicted deepens it
to a capped tier. Recovery accelerates with room comfort
([base-building.md §2](./base-building.md)) and later with medicine.

See [D-007](../design-decisions.md) for the full rationale, including why worker crafting must
remain immune.

---

## 6. Pre-alpha subset

- [ ] Melee swing, dodge
- [ ] Root worm, cave cricket, seam lurker, scrub hound
- [ ] Light-avoidance behaviour on the seam lurker
- [ ] Death, respawn, Marrow-Ache tier 1

Cut: ranged, block, guardians, all fauna below −3, Marrow-Ache tier 2, medicine.
