# Core Loops

---

## 1. Moment to moment (seconds)

**Mine → reveal → decide.**

You swing at rock. The wall opens. What's behind it is one of: more rock, an ore vein you
need light to identify, a natural void that just saved you an hour of digging, a hazard, or
something built by someone else a very long time ago.

The tight loop is *excavation with information payoff*. Every tile removed is a tiny reveal.
Keep the dig verb fast, chunky, and satisfying — screenshake, debris, a good sound. If mining
one tile isn't pleasurable in isolation, nothing above it will save the game.

---

## 2. The expedition loop (5–20 minutes)

The primary unit of play.

```
      PREPARE                 TRAVEL                WORK                 RETURN
  food, fuel, tools   →   down the shaft,     →   mine, fight,     →   haul it up,
  weight budget           or out at dawn          shore, salvage        weight-limited
      ↑                                                                      │
      └──────────────────────  DEPOSIT & PROCESS  ←─────────────────────────┘
                          smelt, cook, craft, expand
```

The tension is always **weight versus greed**. You went down for iron and found silver; now
something has to be left behind, or you make a second trip, or — the intended lesson — you
go home and build a chute.

**Surface expeditions are the same loop with the exposure meter substituted for weight** as
the limiting pressure, and a route rather than a shaft as the travel problem. Same shape,
different medium. Players learn one loop and get two.

---

## 3. The session loop (30–90 minutes)

```
  Arrive with a goal ("drain the west sump")
        → 2–4 expeditions gathering what it needs
        → one construction project completed
        → the warren is measurably better than when you sat down
        → the improvement reveals the next goal
```

**Hard requirement: every session must end with something built.** Not a fuller chest — a
*structure*. A session that produced only inventory is a session that felt like nothing
happened. Balance costs so a focused hour yields at least one completed piece of
infrastructure.

---

## 4. The progression loop (hours)

```
   Descend  →  new materials & ancestral techniques
      ↑                        ↓
   supply line   ←   better tools, columns, machines
   reaches deeper          ↓
      └──── you can now hold the level you could only visit ────┘
```

Note what is *not* in that loop: a stat wall. You descend because you can **sustain** it, not
because a number cleared a threshold. Tool tier gates breaching a floor and nothing else.

### The motive stack — why go deeper
A player should always have at least two of these live at once:

1. **Material need.** The thing I want to build needs something from below.
2. **Space.** The cone means I am genuinely running out of room up here.
3. **Curiosity.** There is an authored ruin down there I have seen the edge of.
4. **The gated region.** I left half of −4 behind because I had no pumps. It is still there.
5. **The people.** Somewhere below, there are molepeople who have been cut off for
   generations, and I am the only one doing anything about it.

---

## 5. The meta loop (deferred — post-first-playable)

```
   Reconnect / recruit  →  assign molepeople to stations
          ↑                          ↓
   deeper reach    ←    automation removes upkeep tedium
```

Explicitly out of scope for pre-alpha. Two constraints on it are already fixed and must be
honoured when it is designed:

- Worker crafting is **immune to Marrow-Ache**, so a good workshop softens death ([D-007](./design-decisions.md)).
- Workers automate **upkeep and tedium**, never excavation-as-authorship. The player always
  holds the shovel. A moleperson that digs your base for you deletes the core fantasy.

---

## 6. Pressure map

Every loop needs opposing forces. Ours, and where each one bites:

| Pressure | Bites during | Answered by |
|---|---|---|
| **Weight** | Return leg | Chutes, hoists, lifts |
| **Sun exposure** | Surface travel | Shade routing, awnings, gear, night |
| **Lantern fuel** | Deep work | Fixed lighting; eventually retired entirely |
| **Hunger** | Everything, gently | Fungus farms, surface grain, cooking |
| **Structure** | Excavation | Columns, better materials, the overlay |
| **Region gates** | Arrival on a new level | Pumps, shoring, sealing tech |
| **Marrow-Ache** | After death | Time, rest, and later, workers |

Three of these (fuel, region gates, Marrow-Ache) are designed to be **substantially solved**
by late game. A survival game where nothing is ever solved is a treadmill; the feeling we want
is *this mountain used to be hard on me and now it isn't.*
