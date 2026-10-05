# Deepholt

A survival-crafting game about digging a home *down* through a mountain. Godot 4, in
[`game/`](game/). Design docs in [`docs/`](docs/) — start at
[game-overview.md](docs/game-overview.md). Execution in [`work/`](work/).

## How we work

**Read [work/WORKING-AGREEMENT.md](work/WORKING-AGREEMENT.md) before proposing or planning
anything.** The two rules that change default behaviour most:

- **Ask the mode first.** Before engaging with any segment of work, ask which mode it runs in —
  never assume, never carry one over:
  - **Self Coded** — Derik builds; Claude answers questions only when asked.
  - **Educational Assistant** — Derik builds; Claude writes markdown walkthroughs (in gitignored
    `work/lesson/`) covering decisions, reasons, trade-offs and how things work, with small
    snippets only, never the complete work.
  - **Agent** — Claude builds it.
- **Nothing is hidden.** In every mode, traps are named and explained, foreseeable mistakes are
  pointed out, and questions get straight, complete answers.

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
