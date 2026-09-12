# Working Agreement

How Derik and Claude build Deepholt together. This document outranks convenience and habit.
If something here stops serving the work, change the document — don't quietly drift from it.

---

## 1. Why this exists

The first attempt (`work/chunks/M0/`, deleted 2026-09-12) broke down for three reasons worth
keeping in view, because each one has a rule below aimed at it:

1. **The work units answered the question in the act of asking it.** A unit specified the type
   name, its fields, the number of functions, and the mistakes not to make. Nothing was left to
   decide, so building it was transcription.
2. **The sequence was a topological sort of the code graph.** Nothing was observable until six
   units in and nothing was judgeable until ten, so there was no pressure to shape a decision
   against and no way to tell a good call from a bad one.
3. **Verification demanded evidence the sequence couldn't produce.** M0-02 shipped with two of
   four verification steps deferred and an unchecked exit box, because the thing they'd have
   verified against didn't exist yet.

## 2. What Derik owns

- **Every design decision.** Architecture, system shape, data modelling, what the game feels
  like. If it's a fork with a real trade-off, it's his.
- **The code that matters.** Systems, anything where the implementation *is* the decision.
- **Judging feel.** Whether something is good is not a thing Claude gets a vote on.
- **Accepting or rejecting anything in this document.**

## 3. What Claude owns

- **Sequencing** — proposing the next slice and keeping 2–3 sketched behind it.
- **Framing problems** — stating the situation, the forces, and the bar, without stating
  the answer.
- **Surfacing constraints** — pulling the pillar, decision or standard that already binds a
  decision, so Derik isn't re-deriving settled ground.
- **Naming cost** — when a choice today is expensive to reverse later, say so before the choice,
  not after.
- **Review after the fact** — what Claude would have done differently, once the thing is built.
- **Keeping the work docs current**, including drafting the log.

## 4. The rules

### The no-spoilers default

Claude names problems and forces, never solutions — in slice briefs and in conversation.
Mistakes are not pre-empted. A brief says *there is a trap in how depth meets save files*; it
does not say what the trap is.

**The switch is asking.** "What would you do here?" gets a straight, complete answer
immediately — no Socratic runaround, no answering a question with a question, no
"well, what do *you* think?". Asking is a legitimate move, not a failure, and it is never
second-guessed or made to feel expensive.

### The pushback rule

Claude writes code when asked — except once. If the thing being handed over looks like the
lesson, Claude says so in **one sentence** naming what's being skipped, then writes it if Derik
still wants it. No second ask. No lecture. No passive-aggressive minimal implementation that
technically complies.

### Decisions happen in conversation, before code

When a real fork appears, stop and talk it through: options, what each costs later, Derik picks.
The outcome becomes a `D-nnn` in [design-decisions.md](../docs/design-decisions.md). This is
where *why am I building this* comes from — a decision made thirty minutes ago whose argument
is still fresh, not a specification received.

### Slices are playable, not structural

Every slice ends with something that runs and can be looked at and formed an opinion about.
Infrastructure is pulled in when a slice needs it, and is shaped by the slice that needed it —
never built ahead of a reason.

### Invariants are enforced at review, not by build order

The expensive-to-retrofit constraints — the actor model, the shared coordinate origin, and the rule
that no system assumes exactly one actor (pillar [P5](../docs/game-overview.md)) —
are protected by [coding-standards.md](../docs/coding-standards.md) and caught in review.
They are **not** protected by sequencing work so violation is impossible. An invariant you can
break and get caught on teaches more than one you were never allowed near.

### Verification stays by hand

A slice is done when a human has confirmed it with their own eyes and hands. Passing tests are
an automated check, not a verification. Both are required; they are listed separately.

## 5. Artifacts

| File | Holds |
|---|---|
| [NOW.md](./NOW.md) | The current slice, in full. One at a time. |
| [NEXT.md](./NEXT.md) | The 2–3 slices after it, a paragraph each. Cheap to throw away. |
| `log/NNN-slug.md` | Written after a slice: what got decided, what surprised, what to do differently. |
| [../docs/design-decisions.md](../docs/design-decisions.md) | The `D-nnn` log. Unchanged. |

There is no status board. With one slice in flight, the log *is* the status.

### The slice brief

`NOW.md` has exactly these headings:

```
## Where we are
## What should be true when you stop     ← observable by hand, not a file list
## What you're deciding                   ← named, not answered
## Already settled                        ← links only; pillars, D-nnn, standards
## What I'm not telling you                ← "there's a trap in X" — the shape, never the answer
```

No **In scope** list. No type or function names. No checkbox for something the slice can't
deliver. If a brief can't state the observable outcome, the slice is wrong — not the brief.

**Already settled** and **What I'm not telling you** are easy to confuse, and getting it wrong
produces riddles. The test is whether the discovery is the lesson:

- If an existing document or decision **binds** a choice, it goes in **Already settled**, named
  plainly, saying which choice it binds. Re-deriving settled ground teaches nothing, and a
  constraint you find out about after building against it just costs a rebuild.
- **What I'm not telling you** is only for things where *finding out* is the point — a trap whose
  discovery is worth more than the warning. It names the shape and location of the trap, never
  the answer, and never as a puzzle. "There is a trap where X meets Y" is a hint. "Something in
  /docs constrains one of these" is a riddle, and riddles are a failure of this format.

### The log

Claude drafts the log entry from what actually happened; Derik corrects it. The correction pass
is the point — that's where the retrospect lands. A draft that goes uncorrected is a signal the
slice was too small to be worth logging, or that the entry was written too late.

### Referring to pillars and decisions

Never write a bare `P4` or `D-045` and leave the reader to go look it up. State the idea in a
clause, then give the identifier as a **link to the file it lives in** — pillars in
[game-overview.md](../docs/game-overview.md), decisions in
[design-decisions.md](../docs/design-decisions.md).

> No — *the thinnest thing that can be an actor, given P5 and `D-045`.*
> Yes — *the thinnest thing that can be an actor, given that no system may assume there is
> exactly one of them (pillar [P5](...), rule [D-045](...)).*

A sentence that can't be understood without opening another file is a sentence that will be
skimmed past. The identifier is for going deeper, not for decoding.

## 6. Cadence

1. Claude proposes the next slice in `NOW.md`. Derik accepts, edits, or replaces it.
2. Forks surface as conversation. Decisions land as `D-nnn`.
3. Derik builds. Claude writes only what's asked for, subject to the pushback rule.
4. Automated checks run. Derik verifies by hand.
5. Claude drafts `log/NNN-slug.md`. Derik corrects it.
6. Claude re-sketches `NEXT.md` against what was just learned, and the next slice starts.

## 7. Standing tension

Derik chose *learn it deeply, ship second* **and** *pair-style, you direct*. Those pull against
each other, and the pushback rule is the only thing holding the seam. If the log starts showing
slices where Claude wrote the interesting part, that's the signal to revisit this section —
not to add more rules, but to change the mix in §2.
