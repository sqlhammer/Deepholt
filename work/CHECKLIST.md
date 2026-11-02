# Slice 005 checklist

Working list for [NOW.md](./NOW.md). **Agent mode for the whole slice** (Derik, 2026-11-02):
Claude builds on the `slice-005` branch, in small commits, and Derik merges it as a PR. Derik
verifies by hand. Forks are taken one at a time, just before the section that needs them, and
each lands as a `D-nnn`. Numbers in brackets are the brief's outcomes.

Ordered cheapest and least coupled first, so that the tidy-ups are off the table before the
transition, which touches the actor, the view and saving at once. The game is launched by hand
at the end of every section that changes something you can see.

Slice 004's checklist is in git history (last at `c8e5d62`).

---

## A. Tidy-ups

No forks.

- [x] `density` → `hardness` in code (`TileKind.MINABLE_DENSITY` and its readers). Names only
  ([D-081](../docs/design-decisions.md)). [13]
- [x] The dead tool-loading code goes: `_load_tool`, `TOOL_DIR`, and the `equipped` check in the
  actor validator (R-B5). [13]
- [x] Save slots are listed sorted, not in `get_directories()` order (R-P6). Test it with slots
  created out of order. [13]
- [x] "it's" → "its" in three comments, and every comment wrapped to 70 characters (R-S4).
  *Only two "it's" were wrong (three lines); 147 long comment lines across 43 files were
  re-wrapped.* [13]
- [x] F3's tile window prints a hole as its own character, not `.`. *It prints `h`, the
  character holes are authored with.* [3]
- [x] Test the playtime clocks: active and total, across a save, a load and a pause
  ([D-120](../docs/design-decisions.md)). [7] *Pausing is checked by each timer's
  `process_mode`, not by pausing the tree, which would pause GUT too.*
- [ ] By hand: F3 shows a hole distinctly. [3]

## B. Loads

- [x] The load returns a typed result instead of a dictionary with the world under `"world"`.
  Grep the run for `Ignoring` and `Parse Error` (trap 3). [8] *`SaveGame.LoadedGame`: the
  world, a `SaveSession`, a typed `Header` and the problems
  ([D-131](../docs/design-decisions.md#d-131--a-load-returns-the-world-a-session-and-a-typed-header)).*
- [x] The view can show a world with no followed actor and announces `shown_world_changed` for
  it ([D-129](../docs/design-decisions.md)). Test: a save with only NPCs loads, and the
  renderers and F3 draw the new world. [9] *Every swap now shows the new world at its spawn's
  depth first
  ([D-132](../docs/design-decisions.md#d-132--every-swap-shows-the-new-world-at-its-spawns-depth-following-an-actor-moves-only-the-depth)).*
- [ ] By hand: measure F3's "Last load" after F6 and record it for the log (003 closed at about
  100 ms). [6]

## C. Saves on disk

- [x] *Decide:* format version 1, settled now or left open. *Open until the first build goes to
  someone else
  ([D-133](../docs/design-decisions.md#d-133--save-format-version-1-is-settled-when-the-first-build-goes-to-someone-else)).*
- [x] *Decide:* the pruning rule: what's kept, how many or how long, and when it runs (trap 5).
  *The newest of each kind, each kind with its own count (three for now), at launch once the
  game has started
  ([D-134](../docs/design-decisions.md#d-134--kept-saves-are-pruned-to-a-newest-few-of-each-kind-each-kind-its-own-count-at-launch)).*
- [x] Pruning built to that rule. Test it against a folder with the live save, the backup, and
  one of each kind of moved-aside and broken save
  ([D-111](../docs/design-decisions.md#d-111--continue-by-default-a-flag-for-a-new-game-backups-and-broken-saves),
  [D-123](../docs/design-decisions.md)). [5]
- [x] [save-files.md](../docs/tech/save-files.md) caught up: the two playtime clocks (D-120),
  the required keys (D-121, D-122), the file-name timestamp (D-123), the two counters and
  `SaveSession` (D-130), and whatever C decides. [13]
- [ ] By hand: save and relaunch until saves are moved aside, and see the folder pruned. [5]

## D. The tuning profile

- [ ] *Decide:* how the profile is reached, and how much moves into it now
  ([D-037](../docs/design-decisions.md#d-037--one-tuningprofile-resource-holds-every-global-constant)).
- [ ] *Decide:* the content validator: built now and with which checks, or left for when the
  strata are built. The Surface's accepted 0.375 s needs a recorded exception (trap 6,
  [D-038](../docs/design-decisions.md), [D-081](../docs/design-decisions.md)).
- [ ] `TuningProfile` built to that decision. The autosave interval comes from it, and a save
  writes its id instead of `"none"`
  ([D-116](../docs/design-decisions.md)). [12]
- [ ] The validator, if it was decided in.

## E. Fixtures and ladders

- [ ] *Decide:* moving a fixture: a read-only `Fixture.tile`, and announced as removal plus
  placement or as its own event.
- [ ] A fixture moves only through the world's fixture gatekeeper. Test: the move is announced
  as decided, and the fixture renderer follows it. [11]
- [ ] *Decide:* which way a ladder goes when both directions apply
  ([D-106](../docs/design-decisions.md#d-106--interact-is-polled-on-the-physics-tick)).
- [ ] Test: in a built world with neighboring shafts at −2 and −3, the actor goes the way that
  was decided. [10]
- [ ] *Decide:* the temporary Surface hole at (0, 2), removed now or kept.
- [ ] If removed: by hand, `--new-game` starts without it (trap 4). [4]
- [ ] *Decide:* the refusal reasons: shown in F3 now, or left for feedback.

## F. The level-change transition

- [ ] *Decide:* how it looks and how long it takes; whether the move is delayed in the
  simulation or the view only plays the effect; what a held dig does during it; whether input
  and the level-change save wait for it
  ([D-108](../docs/design-decisions.md#d-108--a-held-dig-carries-across-a-level-change-level-changes-are-instant-for-now),
  traps 1 and 2).
- [ ] Built between the request and `Actor.move_to`, never in the `Ramp` or `Ladder` rules
  ([D-119](../docs/design-decisions.md#d-119--move_to-is-the-one-way-an-actor-is-put-somewhere-else)).
- [ ] Per actor, not global: two actors in one world each take their own transition
  (pillar [P5](../docs/game-overview.md)). Test it.
- [ ] A swap cancels a transition in progress, and nothing fires against a freed actor. Test it
  (trap 1). [2]
- [ ] By hand: the ramp and the ladder, both ways, with a held dig. [1]
- [ ] By hand: F5 during a transition, then F6. [2]

## G. Done

- [ ] `scripts/test.ps1` passes, with no "Ignoring script" warnings and no leak warning.
- [ ] `python scripts/coverage.py` run; uncovered lines looked at (004 closed at 95.7%).
- [ ] By hand: every by-hand outcome walked in one sitting, launched outside the editor at least
  once.
- [ ] Claude writes `log/005-clearing-the-backlog.md`.
- [ ] Claude re-sketches [NEXT.md](./NEXT.md).

---

### Not in this slice, worth knowing

- **Generation on first descent** (world-runtime §8) still isn't how the code works. All eight
  levels are built at launch. When that changes, a save in which some levels don't exist yet
  is a missing key, and the load needs that case. Carried in [NEXT.md](./NEXT.md).
