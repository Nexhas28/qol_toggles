---
type: Reference
title: Field-move eligibility and Gen 2 tree interaction
description: FIELD MOVES ALL uses explicit context data or the live game learnsets while retaining HM-item, badge, and AUTO CUT gates.
tags:
  - field-moves
  - gen2
  - regression-tests
sources:
  - id: mod
    resource: file:///Users/shanemcgovern/dev/qol_toggles-main/main.lua
  - id: engine
    resource: file:///Users/shanemcgovern/dev/gen1recomp-dev/src/world/gen2/World.lua
  - id: field-moves
    resource: file:///Users/shanemcgovern/dev/gen1recomp-dev/src/world/gen2/FieldMoves.lua
  - id: tests
    resource: file:///Users/shanemcgovern/dev/qol_toggles-main/tests/field_moves_gold_test.lua
generated:
  by: process:codex
  at: "2026-10-10T20:27:13Z"
---

Observed on 2026-10-10 in the uncommitted QoL Toggles working tree based on
`17018cadc67cce4aa6d915e87588742d9bf3596e`, using engine checkout
`gen1recomp-dev` at `1f102048fa69f2645ac10e90d491e5fefd254dc8`.

Gen 2 tree interaction runs `World:interact` → `World:tryCutOW` →
`FieldMoves.tryCutOW` → `FieldMoves.partyMoveUser` → the
`fieldmove.eligibility` hook. The inspected engine's `World:fieldContext`
contains `save` and `party` but omits `data`. Its `World:partyMoveUser`, used
by Rock Smash, explicitly supplies `game.data`. Before the mod fix, that
difference prevented a Cut learner from qualifying at a tree even though
the party submenu offered Cut.[^engine][^field-moves]

The mod's eligibility hook prefers `ctx.data` and falls back to
`mod.game.data` when it is absent. Use the live mod game service: Gen 2 owns
a separate game instance. Known moves take priority over learners; learnable
HM moves still require their HM item while HM ITEM REQUIRED is enabled,
and normal badge requirements remain. AUTO CUT's walking shortcut explicitly
requires a party member that knows Cut, independent of FIELD MOVES ALL.[^mod]

`tests/field_moves_gold_test.lua` drives the real tree interaction and
blocked-step dispatch with a fixture map, replacing only the dialogue and
animation callbacks. It covers learnable/known/incompatible species,
toggle-off behavior, HM ownership, badges, explicit context data priority,
unchanged movesets, Rock Smash eligibility, and the AUTO CUT boundary.[^tests]

Validation: 33/33 targeted checks passed; the pre-fix source failed five of
those checks. The full existing suite passed 1865/1870 checks both before
and after the fix, with the same existing happiness-row and fixture
type-chart failures. Runs used the ROM-free fixture dataset and a temporary
LeafGreen version alias because this local engine predates that manifest
target. No live game or animation acceptance was performed.

For publication, the Cut-only change was reapplied on branch
`Nexhas28/fix-cut-interaction` from remote main at
`841cb5e8a60dd3b74844c9d58b3c0cf031acb826` without the unrelated local
Gen 3 commit or happiness edits. This isolated tree passed 33/33 targeted
checks with no version alias; its full suite passed 1851/1855 checks both
before and after the fix, with the same four fixture type-chart failures.

[^mod]: `main.lua`, `eligibleMon`, the `fieldmove.eligibility` hook, and the Gen 2 AUTO CUT wrapper.
[^engine]: `src/world/gen2/World.lua`, `fieldContext`, `partyMoveUser`, `tryCutOW`, and `interactBody`.
[^field-moves]: `src/world/gen2/FieldMoves.lua`, `partyMoveUser` and `tryCutOW`.
[^tests]: `tests/field_moves_gold_test.lua`, headless Gold regression run.
