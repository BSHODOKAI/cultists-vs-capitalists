---
name: create-enemy-type
description: Use when adding a new enemy unit or boss to cultists-vs-capitalists. Covers the UnitData and AbilityData resources, per-unit-type kill leveling, the UNITS.md register, procedural mesh/icon registration, and wiring into UnitLibrary and WaveDirector.
---

# Adding an Enemy Unit or Boss

Every enemy unit or boss is a `UnitData` resource in `res://data/units/` (or `res://data/units/bosses/` for bosses). That resource holds the **base (level 0 / boss_index 1)** numbers. Spawn-time scaling is applied automatically by `UnitLeveling` and `TowerSystem.spawn_unit_from_data()`.

## Documentation Register — Keep `UNITS.md` In Sync

[`UNITS.md`](../../../UNITS.md) at the repo root is the human-readable register of **every** enemy — the 16 regular units (by faction), the 5 bosses, the `rogue_entity`, and the ability-component reference.

**Any change to a `UnitData` or `AbilityData` resource — a new unit or boss, a stat retune, a new ability, a changed parameter — MUST update `UNITS.md` in the same change.** A unit change is not complete until the register matches the data. Specifically:

- Adding a unit: add its row to its faction's table (§2–§5), add its abilities to the "Signature abilities" notes, and update the totals in §1.1.
- Adding a boss: add it to §6 with its stats and its mechanic paragraph.
- Adding an ability id: add it to the §8 ability-component reference (§8.1 regular / §8.2 boss).
- A new unit or boss also requires updating the roster assertions in `res://tests/test_enemy_library.gd`.

Do not treat `UNITS.md` as optional prose: it is the roster-of-record a designer reads instead of opening 22 `.tres` files.

## Architecture Overview

| Piece | File | Job |
| --- | --- | --- |
| `UnitData` | `scripts/units/unit_data.gd` | Base stats (`id`, `display_name`, `faction`, `cost`, `base_hp`, `speed`, `tags`, `resistances`, `abilities`, `leak_cost`, `scrap_value`) |
| `AbilityData` | `scripts/units/ability_data.gd` | Reusable data-parameterized ability component + telegraph hook (`telegraph_event`, `telegraph_lead_time`) |
| `UnitAbilityRegistry` | `scripts/units/unit_ability_registry.gd` | Registry & validator for all regular and boss ability IDs |
| `UnitLeveling` | `scripts/units/unit_leveling.gd` | Per-unit-id kill tracking, interval level floor, spawn-time HP/speed snapshotting, and boss scaling |
| `UnitLibrary` | `scripts/units/unit_library.gd` | Catalog loader (`REGULAR_UNIT_PATHS`, `BOSS_UNIT_PATHS`) |
| `PlaceholderModels` | `scripts/world/placeholder_models.gd` | Procedural 3D mesh for the unit (`get_unit_mesh`) |
| `PlaceholderIcons` | `scripts/ui/placeholder_icons.gd` | Procedural 2D icon for Intel & Boss UI (`get_unit_icon`) |

## Steps to Add a Unit

1. Create `res://data/units/<unit_id>.tres` (or `res://data/units/bosses/<boss_id>.tres`) with script `res://scripts/units/unit_data.gd`.
2. Populate base fields: `id`, `display_name`, `faction` (`swarm_syndicate`, `iron_board`, `hostile_takeover`, `skyline_logistics`, or `coalition`), `cost`, `base_hp`, `speed` (in hexes/s), `tags` (`PathConstants.UnitTag` ints), `resistances` (`PathConstants.DamageTag -> float`), and `abilities` (`Array[AbilityData]`).
3. Ensure every attached `AbilityData` uses a registered `ability_id` in `UnitAbilityRegistry` and has a non-empty `telegraph_event`.
4. Register the `.tres` path in `UnitLibrary.REGULAR_UNIT_PATHS` (or `BOSS_UNIT_PATHS`).
5. Add a distinct silhouette in `PlaceholderModels.get_unit_mesh()` and an icon in `PlaceholderIcons.get_unit_icon()`.
6. Update `res://tests/test_enemy_library.gd` if catalog counts change, and run `run_tests` on `res://tests/test_enemy_library.gd`.
7. Update [`UNITS.md`](../../../UNITS.md) (see "Documentation Register" above): add the unit's faction-table row and ability notes (or the boss's §6 entry), update the §1.1 totals, and add any new ability id to the §8 reference. Re-read the register against the data so no row is stale — a register that disagrees with the `.tres` files is a bug.
