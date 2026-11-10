# 014a — Telemetry without names

*Written by Claude, 2026-11-10. A mini-slice after 014, in Agent mode, on
`fix-telemetry-identity` (from `slice-014`).*

**Result:** 1123 tests, green, no warnings; the report script's four tests pass. An exported
playtest build, killed and relaunched, wrote the new shape: errors by type and by place, no text.
That run raised no warnings, so the case with a name in it is covered by the tests, not seen in
a build.

## What got decided

**D-209** (Derik): errors are recorded by where they were raised, not what they said. Telemetry's
summary keeps a count per type and per place (`warning at game.gd:612 _local_player`); outside
a debug build the debug log's error events keep the place but not the message. Derik chose this
over scrubbing names from the text and over counts alone.

## How it was found

Writing 014's acceptance walkthrough, I checked what could identify a tester and found the
summary's `errors.first`, the first ten warnings' text, which 014 put there under D-202. Some
warnings name the actor ("… DefaultName (1) is local instead."). Planning the fix found the same
text in a second place: the debug log's error events, which run in playtest builds and go into
the crash file a tester sends. Both are fixed.

## Choices made while building, not put to Derik

- **A debug build still keeps warning text** in its own session log and captures: those stay on
  Derik's machine. `Log.keep_error_text` follows the build; tests switch it.
- **The report lists the three places raised most,** under each session's engine counts.
- **A place is the script line that raised it,** as 013 already found it; for an engine error
  with no script on the stack, the engine's source file and line.

## What surprised

- **Nothing in 014's tests could have caught this:** the identity test searched for the actor's
  name in a session that raised no warnings. Its replacement raises one that names the player
  and checks the summary and the rolling crash file.

## By-hand

In [uat-014](./../lesson/uat-014-how-it-plays-for-other-people.md) (untracked), case B4 now says
what to look for: `errors.sites` in the summary, places only, no messages.
