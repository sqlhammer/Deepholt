# Content Data Schema

Every number in the [tuning appendix](../tuning-appendix.md) needs a defined home before the
first fifty items exist. Retrofitting a schema afterwards is the classic tax.

Authoring format: **Godot 4 custom `Resource` types (`.tres`)** — type-safe, editable in the
inspector, diffable in git, and hot-reloadable. No bespoke JSON loader.

---

## 1. Identity rules

- Every content object has a **stable string `id`** in `snake_case` (`copper_ore`, `hand_winch`).
- **IDs are never reused and never renamed.** Saves reference them. Deprecate, don't rename.
- Display names live in a separate localisation table, never in the `id`.
- Every reference between resources is by `id`, resolved through a registry at load, so a broken
  reference is a **startup error**, never a silent null at runtime.

---

## 2. The TuningProfile — one resource holding every global constant

The single most valuable thing in this document.

```gdscript
class_name TuningProfile extends Resource
  # time
  real_seconds_per_game_hour  : float   # 60.0
  sunrise_hour, sunset_hour   : float   # 6.0, 18.0
  # movement & load
  walk_speed_tiles_per_sec    : float   # 5.0
  load_curve                  : Curve   # load% -> speed multiplier
  ladder_block_load_ratio     : float   # 1.5
  # carry
  base_carry_kg               : float   # 60.0
  # digging
  dig_time_coefficient        : float   # 1.0
  breach_time_multiplier      : float   # 8.0
  breach_power_margin         : float   # 1.2
  # exposure
  exposure_peak_fill_per_sec  : float   # 2.22
  exposure_drain_shade        : float   # 1.11
  exposure_drain_indoors      : float   # 6.67
  sun_altitude_curve          : Curve
  shade_multipliers           : Dictionary  # direct/dappled/occluded
  exposure_damage_bands       : Array
  # survival
  hunger_days_full_to_empty   : float   # 3.0
  meal_buff_minutes           : float   # 15.0
  marrow_ache_days            : float   # 1.0
  marrow_ache_modifiers       : Dictionary
  comfort_recovery_multipliers: Dictionary
  # power
  transmission_loss_per_depth : float   # 0.05
  # light
  dark_vision_radius          : int     # 7
  ore_identify_light_threshold: float   # 0.35
```

Three consequences worth stating:

1. **Playtest variants are one file swap.** Want to A/B a 16-minute day against a 24-minute one?
   Two `.tres` files. No code change, no rebuild.
2. **Saves record `tuning_profile_id`** ([world-runtime §7](./world-runtime-and-persistence.md)),
   so playtest data can always be traced to the numbers it was played under. Without this,
   feedback from a build you have since retuned is worthless.
3. **Nothing may hardcode a constant that belongs here.** A magic number in a script is a bug,
   even if the value is right.

---

## 3. Resource types

### TerrainType
```
  id · display_key · hardness · is_wall · is_support
  yields: [ItemStack]        # what mining it drops
  stratum_affinity: [depth]  # where it generates
  tileset_ref · dig_sfx · particle
```

### OreType
```
  id · item_id · yield_min · yield_max
  dig_time_multiplier   # 1.5
  requires_light_to_identify : bool   # true for all metals
  depth_weights : Dictionary          # depth -> spawn weight
```

### Item
```
  id · display_key · weight_kg · stack_max · trade_value
  tags: [ore, ingot, fuel, food, tool, part, decor]
  icon · world_sprite
```
`trade_value ÷ weight_kg` is what powers **sort by value density**
([ui-ux-and-controls §5](../ui-ux-and-controls.md)), so both fields are mandatory on every item.

### Tool *(extends Item)*
```
  tool_class : PICK | SHOVEL | HAMMER | LANTERN | WEAPON
  power : int              # 16 flint · 30 bronze · 55 iron · 95 steel · 160 ancestral
  tier_name
```

### Structure
```
  id · display_key · footprint (w,h) · build_cost: [ItemStack] · build_seconds
  support_bonus : int          # 0 timber · 1 stone · 3 iron-braced · 5 arch
  is_support : bool
  power_draw_sp · power_supply_sp
  light_radius · light_colour
  comfort_value · comfort_category      # for room scoring; variety is capped by category
  requires_light_level : float          # stations
  throughput : { kg_per_cycle, cycle_seconds }   # logistics only
  flags: [reinforced_floor, blocks_movement, needs_aligned_shaft, needs_landing, surface_only]
```

### Recipe
```
  id · station_id · inputs: [ItemStack] · outputs: [ItemStack]
  craft_seconds · technique_required : id?
```
The smelting ratio lives here as data, not code: `3 copper_ore -> 1 copper_ingot`
([D-031](../design-decisions.md)).

### Technique *(recovered blueprint)*
```
  id · display_key · unlocks: [recipe_id | structure_id]
  found_in: [poi_id] · min_depth
  document_text_key            # the story text and the unlock are the same pickup
```

### Meal *(extends Item)*
```
  buff_type : CARRY | DIG | EXPOSURE | REGEN | LANTERN
  magnitude · duration_minutes
```
Exactly one meal buff may be active ([survival-and-farming §2](../systems/survival-and-farming.md)).

### CreatureType
```
  id · hp · move_speed · damage · attack_interval
  behaviour : NEUTRAL | TERRITORIAL | AMBUSH | PACK | BURROWER
  avoids_light : bool · light_threshold
  depth_weights · region_affinity
```
**Validator invariant:** `move_speed ≤ TuningProfile.walk_speed_tiles_per_sec` for every
non-guardian creature ([D-032](../design-decisions.md)).

### Stratum
```
  depth · display_name · radius_tiles
  rock_hardness · support_radius_R
  ore_table · fauna_table · region_class_weights · poi_pool
  ambient_palette_ref
```

### RegionArchetype / POIPrefab
```
  RegionArchetype: id · carve_params · access_class_weights · decoration_set
                   # access_class_weights covers OPEN/UNSTABLE/SEALED/CRUSHED only.
                   # WATER_SOURCE is a generation-time marker; there is no FLOODED class.
  POIPrefab:       id · size · variants · rotation_allowed · guaranteed_at_depth?
                   contained_techniques · loot_table
```

---

## 4. Where numbers live — a map

| Tuning appendix § | Lives in |
|---|---|
| §1 Time | `TuningProfile` |
| §2 Movement & load | `TuningProfile` (`load_curve` as a `Curve` asset) |
| §2 Vertical transit | `Structure.throughput`, `Structure.build_cost` |
| §3 Weights | `Item.weight_kg` |
| §3 Smelting ratio | `Recipe` |
| §4 Digging | `TerrainType.hardness`, `Tool.power`, `TuningProfile` coefficients |
| §5 Exposure | `TuningProfile` |
| §6 Light | `TuningProfile.dark_vision_radius`, `Structure.light_radius` |
| §7 Power | `Structure.power_draw_sp` / `power_supply_sp`, `TuningProfile` loss |
| §8 Survival | `TuningProfile`, `Meal` |
| §9 World scale | `Stratum` |

**If a number in the appendix has no home in this table, the schema is incomplete.**

---

## 5. The content validator

An editor tool, run in CI, that fails the build on:

- Any unresolved `id` reference.
- Any `Item` missing `weight_kg` or `trade_value`.
- Any creature violating the speed invariant (§3).
- **The digging invariant:** for every stratum, the tier-appropriate tool must yield a dig time
  within 0.5–0.7 s, and the breach ladder must resolve to exactly one tool tier per depth
  ([tuning-appendix §4](../tuning-appendix.md)). This is the check that keeps the derived
  progression from silently drifting as values are tweaked.
- Any stratum whose `support_radius_R` is not monotonically decreasing with depth.
- **The watertight check:** for every generated level, each water body's open-space component
  must not reach the descent point or the arrival area
  ([world-and-generation §3](../world-and-generation.md)). This is the principal new generation
  cost of [D-039](../design-decisions.md) and must run on every seed, not just authored ones.
- Any recipe reachable before the technique that unlocks it can be found.

The digging invariant is the important one. The breach ladder is trustworthy *because* it is
derived; a validator is what keeps it derived.

---

## 6. Authoring workflow

1. Content lives in `res://content/<type>/<id>.tres`.
2. A registry autoload scans and indexes at startup; missing or duplicate ids are fatal.
3. Bulk numeric tuning is done by editing `.tres` in the inspector — **not** by adding a
   spreadsheet import path. One source of truth.
4. Tuning profiles live in `res://content/tuning/` with a default and any playtest variants.
