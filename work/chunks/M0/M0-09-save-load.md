# M0-09 — Save format, migration, round-trip

**Depends on:** M0-03, M0-06, M0-07, M0-08 · **Feeds:** M0-10
**Acceptance checks:** §10.3, §10.5, §10.6

## Goal

A modified world round-trips exactly; the format is versioned with a working migration path from
day one; and a rate machine's accrual survives the trip.

The migration path is not premature engineering. A save format with no migration gets wiped
repeatedly during pre-alpha, which destroys long-run playtest data — and long-run data is exactly
what success criterion 5 needs ([pre-alpha-scope §6](../../../docs/pre-alpha-scope.md)).

## In scope

- The format from [§7](../../../docs/tech/world-runtime-and-persistence.md), in this shape:
  ```
  header   : format_version · world_seed · game_time · playtime · actor_count
  per depth: level_seed · region table · POI instances · tile arrays (compressed)
  entities : actors · structures · machines (with last_evaluated_tick) · ground items
  meta     : discovered techniques · quest/objective flags · tuning_profile_id
  ```
  Region tables and POI lists are empty in M0 (procgen is M3); the fields exist and round-trip.
- **Full tile arrays, compressed. Not seed-plus-deltas.** A delta system saves ~2 MB and buys a
  permanent class of "my base disappeared after an update" bugs.
- `format_version` as an integer, with a migration function table and **one no-op migration**
  (`v1 → v2`) written now, before it is needed, and exercised by a test.
- `tuning_profile_id` recorded, so a playtest save can be traced to the numbers it was played
  under ([content-schema §4](../../../docs/tech/content-schema.md)).
- **Support and light are not saved.** On load, `recompute_all_from_scratch()` (M0-08) runs before
  gameplay resumes.
- Machines serialise `last_evaluated_tick`; `game_time` restores from the header; accrual continues
  from the stamp, not from load time.
- Actors serialise with `actor_id`, components, and depth — as a **set**, with `actor_count` in the
  header. No slot reserved for "the player".
- Save-file size reported in the debug overlay after each save.

## Out of scope

Autosave policy, multiple save slots, cloud saves, a save UI. Debug hotkeys are correct for M0.

## Automated checks

| Check | Expectation |
|---|---|
| modify 1,000 tiles across 3 depths, save, load | every field byte-identical, all 8 depths |
| save a `v1` file, load it | migration `v1 → v2` runs; content unchanged; version stamped 2 |
| poison derived fields, save, load | loaded derived fields are correct — proving they were recomputed, not read |
| grep the serialiser for `support_state` / `light_level` | no matches |
| machine at rate 2/tick: save, advance 100 ticks of wall time, load, query | output reflects the *saved* tick, not the load time |
| machine accrues 50 ticks, save, load, accrue 50 more | total exactly 100 |
| two actors saved, one without `Inventory` | both restored with correct component sets and depths |
| save `sparse` world | compressed file well under 1 MB |

## Human verification

1. Load `flat`, dig out a recognisable shape (your initials) on −2 with the tile inspector, place
   a debug machine on −3, and spawn two actors on different depths.
2. Save. → The overlay reports a file size under 1 MB.
3. Quit the game entirely. Relaunch. Load. → Your initials are there, on −2, in the same place.
   Both actors are back on their own depths. The machine is on −3.
4. Check the machine's output. → It matches what it was at save; it did not reset and did not
   accrue for the time the game was closed.
5. Let it run 30 seconds, save, load again, check output. → Continues from where it was.
6. Hand-edit the `format_version` in a copy of the save down to 1 and load it. → It loads, the
   migration is logged, and nothing is lost.
7. Corrupt a byte in the middle of a save file and load it. → A clear error, not a crash, and the
   previously loaded world is not damaged.

## Exit checklist

- [ ] Round-trips a modified world across all eight depths
- [ ] `format_version` + one exercised no-op migration
- [ ] `tuning_profile_id` recorded
- [ ] Derived fields absent from the file and recomputed on load
- [ ] Rate machine accrual exact across save/load
- [ ] Actors saved as a set; no player slot
- [ ] Corrupt file fails cleanly

## Discovered work

-
