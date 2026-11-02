# 005 — Clearing the backlog

*Written by Claude, 2026-11-02.*

> Take a ramp and the level change is a transition you can see, not a cut. Under it, every item
> deferred from slices 002–004 and every carried-forward note is either done or decided.

**Result:** built in Agent mode in one session, on the `slice-005` branch, with one commit per
checklist section for Derik to merge as a PR. The suite passes: 754 tests in 37 scripts, no
skipped files, no leak warning and no orphan reports. Coverage is 97.5% (1983 of 2034 probed
lines; 004 closed at 95.7%). **The by-hand outcomes haven't been walked yet.** Derik does that,
so this log was written before anyone ran the game by hand. Claude never launched the game,
because a launch reads, writes and now prunes the real save slot.

Derik set the scope at the start: only NEXT.md's "Deferred from" sections and the carry-forward
notes. The dark moved to 006, and digging your own way down to 007.

---

## What got decided

Twelve decisions, D-131 to D-142, each put to Derik one at a time just before the section that
needed it:

- **A load returns a typed `SaveGame.LoadedGame`:** the world, a `SaveSession` and a typed
  header (D-131).
- **Every swap shows the new world at its spawn's depth.** Following an actor afterwards only
  moves the depth, so a save with only NPCs is still shown (D-132).
- **Format version 1 is settled when the first build goes to someone else** (D-133).
- **Kept saves are pruned at launch to the newest of each kind** (D-134). Derik added, while it
  was being built, that **each kind gets its own count**, not one number for all three.
- **The world holds a `TuningProfile`, and every tuning number in the code moved into it:** the
  autosave interval, walk speed, hardness and the ore multiplier (D-135).
- **A loaded world runs under the profile its save names, else the default,** with a warning
  (D-136).
- **The content validator waits for a stratum below the Surface with its own stone** (D-137).
- **A fixture moves through the gatekeeper, as its own event** (D-138).
- **On a ladder facing a usable hole, interact goes down** (D-139).
- **The temporary Surface hole stays until 007** (D-140). **Refusal reasons wait for feedback**
  (D-141).
- **A level change fades through black in the view, over 0.5 s, and the move stays instant.**
  The local player's input pauses during the fade, and held keys resume after it (D-142).
  Derik chose 0.5 s over the 0.3 s Claude recommended.

**Choices made while building, not put to Derik.** He may want to look at these:

- **The tuning profile's id moved off `SaveSession` and onto the world** (written into D-135).
  It followed from "the world holds the profile", but it amends D-130 and D-131, which Derik
  had just settled. The load's header still says which profile the file named.
- **Whether a kind can be dug stays `TileKind`'s** (`TileKind.DIGGABLE`), and the profile only
  holds the numbers. A profile that leaves a kind out makes the dig refuse, loudly, rather than
  finish on the first tick.
- **`LoadedGame` and `Header` are inner classes of `SaveGame`,** like `SlotLoad`, so no new
  `class_name` files were needed for them.
- **A `View` made on its own switches depth at once** (`transitions` is false). The game turns
  fading on. Most view tests didn't have to change, but it's a switch a reader has to know
  about.
- **The followed actor is always drawn**, so it doesn't vanish while the fade still shows the
  level it left.
- **`--tuning=<id>` picks a new world's profile**, read the way `--new-game` is.
- **Pruning prints one "Pruned …" line per file** to the console, and nothing on screen.
- **The 147 comment lines over 70 characters were re-wrapped by a script,** across 43 files.
  That's most of section A's diff. It changed no code, but it's a large diff to read.

---

## What surprised

**Half the backlog was decisions, not code.** Of the twenty-odd items, eleven needed Derik, in
sixteen questions: the load result, the view with nobody to follow, format v1, pruning, the
profile (three questions), the validator, the fixture move, the ladder tie, the Surface hole,
the refusal reasons, and the transition (three questions).
The checklist put each decision just before its section, and that held up: none of the
decisions came back as a rebuild.

**Two of the three "groundwork" outcomes had a home ready.** The fixture move went into the
gatekeeper beside placing and removing, and the ladder tie was a three-line reordering of
`Ladder.target_for`. Only the profile needed a new class.

**Putting the transition in the view made trap 1 go away.** The brief's biggest trap, a world
half moved during a transition, can't happen when the move stays instant. The view-only answer
also kept the fade off NPCs and the second local player (D-045).

**Typed dictionaries are strict about where a value comes from.** Assigning `{...}` to a
`Dictionary[KEPT_KIND, int]` property through a node reference failed at run time, though the
same literal compiles when assigned to a typed local first. The test now builds a typed local.

**(Claude) A stray `cat >` waited on input for two minutes.** A leftover `cat > "$TEMP/…"` at the
front of a scan command had no input, so it hung until it was moved to the background and
stopped. Nothing was written. The rerun used a scratchpad script, with stdin from `/dev/null`.

**(Claude) The same heredoc trap as 001–004.** One inline Python edit with escaped backslashes
failed its match, as `reference-tooling-gotchas` warns. Every edit after that went through a
pairs file written with the Write tool and a small whitespace-tolerant replace script, and none
failed to match.

---

## What to do differently

1. **(Claude) Put every shell edit in a scratchpad file, from the first edit.** The pairs-file
   replace script made edits reliable, and it was only adopted after a failure. Start each
   session with it.
2. **When a decision moves a piece of data, list what else names it before building.** The
   profile id was on `SaveSession` by D-130. Moving it to the world was right, but it should
   have been part of the question put to Derik, not found while building.
3. **Ask the length and look of a feel item together with the "where".** The three transition
   questions could have been one question with previews, since the answers were tied.
4. **Leave large mechanical changes in their own commit.** The comment re-wrap would read
   better as a separate commit from the rename and the tests. It went in with section A.

---

## Open, carried forward

- **By hand, for Derik:** F3 shows a hole as `h` (outcome 3); save and relaunch until saves are
  moved aside, and see the folder pruned (5); read F3's "Last load" after F6 (6); the ramp and
  the ladder both ways with a held dig, through the fade (1); F5 during a fade, then F6 (2).
- **The load time is still unmeasured** until that walk. It was about 100 ms at the end of 003.
- **`content/tuning/default.tres` was written by hand and has no `uid`.** The editor adds one the
  first time it saves the file, so expect that small diff.
- **The two playtime timer scripts are identical** (`active_play_timer.gd`,
  `total_play_timer.gd`). They're tested now. Merging them is a tidy-up for whenever the clocks
  are next touched.
- **Generation on first descent** is still in NEXT.md's "Not placed yet".
