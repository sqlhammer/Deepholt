# Deepholt — Design Documentation

Pre-production design docs. No code lives here; the Godot project is in [`/game`](../game/).

**Start with [game-overview.md](./game-overview.md).** It holds the pitch, the five pillars,
and an index of every other document.

If you are here to build something, read [pre-alpha-scope.md](./pre-alpha-scope.md) — it is
the only document that describes what is actually being made right now, and it is deliberately
much smaller than the rest of this folder.

If you are wondering *why* something is the way it is, check
[design-decisions.md](./design-decisions.md) before assuming it was an accident.

## Conventions

- Every system document ends with a **pre-alpha subset** — a checklist of the minimum slice of
  that system, and an explicit list of what is cut.
- Decisions are numbered `D-nnn`, append-only. Reversals get a new entry rather than an edit.
- Anything marked **Open** or **Deferred** is a real invitation, not an oversight.
