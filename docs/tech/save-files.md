# Save Files

What the save system must do, rule by rule. The reasons live in the decisions linked from each
section; this page is the *what*. The save format's place in the wider world model is
[world-runtime §7](./world-runtime-and-persistence.md#7-save-format).

[D-109]: ../design-decisions.md#d-109--a-save-is-one-store_var-file-per-slot-owned-by-a-static-class
[D-110]: ../design-decisions.md#d-110--when-a-save-happens-quit-level-change-a-timer-and-a-key
[D-111]: ../design-decisions.md#d-111--continue-by-default-a-flag-for-a-new-game-backups-and-broken-saves
[D-112]: ../design-decisions.md#d-112--tile-layers-are-saved-by-name-a-byte-layer-per-fact-a-saved-bound-wins
[D-113]: ../design-decisions.md#d-113--loaded-fixtures-go-straight-in-then-are-checked-and-reported-never-dropped
[D-114]: ../design-decisions.md#d-114--actors-get-int-ids-from-a-world-counter-what-an-actor-saves
[D-115]: ../design-decisions.md#d-115--the-save-names-the-local-actor-an-actor-on-an-impassable-tile-goes-to-the-spawn
[D-116]: ../design-decisions.md#d-116--the-save-header-and-a-placeholder-tuning-profile-id
[D-120]: ../design-decisions.md#d-120--playtime-is-two-clocks-active-and-total
[D-121]: ../design-decisions.md#d-121--three-header-keys-are-required-the-rest-load-as-their-defaults
[D-122]: ../design-decisions.md#d-122--the-save-time-is-a-utc-unix-int-and-the-writers-offset-both-required
[D-123]: ../design-decisions.md#d-123--moved-aside-saves-are-named-with-a-utc-time-in-iso-basic-format
[D-127]: ../design-decisions.md#d-127--the-generator-and-the-save-each-build-a-whole-world-outside-the-tree
[D-129]: ../design-decisions.md#d-129--a-swap-happens-at-the-end-of-the-frame-and-the-view-re-points-everything-that-draws
[D-130]: ../design-decisions.md#d-130--a-save-takes-the-world-and-a-typed-session-the-worlds-counters-go-in-the-header
[D-131]: ../design-decisions.md#d-131--a-load-returns-the-world-a-session-and-a-typed-header
[D-132]: ../design-decisions.md#d-132--every-swap-shows-the-new-world-at-its-spawns-depth-following-an-actor-moves-only-the-depth
[D-133]: ../design-decisions.md#d-133--save-format-version-1-is-settled-when-the-first-build-goes-to-someone-else
[D-134]: ../design-decisions.md#d-134--kept-saves-are-pruned-to-a-newest-few-of-each-kind-each-kind-its-own-count-at-launch

---

## 1. Where the files are

One folder per slot, named `slot-` and three digits. There's one slot for now, `slot-001`.
Slots are listed in name order, and launch continues the first.

```
user://saves/slot-001/
	world.save                         the save
	world.save.tmp                     being written; exists only during a write
	world.save.bak                     the save before the current one
	world.<time>.save                  moved aside by a new game
	world.backup.<time>.save           its backup, moved aside with it
	world.broken.<time>.save           refused at load, kept for bug reports
```

- `<time>` is the UTC time in ISO basic format, `YYYYMMDDTHHMMSSZ`. A second file moved aside
  in the same second gets `-2`, `-3` and so on before `.save`, and never replaces another
  file. ([D-123])
- On Windows, `user://` is `%APPDATA%\Godot\app_userdata\Deepholt\`.
- Everything for a slot stays in its folder, because a rename only replaces a file within one
  folder. ([D-109])
- Moved-aside and broken saves are pruned at launch (§6).

## 2. What's in a save

One file holds the whole world: a single `Dictionary` written with `FileAccess.store_var`.
([D-109])

| Part | Holds |
|---|---|
| Header | `format_version`, `world_seed`, `game_version`, `saved_at` (UTC Unix seconds, an int) and `saved_at_utc_offset` (the writer's offset in minutes, an int); `tuning_profile_id` (`"none"` until the tuning profile exists), `local_actor_id`, `next_fixture_id`, `next_actor_id`, and `stats`. No `game_time` until there's a game clock. ([D-116], [D-122], [D-130]) |
| `stats` | `active_play_time` (seconds played unpaused) and `total_play_time` (seconds the game was open), as floats. A zero isn't written. ([D-120]) |
| Per level | Keyed by depth (an int): the bound (depth and radius, as plain ints), the level seed, the tile layers by name (`"ground"`, `"top"`, `"ore"`), and the fixtures (kind, tile, id). ([D-112]) |
| Actors | Every actor, never just "the player", keyed by id: kind, name, depth, tile, facing. ([D-114]) |

**Who supplies what:** `SaveGame.save_game(slot, world, session, saves_root)`. The `World`
gives its seed, levels, actors and both id counters. A `SaveSession` gives what isn't the
world's: the local actor's id, the tuning profile id and the two clocks. A new header field
that isn't the world's becomes a field on `SaveSession`, and no call site changes. ([D-130])

**Rules for what goes in:**
- **Plain types only:** ints, floats, strings, `Dictionary`, `Array`, `PackedByteArray`. Never
  an `Object` or a `Resource`. ([D-109])
- **Each tile layer is compressed on its own with ZSTD,** so the header can be read without
  decompressing anything. ([D-109])
- **Kind ids are numbers, and never change meaning.**
- **Derived data is never saved.** Renderer textures, the view, and later support and light,
  are rebuilt on load.

**Not saved:** capabilities (the game grants them by actor kind), a dig in progress, the
equipped tool (a placeholder until inventory exists). ([D-114])

## 3. When a save is written

([D-110])

- When the window is closed (the game holds the close, saves, then quits).
- When the player quits with `Esc`.
- After every level change, once the actor has arrived.
- On a timer while playing, every 300 s for now.
- On the debug quicksave key, `F5`. `F6` loads the slot (§7).

The editor's stop button kills the game without a save. Test quitting outside the editor.

## 4. How a save is written

Always in this order, never written in place over `world.save`: ([D-111])

1. Write the whole save to `world.save.tmp`, and close the file.
2. Rename the current `world.save` to `world.save.bak`, replacing the old backup.
3. Rename `world.save.tmp` to `world.save`.

A crash at any step leaves at least one complete save on disk. On Windows a rename over an
existing file is a delete and then a rename, so between steps 2 and 3 there can be a `.bak` and
a `.tmp` but no `world.save`. Loading handles that case (§5).

## 5. What happens at launch

Normal launch (no `--new-game`): ([D-111])

| In the slot folder | What happens |
|---|---|
| Nothing | New world. |
| `world.save`, and it loads | Continue it. F3 says *loaded*. |
| `world.save` is refused, `world.save.bak` loads | The bad file is renamed `world.broken.<time>.save` and kept. The backup loads. An error is logged, a message stays on screen, and F3 says *loaded from backup*. |
| No `world.save`, but `world.save.bak` loads | Load the backup, loudly, as above. **Never** a new world. |
| Both refused, or no `world.save` and the `.bak` is refused | The game does not start, and saving is refused. Nothing is renamed, written or pruned. A message names both files and why each was refused. |

`--new-game` (after `--` on the command line, or in the editor's run arguments): an existing
`world.save` is renamed `world.<time>.save`, and `world.save.bak` `world.backup.<time>.save`,
before anything is generated. Then a new world starts. If either can't be moved, the game
doesn't start. ([D-111], [D-123])

## 6. Pruning

([D-134])

- **Once per launch, once the game has started:** after the slot loaded, or after a new game
  moved the old world aside. Never during a load (`F6` doesn't prune), and never when the game
  refused to start.
- **Three kinds, each with its own count:** old worlds (`world.<time>.save`), old backups
  (`world.backup.<time>.save`) and broken saves (`world.broken.<time>.save`). Each keeps its
  newest files, by the time in the name and then the `-n`. Three of each, for now
  (`SaveGame.KEEP_PER_KIND`). A kind with no count is never pruned.
- **Only names that match one of those three patterns exactly are deleted.** `world.save`,
  `world.save.bak`, `world.save.tmp` and anything else in the folder are never touched.

## 7. When a save is refused

A save is refused if any of these is true: ([D-111], [D-121])
- It can't be opened or read, or it's cut short.
- What comes back isn't a `Dictionary`, or it has no `format_version`.
- Its `format_version` is newer than this build understands, or there's no migration from it.
- A required header key is missing or of the wrong type: `world_seed` (int), `game_version`
  (String), `saved_at` (int), `saved_at_utc_offset` (int). ([D-121], [D-122])
- It has no levels, or no actors.
- Any level in it won't load: all or nothing, since a world missing a level isn't the world that
  was saved. That includes a tile layer that **is** present but is the wrong size for its
  level's saved bound, and a saved radius over 1024 (`SaveGame.MAX_SAVED_RADIUS`). ([D-112])
- No actor in it can be placed.

Every check that can be made on the file runs before any node is built. A refusal found while
building frees the one world built so far, so nothing is left orphaned. ([D-127])

These are **not** refusals:
- **A missing or wrongly typed optional key.** It loads as its default: `tuning_profile_id` as
  `"none"`, the local actor and each clock as -1 (not saved), and each counter from the loaded
  ids. ([D-121], [D-131])
- **A missing tile layer.** It loads as that layer's default. ([D-112])
- **A fixture that breaks a placement rule, or a ramp or ladder check that fails.** It loads
  anyway, a warning is logged, and F3 shows the count. Nothing is dropped. ([D-113])
  The one exception is a second fixture with an id already on its level: a level can't hold
  two fixtures with one id, so the second is skipped, with a warning.

`F6` mid-session follows the same table as launch, except that with both files refused the
running world is left exactly as it was, and so is saving.

## 8. Reading a save back

- **Read with `get_var` and `allow_objects` off,** so a save file can never run code. ([D-109])
- **Older saves are brought up to date** one `format_version` step at a time, by a migration
  function per step. The first migration is a no-op, written before it's needed. **Version 1
  isn't settled yet:** until the first build goes to someone other than Derik, a format change
  edits v1 in place, with no bump and no migration. ([D-133])
- **A load builds a whole `World` outside the tree** and returns a `SaveGame.LoadedGame`: the
  world, a `SaveSession`, a typed header (the version the file was *written* in, which F3
  shows), and the load's problems. A load hands back what a save took in. ([D-127], [D-131])
- **The swap happens whole.** The old world is freed with everything in it, the new one is
  added, and the view is told the new world at its spawn's depth. After that, a player is given
  control. `F6` swaps at the end of the frame, since it arrives from inside input. ([D-129],
  [D-132])
- **A loaded level is built from its saved bound** even if its recipe has changed since. A
  level the save holds only in part is generated, after every saved fixture id has been
  claimed. ([D-112])
- **Seeds are read back as numbers,** never re-hashed from strings.
- **Id counters are restored last,** after anything that could draw an id, then moved past every
  id the load brought back. A save with no counters gets them from the ids alone. ([D-130])
- **Each clock is seeded from the save, and counts on from there.** A clock the save left out
  keeps its count. ([D-120])
- **The local player is the actor `local_actor_id` names.** If that's missing, it's the
  lowest-id player, with a warning. A save with no player loads, and nobody is given control.
  ([D-115], [D-132])
- **An actor whose saved tile is no longer passable is moved to the world spawn,** with a
  warning, before the game listens to it, so the move doesn't save a world half swapped in.
  ([D-115])

## 9. Not decided yet

- The autosave interval (a placeholder 300 s) and the quicksave key.
- Whether a timer save is felt mid-play. If it is, the save splits into a quick copy on the
  main thread and compress-and-write on a worker thread. ([D-110])
- Levels that don't exist yet, once generation happens on first descent: a missing level key.
