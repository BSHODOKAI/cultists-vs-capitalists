PROJECT: Endless-mode, isometric, hex-grid tower defense in Godot 4
(typed GDScript). A scrappy Lovecraftian cult (mysticism + salvaged junk)
defends against sleek, sponsor-branded cyberpunk corporate warlords.

CORE LOOP
- Enemies spawn at the far end of a procedurally generated path and walk
  to the player's base at path index 0. Air units also follow the path
  (they ignore blockers and are only hit by anti-air towers).
- A leaked enemy costs lives (field leak_cost, default 1). Lives start at
  20. A leaked BOSS is an immediate game over. Zero lives is game over.
- Every 10th wave is a boss wave. When the boss dies, the path grows.
- An AI director builds each wave from a budget, adapting to the player's
  defenses to force balanced builds.
- Towers have NO HP in v1. Enemies interact with towers by disabling,
  suppressing, or converting them.

CURRENCIES
- Offerings: build towers, Revealed upgrades, Penance. Earned from kills
  and Tithe Boxes. Start: 150.
- Scrap: Rigged upgrades and maintenance. Dropped by killed enemies
  (scrap_value defaults to round(cost * 0.5), overridable per unit).
  Start: 0.

TAGS
Damage tags: Kinetic, Corrosive, Psychic, Void, Electric.
Unit tags: Ground, Air, Fast, Fragile, Armored, Shielded, Cloaked, Swarm,
Healer, Spawner, Support, Aura, Hacker, Electric, Anti-Magic, Cybernetic,
Tank, Ranged, Boss.
Resistances are damage multipliers per damage tag (0.75 = takes 25% less,
1.25 = takes 25% more).
Bosses: immune to flee, displacement, root and conversion; slows and
damage-over-time effects apply at 50% strength.

SPECIAL EVENT: "Stars Are Right" waves are every 5th wave that is not a
boss wave (5, 15, 25...). Revealed towers deal +20% damage that wave.

ENGINEERING CONVENTIONS
- All game data lives in Resource (.tres) files under res://data/. All
  balance numbers live in named constants or one balance resource per
  system, never scattered through logic.
- Separate pure logic (RefCounted classes) from Nodes so everything can be
  tested headlessly. Use GUT for tests.
- All randomness uses seeded RandomNumberGenerator instances passed in.
  Never call global randf()/randi().
- Cross-system events are signals: wave_started, wave_ended, enemy_died,
  enemy_leaked, boss_killed, boss_leaked, path_extended,
  tower_damaged_enemy(tower_id, tower_type, unit_id, unit_tags, amount,
  damage_tag).
- Rendering is out of scope except for placeholder visuals and explicit UI
  hooks. Do not add features that are not in the spec; when the spec is
  ambiguous, choose the simplest option and list it as an assumption.

WORKFLOW
1) Restate your understanding and list assumptions.
2) Propose the file layout.
3) Implement.
4) Write the tests specified.
5) Finish with a summary: what is done, assumptions made, open items.