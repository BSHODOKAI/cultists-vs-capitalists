## UpgradeNode
##
## Data-driven Resource representing a single upgrade node (T2 shared, T3
## Revealed/Rigged, or T4 Capstone) on a tower's upgrade tree.
## Effects are declarative stat modifiers plus named behavior IDs from
## [TowerBehaviorRegistry], so new nodes require no engine changes.
class_name UpgradeNode
extends Resource

enum Branch {
	SHARED = 0,
	REVEALED = 1,
	RIGGED = 2,
	## Rite branch: paid in Rites (Corruption spent as a resource). The T3 fork is
	## exclusive, so choosing Rite locks both Revealed and Rigged, and vice versa.
	RITE = 3,
}

enum Currency {
	OFFERINGS = 0,
	SCRAP = 1,
	## Rites are Corruption spent as a resource: drawing them costs Corruption and
	## leaves permanent Corporate Attention behind (see TowerBalanceData).
	RITES = 2,
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var tower_id: String = ""
@export var tier: int = 2
@export var branch: Branch = Branch.SHARED
@export var currency: Currency = Currency.OFFERINGS
@export var cost: int = 0
@export var prerequisite_id: String = ""

## Global Corruption added when purchasing this upgrade (T3 Revealed: +4, T4 Revealed: +8).
@export var corruption_delta: int = 0
## Jank percentage set on the tower when purchasing this upgrade (T3 Rigged: 10, T4 Rigged: 25).
@export var jank_set: int = 0

@export_group("Stat Modifiers")
## Additive damage multiplier (e.g. 0.40 = +40% damage).
@export var damage_mult: float = 0.0
## Additive fire/application rate multiplier (e.g. 0.30 = +30% fire rate).
@export var fire_rate_mult: float = 0.0
## Flat hex range added to the tower's range (or aura radius).
@export var range_add: int = 0
## Fractional range multiplier (e.g. 0.10 = +10% range).
@export var range_mult: float = 0.0
## Additional choir members (for chanting_choir).
@export var members_add: int = 0
## Additional simultaneous targets (for tentacle_storm_drain).
@export var targets_add: int = 0
## If > 0, overrides the tower's slow aura strength (e.g. 0.45 for more_grates).
@export var slow_aura_override: float = -1.0
## If > 0, overrides the AIR_CONTROL tower's grounding bonus (extra ELECTRIC damage taken).
@export var grounding_bonus_override: float = -1.0
## If > 0, overrides the tower's DoT duration in seconds (e.g. 6.0 for heavier_incense).
@export var dot_duration_override: float = -1.0
## If > 0, raises the Armor Shred stack cap applied by this tower (8 or 10).
@export var shred_cap_override: int = -1
## If > 0, overrides the Fever Shrine aura fire-rate bonus (e.g. 0.30 for frenzy_rites).
@export var aura_fire_rate_override: float = -1.0
## Additional summoned blockers (for the_congregation).
@export var summon_count_add: int = 0
## Flat HP added to each summoned blocker.
@export var summon_hp_add: float = 0.0
## Fractional HP bonus added to each summoned blocker (e.g. 1.0 = +100% HP).
@export var summon_hp_mult: float = 0.0
## Additive income multiplier (e.g. 0.50 = +50% Offerings income).
@export var income_mult: float = 0.0
## When true, allows a Ground-only tower to also target Air units.
@export var grants_air_targeting: bool = false
## Additive damage multiplier per point of CURRENT Corruption (e.g. 0.004 = +0.4%
## per point, so +40% at 100 Corruption). The Rite branch's signature: it turns the
## danger meter into a damage stat, which is what the cult paid Attention for.
@export var corruption_scaled_damage: float = 0.0
## Additive bonus per point of CURRENT Corruption, keyed by stat name. The Rite branch exists
## on ALL towers, but damage is meaningless on a tower that never attacks -- this is how the
## branch scales the stats a SUPPORT tower actually has. Supported keys: `"aura_fire_rate"`,
## `"income"`, `"summon_hp"`, `"slow_aura"`. `"damage"` is also accepted here and folds into
## `corruption_scaled_damage`, so both spellings work.
@export var corruption_scaled_stat: Dictionary = {}

@export_group("Named Behaviors")
## Named behavior IDs resolved via TowerBehaviorRegistry.
@export var behaviors: Array[String] = []
## Optional parameter dictionary keyed by parameter name for behavior customization.
@export var behavior_params: Dictionary = {}
