# Forks & Destruction — Implementation Plan

**Status: NOT STARTED.** Nothing of this exists in code yet.

## Where the design lives

`.bible/milestones.md`, the `FOrks!!!` section (lines ~43-53). That file holds the
author's original intent — read it first. This document is the *implementation* half:
what to touch, in what order, and which design questions are still open.

The reason this felt lost: the design notes are still **uncommitted** in
`.bible/milestones.md`, and no code was ever written, so nothing in the repository
records that the feature is planned. Hence this file.

## Verification that nothing was built

- `grep -n "lane_id|destroy_tower|condemn|second_path|branch_path"` over `scripts/`
  — **0 hits** (the only `lane` matches are mesh lane-markings and ground-plane math).
- No second `path_hexes` array, no per-lane spawn, no fork budget spend, no
  destruction path, no "company drop" alert text or SFX cue.
- The only mention in code is `AGENTS.md` §7 and `WaveRoster`'s comment that
  `unspent_budget` "is reserved for future fork/objective budgets".

## What was shipped instead (and why forks waited)

This session's agreed order put the path-growth payoffs first. Delivered, in order:
trimmed growth geometry → real director path signals → corrected director budget
spend → **Objectives** (claimable sites on new ground, region auras) → **Rites and
the Reckoning** → the **Rite branch on all 10 towers**. Forks were explicitly
deferred, and the session then filled with the tower panel and UI work. Forks remain
the next planned feature.

## What already exists that forks should build on

Do not re-invent these — they were built with forks in mind:

| Existing thing | Why forks need it |
|---|---|
| `PathGenerator` preview→commit lifecycle (`generate_preview()` at `PREVIEW_LEAD_WAVES`, reserve `ghost_path_hexes`, `commit_extension()` in `POST_BOSS`) | A fork is an *alternative outcome of the same lifecycle*, not a new system |
| `validate_path` hard constraints H1-H5 | A fork is a SECOND chain from the same base; "single non-branching chain" must become per-lane |
| `WaveRoster.unspent_budget` (never silently discarded) | The reserved seed for a fork's own budget |
| `ObjectiveSystem` site settling after `commit_extension()` | New ground is new ground: fork lanes must settle sites too |
| `TelegraphLayer.show_banner()`, `GameState.camera_focus_requested`, `AudioCueSystem` | The "company drop" alert (banner + SFX + camera move) |
| Overlay convention: ring + ground fill + per-KIND billboarded icon, decals at y 0.016-0.078 | The fork candidate preview should reuse it (ghost path ribbon is `ghost_path_color` at y 0.08) |

## The lane refactor — the hard part

Today every system assumes ONE path: `path_hexes[0]` is the base,
`path_hexes[size-1]` is the spawn. Six chokepoints derive everything from that:

1. **`CombatUnit`** — add `lane_id`; `get_unit_hex()` and path progress read the
   unit's own lane.
2. **`HexSpatialIndex.rebuild()`** — buckets units by hex for tower targeting;
   confirm it stays lane-agnostic (keyed by hex) or make it lane-aware.
3. **`EnemyMoverView` / `EnemyVisualPool`** — visual interpolation walks the path
   per unit; each unit must interpolate along ITS lane.
4. **`HexMath.path_position_to_world()`** — becomes `(lane, progress)`.
5. **`PathView.refresh_path()`** — N ribbons, N spawn markers, one shared base.
6. **`PathGenerator`** — preview/commit, validation, overlap computation,
   `is_hex_on_path` / reservation, and leak handling all key off one array.

## Suggested order (each phase should keep the suite green)

- **Phase 1 - lane scaffolding, no gameplay change.** `lane_id` defaults to 0;
  `PathGenerator.lanes: Array[Array[Vector2i]]` with lane 0 = today's path. The six
  chokepoints take a lane. Suite must pass unchanged: that is the whole point of
  this phase.
- **Phase 2 - fork preview as a choice.** Director picks 2-3 candidates; the preview
  renders all of them as distinct ghost ribbons (per-candidate colour + billboarded
  icon + label); the player picks one; the pick commits in `POST_BOSS` exactly like
  an extension today.
- **Phase 3 - fork budget.** Seed the fork lane from `unspent_budget` plus a
  readiness-scaled base, so a new lane can actually be attacked rather than being a
  decorative road. Forks get their own director budget so a fork does not starve the
  main lane.
- **Phase 4 - destruction / condemnation.** Towers on the chosen route are
  destroyed. Give a **2-wave telegraph** during which affected towers can be sold at
  **full value** (not the usual 70%), so the loss is a decision the player had time
  to make. Killing along the new lane pays a bounty toward what was lost.
- **Phase 5 - the alert.** "COMPANY DROP INBOUND" modal/banner + SFX + camera focus.
  After the first Coalition boss, a fork may be a **different faction**.
- **Phase 6 - late game.** Forks REPLACE extensions past a threshold, so growth
  becomes "which fork" rather than "another stretch".

## Open questions (author's own notes) and proposed defaults

1. **Destroy strongholds, or only lone towers?** The notes say lone towers
   "definitely" and strongholds are undecided.
   *Proposed:* destruction is **deterministic — only what the route actually
   crosses** — which is readable on the preview and matches the agreed "destroy
   anything in route". The 2-wave full-value condemnation window is what keeps it
   fair rather than the exemption list.
2. **Player choice or director choice?**
   *Proposed:* **director offers 2-3 candidates, the player picks one** (already the
   agreed decision). It is the only version that cannot hand the player an
   unguardable fork, while the choice itself stays meaningful.
3. **Can the player decline to fork?**
   *Proposed:* **no skip** — growth always happens, you choose *where*. A free skip
   would make forks costless, and the whole point is that new ground is a
   commitment.
4. **Fork danger vs "not game ending":** the notes warn against forking "in a place
   with no towers, and the player has no resources to guard it".
   *Proposed:* candidate generation rejects routes whose neighbourhood has no
   player coverage at all (`CoverageTracker` already measures per-tag DPS by area),
   so every offer is at least guardable.

## Also lost in the same milestones.md edit — both DONE

The uncommitted edit DELETED three earlier notes. Two described real work that was
then silently dropped. **Both are now implemented** (recorded here so the history is
clear rather than because anything is outstanding):

- **"sell tower needs confirm"** — DONE. `TowerPanel` now arms on the first press and
  only sells on a confirming second press, keyed by `tower_id` so changing selection
  disarms (`_sell_armed_for`). Confirming the sale of a Rite tower says explicitly that
  the Rite is NOT refunded. Pinned by
  `test_build_menu_ui.gd::test_07_selling_requires_a_confirming_second_press_and_warns_about_rites`.
- **"not show rites as upgrade options until the player has received their first one"** —
  DONE. `TowerSystem.rites_drawn_total` records every Rite ever drawn and
  `has_ever_drawn_rite()` (holds one, or has drawn one) gates the Rite T3 card, so a
  player with 0 Rites and no Reservoir is no longer shown a dead button or spoiled on the
  branch. Spending the Rite does not re-hide the branch. Pinned by
  `test_build_menu_ui.gd::test_06_panel_hides_the_rite_branch_until_the_first_rite_is_received`.
- "keep an eye as rites as a trap" — a standing design watch-item. The Reckoning's
  debt reset (three rules, AGENTS.md §5) already addresses the worst version of it.

## Verified-input note for future live checks

In this project's `run_scene` harness, **synthesized raw mouse clicks do not activate
Godot Buttons** — a click at a button's exact centre lands and does nothing (verified
repeatedly on the tower panel's T2 upgrade button). Semantic `target` clicks (by a
control's exact visible text or node path) DO work. So UI behaviour must be driven either
by `target` clicks or by calling the handler directly from a test, and a "click did
nothing" result should never be read as an application bug.