# Deepholt

A survival-crafting game about digging a home *down* through a mountain. Godot 4, in
[`game/`](game/). Design docs in [`docs/`](docs/) — start at
[game-overview.md](docs/game-overview.md). Execution in [`work/`](work/).

## How we work

**Read [work/WORKING-AGREEMENT.md](work/WORKING-AGREEMENT.md) before proposing or planning
anything.** The two rules that change default behaviour most:

- **No spoilers.** Name problems and forces, never solutions. Do not pre-empt mistakes. A brief
  says *there is a trap in how depth meets save files*; it does not say what the trap is.
  **Being asked directly is the switch** — "what would you do here?" gets a straight, complete
  answer immediately, with no Socratic runaround and no making the asking feel expensive.
- **Pushback, once.** Write code when asked — except that if the request looks like the lesson,
  say so in one sentence naming what's being skipped, then write it if Derik still wants it.
  No second ask, no lecture, no deliberately thin implementation.

Derik owns every design decision and the code that matters. Claude owns sequencing, problem
framing, surfacing settled constraints, naming retrofit cost, after-the-fact review, and the
work docs.

Current slice: [work/NOW.md](work/NOW.md).

## Hard constraints

- [docs/coding-standards.md](docs/coding-standards.md) — tabs, strong typing, signals over
  direct calls, the source layout, and the **no player singleton** rule — simulation takes actors
  as parameters, nothing global resolves to *the* character (rationale:
  [design-decisions.md](docs/design-decisions.md), `D-045`).
- [docs/design-decisions.md](docs/design-decisions.md) is append-only. Reversals get a new
  `D-nnn`, never an edit.
- Deferred systems get no stubs, no placeholders, no "just the interface"
  ([pre-alpha-scope §4](docs/pre-alpha-scope.md)).

## Commands

- Tests: `scripts/test.ps1` (GUT, headless, non-zero exit on failure).
