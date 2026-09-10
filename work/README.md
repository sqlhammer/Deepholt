# Work Tracking

Design lives in [`/docs`](../docs/). Code lives in [`/game`](../game/). **Execution tracking lives here.**

## Structure

```
work/
  STATUS.md              board — one line per chunk, current state
  milestones/            one brief per milestone: exit criteria + chunk list
  chunks/<M>/            one file per chunk of work
  verification/<M>/      human verification logs, filled in at the end of a chunk
```

## What a chunk is

A **chunk** is the unit of work in this project. It is:

- small enough to finish in one sitting,
- self-contained enough that nothing else must be half-built for it to work,
- and ends with a **human verification** — a numbered list of things a person can
  do with their own hands and eyes to confirm it is real.

A chunk without a human verification step is not a chunk. "The tests pass" is an
automated check, not a verification; both are required, and they are listed separately.

## Chunk states

| State | Meaning |
|---|---|
| `TODO` | Not started |
| `WIP` | In progress |
| `REVIEW` | Code done, awaiting human verification |
| `DONE` | Human verification passed and logged in `verification/` |
| `BLOCKED` | Waiting on a decision or another chunk |

A chunk moves to `DONE` only when a log exists at
`work/verification/<M>/<chunk-id>.md` with a real date and a real name on it.

## Working a chunk

1. Set the chunk to `WIP` in [STATUS.md](./STATUS.md).
2. Build only what the chunk's **In scope** section lists. Anything you notice that
   belongs elsewhere goes in that chunk's **Discovered work** section, not into this one.
3. Run the automated checks.
4. Set `REVIEW`, then walk the human verification steps.
5. Copy [`verification/TEMPLATE.md`](./verification/TEMPLATE.md), fill it in, set `DONE`.

## Rules that outrank convenience

- Design docs are the source of truth. If a chunk contradicts `/docs`, the chunk is
  wrong — fix the chunk file, or amend the design with a new `D-nnn` entry.
- Out-of-scope means out of scope. Deferred systems ([pre-alpha-scope §4](../docs/pre-alpha-scope.md))
  do not get stubs, placeholders, or "just the interface".
- No chunk may introduce a `Player` singleton ([world-runtime §6](../docs/tech/world-runtime-and-persistence.md)).
