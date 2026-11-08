# Slice 010 — Holding it up

> Dig out a room wider than the rock can span and the ceiling starts to crack. You have
> forty-five seconds to set a timber prop, or the room fills with rubble. Narrow tunnels never
> fail; the deeper you go, the narrower "wide" becomes.

*Proposed by Claude, 2026-11-08, for Derik's approval. Scope and every fork settled in planning
([D-163](../docs/design-decisions.md#d-163--slice-010-is-holding-it-up-the-support-rule-collapse-timber-props-the-overlay)
to D-166). Agent mode on a `slice-010` branch. Nothing is built until Derik approves this brief.*

## Where we are

Slices 008 and 009 are merged ([008](./log/008-what-you-carry.md),
[009](./log/009-letting-go.md)), **neither walked by hand yet.** A player can dig, breach, carry,
drop and pick up, and build ladders that cost timber. Nothing about excavation is unsafe: a room of
any size stands forever.

**What 010 adds** ([digging-and-structure §2–4](../docs/systems/digging-and-structure.md)):
- **The support rule:** every excavated tile is Stable within R tiles (Chebyshev) of a support,
  Marginal at R+1, Failing beyond. R is 8 at −1, falling to 3 at −6 and −7.
- **Only what players dig is judged** (D-164): a saved "excavated" bit, so natural caves never
  fail.
- **A countdown, 45 s, per connected failing region,** saved and resumed; a support cancels it.
- **Collapse:** the region fills with rubble, a new top kind cleared like a dig, yielding nothing;
  what's under it is buried, not destroyed; anyone caught is moved clear.
- **Timber props:** a fixture, 2 timber, a support, blocks walking; placed from build mode or the
  quick key.
- **The overlay:** ceiling tiles tinted green, amber, red.

## What should be true when you stop

By hand, unless marked:

1. On −1, dig a corridor: nothing warns, however long it is. Dig a room 18 tiles wide: its middle
   goes amber, then red, and cracks spread with a notice.
2. Set a prop in the room's middle (F, or build mode's second item) before the time runs out: the
   cracks stop and the overlay turns green.
3. Let a countdown run out: the red tiles fill with rubble; if you stood there, you're moved
   clear. Dig the rubble out (fast, no stone).
4. A ladder or a drop under rubble is still there once it's cleared.
5. Save with a countdown running and relaunch: it resumes, not restarts.
6. Toggle the overlay (V): green, amber and red over what you've dug.
7. *Automated:* natural caves never fail; a 2-wide tunnel never fails at any depth; R falls with
   depth; an NPC's digging is judged the same (pillar [P5](../docs/game-overview.md)).

## Mode

**Agent**, for the whole slice (Derik, 2026-11-08), on a `slice-010` branch with small commits,
one or more per section, the suite green before each; Derik merges the PR. Every fork was settled
in planning; Claude stops for anything new with long-term consequences.

## What you're deciding

Every fork was settled in planning on 2026-11-08 (D-163 to D-166). The list stays as the record:

- **Scope:** the rule, the countdown, collapse and clearing, props, the overlay (D-163).
- **Only what players dig** (D-164), after talking it through: R already makes narrow digging
  free, so only wide player-made rooms need props.
- **The countdown is saved; caught actors are moved clear** (D-163).
- **Props:** a fixture, 2 timber, blocks its tile (D-165).
- **Rubble:** a top kind, cleared like a dig, no yield; buried, not destroyed (D-166).
- **45 s, cracks, a notice, the overlay** (D-166).

**Proposed bindings, checked against `project.godot`** (part of approving this brief):

| Action | Keyboard | Pad | Note |
|---|---|---|---|
| Support overlay | `V` | L3 | As ui-ux §4 has them |
| Quick prop (at the cursor in build mode, else the faced tile) | `F` | D-pad ↓ | ui-ux §2.5's reserved binding; D-pad ↓ still moves the inventory's selection while it's open |
| Build item: ladder / prop | `1` / `2` | RB cycles | ui-ux's hotbar keys; RB is the hotbar's, which doesn't exist yet |

## Already settled

- **The rule, the R table, the states, the countdown's purpose, collapse and burial**
  ([digging-and-structure §2–4](../docs/systems/digging-and-structure.md),
  [D-014](../docs/design-decisions.md)).
- **No upward cascade in pre-alpha** ([pre-alpha-scope §4](../docs/pre-alpha-scope.md)).
- **The player is never surprised by a collapse they couldn't prevent** (§2's countdown).
- **Costs through the fixture gatekeeper, one rule shared with the preview** (D-159).
- **Memory's byte has seven reserved bits** (D-147); "excavated" takes one.
- **The stuck-actor rule moves an actor off an impassable tile** (D-115).
- **Every number in the profile** (D-135); **format v1 edited in place** (D-133).

## Traps

### 1. The rule must be cheap enough to run on every dig

A naive check measures every excavated tile against every support. Recompute only around the
change (R+2 tiles), with a distance transform over that window, and keep each level's states as
derived data that's never saved.

### 2. A dig changes supports, not just ceilings

Digging a wall removes a support. A tile that was Stable can become Failing because of a dig
three tiles away. The recompute window is around the dug tile, not just the tile itself.

### 3. A countdown's region changes while it runs

Digging more of a failing room grows its region; a prop can split it. A region's timer belongs to
its tiles: tiles that join keep the oldest time left, tiles that leave lose it, and a region that
splits keeps the time in both halves.

### 4. Burial must not lose anything

A ladder, a brazier or a drop under rubble is kept and saved, and comes back when the rubble is
cleared. Rubble over a ladder's hole or its landing makes the ladder unusable, not gone.

### 5. Collapse during a load

A countdown saved at one second left must not collapse while the load is still building
(slice 004's lesson, D-143's). Countdowns tick only in a running world.

### 6. The new top kind meets every existing rule

Rubble is solid: collision, the flood (D-145: a face, not open), the dig (diggable, with its own
hardness), the breach (not plain floor), the renderer (art: a placeholder cell), and the save
(top kinds are bytes; a new id, never reused).

## Carried into this slice

- **008's and 009's by-hand walks**, not yet done.
- **The "dragon bag" randomizer** (D-156) and **drop decay** (D-160) stay deferred.
