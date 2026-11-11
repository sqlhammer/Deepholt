# Slice 016 — Something worth carrying

> You come up from −2 with a pack of copper and tin and a sack of coal. At the workbench by your
> bed on −1 you'd made a smelter last trip; it's down by the seam now, and this time you smelt
> there and carry ingots up instead of ore, a third of the weight. A bronze pick later, the iron
> on −3 that flint bounced off gives way, and −2's floor breaks where you want your own shaft.
> You light a lantern and the grey turns to iron for longer than a torch would last.

*Proposed by Claude, 2026-11-11. Accepted with 015 and 017 (D-210). **Agent mode** (D-210).
**Started 2026-11-11:** forks decided (D-237 to D-251). Built on `slice-016` from `main`, one
commit per section; Derik merges.*

## Where we are

- **Built (015):** −3 with iron and a `CRUSHED` region; the chute; the hand winch and its crate,
  stackable into shafts in any order; the torch in a light slot; a CRAFT tab with one hand
  recipe; the map and the depth strip; telemetry for the haul; climb times.
- **Not there:** ore has no use. Nothing is made anywhere but by hand. Tools are flint only, so
  iron is refused (D-217) and −2's floor can't be breached (flint 16 < 18 × 1.2). Coal, a
  station, an ingot, a bed and storage don't exist.
- **Why this slice:** without a use for ore, a playtest of hauling measures nothing. Pre-alpha
  criterion 4, a smelter sited near the mine unprompted, can't happen without a smelter, and
  015's outcome 2, iron worth the climb, waits on bronze (D-217).

## Mode

**Agent** (Derik, D-210, for 015 to 017).

## What should be true when you stop

By hand, unless marked:

1. **A workbench:** build one; standing at it, the CRAFT tab shows its recipes under the hand
   ones, and walking away hides them.
2. **Coal on −2,** in veins, mined like copper.
3. **A smelter turns ore into ingots** (fork 2), with coal; ingots weigh far less than the ore
   (tuning appendix §3: 3 ore → 1 ingot, 15 kg → 4 kg).
4. **Bronze tools:** a bronze pick digs faster than flint, digs iron, and breaches −2's floor.
5. **Iron worth the climb** (015's outcome 2): iron ore from −3, smelted, forged into iron tools
   at a forge, faster again.
6. **An oil lantern** in the light slot, burning fuel (fork 7), lighting farther than a torch,
   with its fuel on the HUD.
7. **A bed** (fork 8) on −1 that is your home: where you appear (fork 8 says when).
8. **A storage crate** you build, fill, and empty; it stays where you put it.
9. **Telemetry** records stations built, things made (by kind and level), so criterion 4 (where
   the smelter is) can be counted.
10. *Automated:* every recipe; the tool tiers' dig, ore and breach gates; the smelter and its
    fuel; the lantern's burn; the bed's spawn; storage and stations saved and loaded mid-use; no
    system assumes one player.

## What you're deciding

Decided 2026-11-11, one at a time, before the build
([design-decisions](../docs/design-decisions.md)):

1. **Stations:** buildables; their recipes show within 2 tiles (D-237).
2. **Smelting:** loaded and left; the first rate machine, so it works on a level nobody is on
   (D-238).
3. **Fuel:** coal on −2, one per ingot (D-239).
4. **The bootstrap:** two smelter build entries, ore or timber, the player picks (D-240, D-241).
5. **Metals:** 3 ore + 1 coal → 1 ingot; 3 copper + 1 tin ingot + 1 coal → 4 bronze, all in the
   smelter (D-242); it alloys only ingots dropped in, in load order (D-243).
6. **Tools:** pick, axe, shovel in flint (by hand, 3 stone + 1 timber), bronze (workbench) and
   iron (forge); a new game starts with 2 timber and no tools (D-244).
7. **Light:** oil pressed from cave fungus clumps in −1's caves (D-245); the lantern's 10-oil
   tank tops up from the pack (D-246); the light slot is assigned in the PACK tab (D-247).
8. **The bed:** its player's spawn point (D-248).
9. **Storage:** a 200 kg crate for 6 timber (D-249); the workbench 6 timber + 4 stone, the forge
   20 stone + 4 bronze ingots (D-250).
10. **−3's floor:** refused with a reason (D-251).

## Already settled

- **Two currencies** ([crafting §1](../docs/systems/crafting-and-progression.md)): materials
  gate what you can afford; techniques come from ruins. Ruins and blueprints are 017's, so 016's
  recipes are known from the start.
- **The tier spine** ([crafting §2](../docs/systems/crafting-and-progression.md)): T0 workbench,
  torch, hearth; T1 (−2, copper, tin, coal) smelter, bronze tools, oil lantern; T2 (−3, iron)
  forge, iron tools. Binds where each recipe sits.
- **Stations** ([crafting §3](../docs/systems/crafting-and-progression.md)): workbench for basic
  tools and parts, smelter for ore → ingots, sited near the mine; forge for iron tools. "All
  stations require a minimum tile light level for full speed."
- **The smelting insight is not tutorialised** ([crafting §3](../docs/systems/crafting-and-progression.md),
  [tuning §3](../docs/tuning-appendix.md)).
- **Numbers** ([tuning appendix](../docs/tuning-appendix.md)): tool power flint 16, bronze 30,
  iron 55 (§4); ingot 4 kg (iron 5), coal 4 kg, oil 0.8 kg, lantern 2 kg (§3); bronze pick 4
  ingots, smelter 8 stone + 4 copper ingots (§10); lantern radius 7, 1 oil per 90 s, a 10-unit
  tank (§6). Breach gate: tool power ≥ hardness × 1.2 (§4), so bronze opens −2's floor and iron
  −3's.
- **Coal is −2's** ([strata table](../docs/world-and-generation.md#2-strata)); −1 stays free of
  metal ([D-187](../docs/design-decisions.md)).
- **Iron needs bronze** ([D-217](../docs/design-decisions.md)): the ore gate is a profile number,
  `ore_tool_power_needed` (iron 20).
- **Weight-limited, no teleport** ([D-013](../docs/design-decisions.md)): a bed is not a way
  home, and storage is never a bigger pack.
- **Buildables take build slots** ([D-170](../docs/design-decisions.md)); costs are one rule,
  `Building` (D-159).
- **The CRAFT tab** ([D-222](../docs/design-decisions.md)): bench recipes go in a section under
  the hand ones; *have / need* per input; hold to keep making.
- **Light slot and keys** ([D-221](../docs/design-decisions.md), D-228): the lantern takes the
  torch's slot and its L / D-pad up.
- **Prompts name only the scheme in use** ([D-223](../docs/design-decisions.md)).
- **The winch's crate is its own** ([D-224](../docs/design-decisions.md)): storage is a fixture
  of its own, though it can reuse `Fixture.contents`.
- **Buried, never destroyed** (pre-alpha's rule): a collapse buries stations, beds and crates
  with their contents.
- **No system assumes one player** (rule [D-045](../docs/design-decisions.md)): any actor uses
  a station; each player has their own bed.
- **Countdowns run only on levels a player is on** (010's choice): the rate machine that would
  let a machine work while you're away is 017's.

## Traps

### 1. The bootstrap
The appendix's smelter needs ingots, and only a smelter makes ingots. Fork 4 has to break the
loop, or the first smelter can't be built.

### 2. A machine that stops when you leave
If smelting takes time on its own (fork 2's third option), it runs only on a level a player is
on until 017's rate machine. A smelter by the seam on −2 then stops while you haul on −1, which
is the opposite of the insight it's there to teach. Name it when choosing.

### 3. −3's floor opens onto nothing
−4 has a recipe row but no content. An iron pick breaches −3's floor by the formula; fork 10
decides what that does.

### 4. A tool stronger than every wall
Rock hardness is per kind, not per stratum: every level's rock is 6 today (the Surface's
number), so flint already digs −3's rock in 0.4 s and a bronze pick digs −3 as fast as −1. "Each tier faster" holds, but the appendix's ~0.6 s per stratum doesn't.
Changing it would retune every level's dig time; flag, don't fix, unless Derik says so.

### 5. Station reach and the cursor
"At a station" must mean the same thing to the CRAFT tab, to telemetry and to a test, and it
must be per actor: two players at two benches see their own.

### 6. New items in old saves
Ingots, coal, oil and the new tools are new item ids; a save from 015 has none, and must load.
New buildables take their first empty build slot (015's rule).

### 7. Stations that block
A station on a tile blocks walking, like a prop. One built in a one-wide tunnel seals it; the
cursor should refuse a placement that closes off the only way past? Or not: the player can dig
around. Decide in fork 1.

### 8. Test time
The suite is ~50 s. Recipe and tool tests should not each build a generated world.

## Carried into this slice

- From 015's walk: the climb bar and shafts built in any order haven't been seen in a window.
- Page Up / Page Down on Derik's laptop, for the map, unconfirmed.
