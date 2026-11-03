---
name: test-scaling-curve
description: Use when checking whether the wave budget, unit leveling, boss scaling, and AI Wave Director counter-picks scale fairly across player build profiles in cultists-vs-capitalists. Runs the 100-wave DirectorSimulator and combat integration tests.
---

# Testing Wave Scaling & Director Fairness

Use `DirectorSimulator` (`res://scripts/director/director_simulator.gd`) and the test suites in `res://tests/` to verify that wave budgets, unit kill leveling, late-wave ramps, and counter-biases stay fair and challenging across 100 waves.

## Key Tools & Files

| Piece | Path | Job |
| --- | --- | --- |
| `DirectorSimulator` | `res://scripts/director/director_simulator.gd` | Headless 100-wave harness testing 4 player profiles (`all_nail_gun`, `balanced`, `all_revealed`, `all_rigged`) |
| `DirectorBalanceData` | `res://scripts/director/director_balance_data.gd` (`res://data/director_balance.tres`) | Budget curve, late-wave ramp (`w > 15`), rubber-banding, and counter-bias caps |
| `UnitBalanceData` | `res://scripts/units/unit_balance_data.gd` (`res://data/unit_balance.tres`) | Kill-leveling exponent/divisor, interval level floor, HP compounding, and boss HP quadratic scaling |
| `TowerBalanceData` | `res://scripts/towers/tower_balance_data.gd` (`res://data/tower_balance.tres`) | Economy starts (`150 Off / 40 Scrap`), cost escalation, Corruption/Rogue Entity scaling, Jank, and CC DR |
| `test_wave_director.gd` | `res://tests/test_wave_director.gd` | Verifies 1,000 seeded rosters, hard constraints, counter-biases, and the 100-wave simulator |
| `test_integration.gd` | `res://tests/test_integration.gd` | Runs a 25-wave seeded combat simulation through `GameState` + `TowerSystem` |

## How to Run the 100-Wave Simulator

```gdscript
extends SceneTree
func _init() -> void:
var sim = load("res://scripts/director/director_simulator.gd").new()
var res: Dictionary = sim.run_all_profiles(100, 1337, false)
print("All profiles fair: ", res["all_profiles_fair"])
for pid: String in res["profiles"].keys():
var p: Dictionary = res["profiles"][pid]
print("%s -> leaks=%d, leak_waves=%d, zero_leak_waves=%d, counter_picks=%d, rubber=[%.2f..%.2f]" % [
pid, int(p["total_leaks"]), int(p["waves_with_leaks"]), int(p["zero_leak_waves"]),
int(p["total_counter_picks"]), float(p["min_rubber"]), float(p["max_rubber"])
])
quit()
```

Or run `run_tests` on `res://tests/test_wave_director.gd` and `res://tests/test_integration.gd`.
