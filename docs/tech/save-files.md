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

---

## 1. Where the files are

One folder per slot. There's one slot for now.

```
user://saves/<slot>/
	world.save                        the save
	world.save.tmp                    being written; exists only during a write
	world.save.bak                    the save before the current one
	world.<timestamp>.save            moved aside by a new game
	world.broken.<timestamp>.save     refused at load, kept for bug reports
```

- On Windows, `user://` is `%APPDATA%\Godot\app_userdata\Deepholt\`.
- Everything for a slot stays in its folder, because a rename only replaces a file within one
  folder. ([D-109])
- Nothing deletes old moved-aside or broken saves yet.

## 2. What's in a save

One file holds the whole world: a single `Dictionary` written with `FileAccess.store_var`.
([D-109])

| Part | Holds |
|---|---|
| Header | `format_version`, `world_seed`, `tuning_profile_id` (`"none"` for now), `local_actor_id`, next fixture id, next actor id, `playtime_seconds`, `saved_at`, `game_version`. No `game_time` until there's a game clock. ([D-116]) |
| Per level | Keyed by depth (an int): the bound (depth and radius, as plain ints), the level seed, the tile layers by name (`"ground"`, `"top"`, `"ore"`), and the fixtures (kind, tile, id). ([D-112]) |
| Actors | Every actor, never just "the player": id, kind, name, depth, tile, facing. ([D-114]) |

**Rules for what goes in:**
- **Plain types only:** ints, strings, `Dictionary`, `Array`, `PackedByteArray`. Never an
  `Object` or a `Resource`. ([D-109])
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
- On a timer while playing.
- On the debug quicksave key.

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
| `world.save` is refused, `world.save.bak` loads | The bad file is renamed `world.broken.<timestamp>.save` and kept. The backup loads. An error is logged, a message stays on screen, and F3 says *loaded from backup*. |
| No `world.save`, but `world.save.bak` loads | Load the backup, loudly, as above. **Never** a new world. |
| Both refused, or no `world.save` and the `.bak` is refused | The game does not start. Nothing is renamed or written. A message names both files and why each was refused. |

`--new-game` (after `--` on the command line, or in the editor's run arguments): an existing
`world.save` is renamed `world.<timestamp>.save` before anything is generated, then a new world
starts. ([D-111])

## 6. When a save is refused

A save is refused if any of these is true: ([D-111])
- It can't be opened or read, or it's cut short.
- What comes back isn't a `Dictionary`.
- Its `format_version` is newer than this build understands.
- A tile layer that **is** present is the wrong size for its level's saved bound.

These are **not** refusals:
- **A missing key.** It loads as its default, so an older save missing a field that was added
  later is fine. ([D-116])
- **A missing tile layer.** It loads as that layer's default. ([D-112])
- **A fixture that breaks a placement rule, or a ramp or ladder check that fails.** It loads
  anyway, a warning is logged, and F3 shows the count. Nothing is dropped. ([D-113])

## 7. Reading a save back

- **Read with `get_var` and `allow_objects` off,** so a save file can never run code. ([D-109])
- **Older saves are brought up to date** one `format_version` step at a time, by a migration
  function per step. The first migration is a no-op, written before it's needed.
- **A loaded level keeps its saved bound** even if its recipe has changed since; the mismatch is
  logged. ([D-112])
- **Seeds are read back as numbers,** never re-hashed from strings.
- **Id counters are restored last,** after anything that could reset them.
- **The local player is the actor `local_actor_id` names.** If that's missing, it's the
  lowest-id player, with a warning. ([D-115])
- **An actor whose saved tile is no longer passable is moved to the world spawn,** with a
  warning. ([D-115])

## 8. Not decided yet

- The slot folder's name, the timestamp format, the autosave interval, the quicksave key.
- Whether a timer save is felt mid-play. If it is, the save splits into a quick copy on the
  main thread and compress-and-write on a worker thread. ([D-110])
- Pruning old moved-aside and broken saves.
- Levels that don't exist yet, once generation happens on first descent: a missing level key.
