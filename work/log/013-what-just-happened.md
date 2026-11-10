# 013 — What just happened

*Written by Claude, 2026-11-10. Accepted by Derik the same day; the by-hand walk below was not
reported done.*

> You breach a floor and find yourself forty tiles back, where you came into the level. Nothing
> said why. Next time, Ctrl+F9 puts the last ten minutes in a folder: every step, every key, every
> request the world answered, and a save of the moment.

**Result:** built in Agent mode on `slice-013`, branched from `fix-world-edge` (PR #9) so it
carries D-192. 1106 tests in 58 scripts, green. Coverage 94.3%; the new files are 86–100%
covered. The suite takes about 47 s, up from 42 s, all of it the 18 new tests that each start a
game: a run with logging switched off took the same time. **No by-hand walk has been done.**

---

## What got decided

Derik's, in planning, one fork at a time:

- **The log is a static class that never writes on the game's thread** (D-193). Derik took the
  static class on the condition that logging is asynchronous and causes no lag.
- **Ctrl+F9** captures (D-194), and **left trigger + Y held 2 s** on a pad (D-195): Derik's own
  choices, over the F9 and L3 + R3 I recommended.
- **Every channel on by default** (D-196).
- **10 minutes in a capture, 30 session logs, 20 captures** (D-197).
- **Telemetry (Level 2) is for later planning:** drafted in
  [logging-and-telemetry §2](../docs/tech/logging-and-telemetry.md), its forks listed.

**Choices made while building, not put to Derik:**

- **The retention numbers are the log's constants, not the tuning profile's.** My fork's
  recommended option said they'd live in the profile; the log runs before any world exists, and
  a profile belongs to a world. D-197 says so.
- **Only answers are logged, not requests.** The world answers a dig, breach, chop or placement
  inside its own handler, which runs before the log's listener hears the request, so a request's
  line came after its answer's. Every such request ends in exactly one result or refusal, and
  those carry the actor and tile. Found in the real-window check, not by a test.
- **Y's actions wait while the left trigger is held** (D-195 records it): build mode and drop
  one. Keyboard B is skipped too while the trigger is held, which can't happen by accident.
- **Ctrl+1 to Ctrl+7 switch channels while F3 shows,** and Ctrl+digit no longer selects a
  hotbar slot anywhere: Godot matches an action's key with extra modifiers held, so Ctrl+3 would
  also have picked slot 3.
- **A session file and the engine hook start only when the game is the scene running,** so the
  ~1,100 tests never write log files. The log still records in memory during tests, and tests
  clear it.
- **The writer is woken once a frame, not per event,** and is joined at quit; a crash loses at
  most the last frame's lines.
- **The ring caps at 60,000 events** (100 a second for ten minutes). Ordinary play is nearer
  10 a second, so the cap only matters in a flood; at the cap it could hold tens of megabytes.
- **A slow frame is one over 50 ms** (three frames at 60 a second).
- **A capture's save goes through the normal save code** with the capture folder as its saves
  root; a test checks the player's own `world.save` and backup are untouched.
- **No screenshot headless:** asking for one there raises an engine error; `info.json` says
  `"screenshot": false`.

---

## What surprised

- **The jump bug didn't reproduce.** Before this slice: a breach from Derik's own save, replayed
  in the real game scene with the real key held, moved nothing. His save showed the actor at
  −1's arrival tile with no hole, written at 1:28 of play; his screenshot was at 2:06. That
  looked like a reload, but Derik confirmed no F6, no crash, and the hole was still there when
  he went back. So something moved the actor in place, and the code has no path that fits. The
  `jump` event is built for exactly this: a move of more than a tile and a half between frames
  that no `move_to` explains.
- **His session's log was gone** because Godot keeps five log files and my test runs that day
  filled them. Now 30 (D-197), and our own session logs are separate from Godot's.
- **Two heredoc-written Python edits mangled escapes** (`\n` became a literal or a real newline
  in GDScript strings), breaking `debug_overlay.gd`'s parse. Caught by the suite at once.
- **Headless Godot errors on a viewport screenshot** rather than returning an empty image.
- **Engine warnings name `variant_utility.cpp`** as their file; the script line is in the
  backtraces Godot passes to a `Logger`, which the log now uses.

---

## What to do differently

1. **(Claude) Write multi-line GDScript edits with the Edit tool, not through a shell heredoc,**
   when the text contains escapes.
2. **(Claude) Check a real run's log, not only the tests:** the out-of-order request lines and
   the `-1` generation time were plain in the first real session file and invisible to the
   tests.
3. **Play with the log on until the jump happens again,** then Ctrl+F9.

---

## By-hand walk (nothing here has been done)

From the brief: play a minute and press Ctrl+F9, and find the folder named in the notice under
`captures/` with a readable log, a save that loads, a screenshot and `info.json`; on a pad,
left trigger + Y held for 2 s does the same once, without toggling build mode; F3 lists the
channels and Ctrl+number switches one off, and its lines stop in the session log; the session
log in `logs/` grows while you play, with no stutter.
