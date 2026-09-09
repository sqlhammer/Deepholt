# Digging & Structural Integrity

Pillar P4. Excavated space must be held up. This is what separates a *warren* from a hole.

---

## 1. Digging

| Action | Target | Notes |
|---|---|---|
| **Mine** | Wall tile | Primary verb. Speed = f(tool tier, rock hardness, Marrow-Ache) |
| **Breach** | Floor tile | Slower, deliberate, requires a tool of that stratum's tier. This is the *only* remaining hard tool gate on descent |
| **Clear** | Rubble | Fast but bulk work. What you do after a collapse |
| **Fell / harvest** | Surface flora | Under exposure pressure |

Rock hardness rises with depth, so tool tier still matters — but per [D-012](../design-decisions.md) the real
constraint on descent is whether you can *supply* the level, not whether you can break its
floor. See [world-and-generation.md §3](../world-and-generation.md#3-region-access--levels-are-open-regions-are-earned).

### Digging next to water
Walls adjacent to a water body are **unmistakably readable before you swing** — damp
discoloration, seepage particles, dripping audio, and a distinct struck-rock sound. Breaching one
lets the water through by connectivity ([D-039](../design-decisions.md)), which is a genuine
setback and must never be a surprise.

This is also where collapse and water meet: a cave-in that fails a wall adjacent to a water body
**floods the collapsed area**. It is the ancestors' disaster in miniature, and it is the strongest
argument in the game for shoring properly.

### Spoil
Mining produces stone and loose spoil. Because inventory is weight-limited, spoil that you
keep is spoil you carry. Design rule: **spoil must never become a hauling chore.** Loose spoil
piles decay if left, stone is only worth keeping when you have a use for it, and dumping
unwanted mass down a chute is always a legal answer. We are not building Dwarf Fortress
hauling.

---

## 2. The support rule

> **Every ceiling tile must lie within `R` tiles (Chebyshev) of a support.**

A *support* is any wall tile — natural rock, a natural pillar left standing, or a built wall —
or a placed column.

### R by depth

| Depth | Base R | Widest unsupported hall (timber) |
|---|---|---|
| −1 | 8 | 17 tiles |
| −2 | 7 | 15 |
| −3 | 6 | 13 |
| −4 | 5 | 11 |
| −5 | 4 | 9 |
| −6 | 3 | 7 |
| −7 | 3 | 7 |

### Column materials add R back

| Support | Bonus | Available |
|---|---|---|
| Timber prop | +0 | start |
| Cut stone column | +1 | −2 |
| Iron-braced column | +3 | −4 |
| Ancestral arch | +5 | −6, recovered technique |

This is the heart of the system. **Depth takes your architecture away and technology gives it
back.** An iron-braced hall at −6 (R=6) is as open as a timber hall at −3. The visible reward
for progression is *beautiful rooms*, and a player can read a screenshot's depth from how
densely it's pillared.

### States

| State | Range | Behaviour |
|---|---|---|
| **Stable** | ≤ R | Nothing |
| **Marginal** | R+1 | Dust motes, occasional creak. Cosmetic warning only — this is the teaching band |
| **Failing** | > R+1 | Failure countdown begins |

### The failure countdown
Roughly **30–60 seconds**, escalating and unmissable: falling dust → rattling pebbles →
visible ceiling cracks → a low groan that ducks the music. Placing a valid support at any
point cancels it. The player is never surprised by a collapse they had no chance to prevent.

---

## 3. Collapse

When a countdown completes, the failing area collapses:

- Tiles fill with **Rubble** (a clearable obstruction, not a permanent wall).
- Actors caught in it take damage, knockback, and a brief stun. It is survivable at full
  health; it will kill you at low health.
- **Built objects are buried, not destroyed.** Clear the rubble and your workbench is fine.
  This is a firm rule — collapse must never delete hours of work.
- Lights in the area are extinguished. The room goes grey. (Emotionally, this is the punch.)

### Upward cascade (rare)

If a collapse covers **≥25 contiguous failing tiles** *and* the floor of the level above is
itself unreinforced, there is a chance the floor above fails too:

- A hole opens between the two levels — rubble falls through, and what's left is an
  unplanned **shaft**.
- The level above takes rubble and damage around the breach.
- **Cascade propagates at most one level.** No chain reactions, ever.

Two things make this fair rather than cruel:

1. **Reinforced Floor** is a cheap buildable tile that is immune to cascade. Once the player
   learns this, protecting their base is a known, affordable action — and the lesson
   ("reinforce under anything you care about") is exactly the lesson the ancestors failed.
2. It requires a *large* unsupported area. You cannot trip it by accident with careful play.

And one thing makes it delightful: a deliberate cascade is a **tool**. If you're reckless and
in a hurry, over-digging a big chamber is a cheap way to open a shaft between levels. Players
will discover this and it should not be patched out.

---

## 4. The support overlay

First-class UI on a dedicated hotkey, not buried in a menu. Toggling it shows:

- Ceiling tiles tinted **green / amber / red** for Stable / Marginal / Failing
- Coverage radius rings around every existing support
- **Ghosted suggestions** for where a column would restore coverage
- Current depth's `R` and the bonus of your best available column, as a header

Design intent: structural integrity should feel like *design work with a good tool*, not like
a trap you spring. Players who never toggle the overlay should still survive on careful play;
players who use it should be able to plan a 40-tile hall on paper.

---

## 5. Pre-alpha subset

- [ ] Mine / breach / clear verbs with tool tiers and per-stratum hardness
- [ ] Support rule with depth-scaled R, timber props and cut stone columns
- [ ] Three ceiling states + telegraphed failure countdown
- [ ] Local collapse with rubble, damage, burial-not-destruction
- [ ] Support overlay with tints and radius rings

Cut from pre-alpha: upward cascade, reinforced floor, iron-braced columns, ancestral arches,
ghosted column suggestions, spoil decay tuning.
