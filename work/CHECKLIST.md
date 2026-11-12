# Slice 016 checklist

Working list for [NOW.md](./NOW.md). **Agent mode** (D-210), on `slice-016`. Numbers in
brackets are the brief's outcomes.

Slice 015's checklist is in git history.

---

## A. Decided before the build

*One at a time with Derik, 2026-11-11.*

- [x] Stations and reach (D-237).
- [x] Smelting as a rate machine (D-238); coal (D-239).
- [x] The bootstrap (D-240, D-241).
- [x] Metals and alloying (D-242, D-243).
- [x] Tools by tier; no starting kit (D-244).
- [x] Fungus, oil, the lantern and the light slot (D-245 to D-247).
- [x] The bed (D-248); storage (D-249); station costs (D-250).
- [x] −3's floor (D-251).
- [x] Found in the build: a BUILD tab, ten buildables for eight slots (D-252).

## B. Built

- [x] Items, tools by tier, hand recipes, coal on −2, −3's floor refusal. [2, 4] (973451f)
- [x] Stations: workbench, forge, smelter entries; the CRAFT tab's station sections. [1, 5]
- [x] The smelter as a rate machine. [3]
- [x] Fungus clumps on −1; oil. [6]
- [x] The lantern and the assignable light slot. [6]
- [x] The bed and spawning at it. [7]
- [x] The storage crate. [8] (all of B to E in c8699b0)
- [x] Telemetry for stations and making. [9] (1a87023)

## C. Done

- [x] `scripts/test.ps1` passes (1348 tests), no "Ignoring script" warnings.
- [x] `python -m unittest scripts/test_telemetry_report.py` passes.
- [x] `python scripts/coverage.py` run: 90.2%.
- [x] Seen in a window, in part (Claude, by screenshot): stations, the lantern, the CRAFT, BUILD
  and PACK tabs, on the Surface.
- [x] By hand, in part (Derik, 2026-11-11): A to E but C3, C4, E3 to E5. F to I not walked.
- [x] Walk fixes (a9d4341): tab clicks, standing still in the inventory (D-254), refusals on the
  open inventory, the smelter's one rate (D-253), text fitting. 1349 tests, coverage 90.6%.
- [ ] Left open: the build-slot flow (Derik wants options).
