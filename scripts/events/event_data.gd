## EventData
##
## Designer-editable definition of a single run Event — the "cards" in the run's
## event deck. Events fire pseudo-randomly every few waves and are revealed only
## at wave start (never advertised ahead of time). Stored as .tres files under
## res://data/events/ and loaded via [EventLibrary].
class_name EventData
extends Resource

## Whether the event helps or hinders the player. Used only by the bad-luck
## protection rule that forbids more than MAX_SAME_CATEGORY_RUN of one category
## in a row. Events do NOT strictly alternate between categories.
enum Category {
	BUFF = 0,
	DEBUFF = 1,
}

@export var id: String = ""
@export var display_name: String = "Event"
@export_multiline var description: String = ""
@export var category: Category = Category.BUFF
## Banner tint shown when the event triggers at wave start.
@export var banner_color: Color = Color(0.85, 0.45, 1.0)
## When false, this event is never chosen on a Boss wave. (The first boss wave,
## EventBalanceData.first_boss_wave, is excluded for every event regardless.)
@export var allow_on_boss_wave: bool = true

@export_group("Instant Effects (applied once at wave start)")
## Flat Offerings granted (negative drains). Scaled by instant_scaling_per_wave.
@export var instant_offerings: int = 0
## Flat Scrap granted (negative drains). Scaled by instant_scaling_per_wave.
@export var instant_scrap: int = 0
## Fraction of current Offerings drained (0.25 = lose 25% of holdings), clamped to >= 0.
@export var instant_offerings_pct: float = 0.0
## Fraction of current Scrap drained, clamped to >= 0.
@export var instant_scrap_pct: float = 0.0
## Corruption change (positive adds Corruption, negative cleanses).
@export var instant_corruption: int = 0
## Jank added to every Rigged tower.
@export var instant_rigged_jank: int = 0
## Linear growth on the flat grants: value * (1 + instant_scaling_per_wave * (wave - 1)).
@export var instant_scaling_per_wave: float = 0.0

@export_group("Wave-Duration Effects (cleared at wave end)")
## Additive Revealed-tower damage bonus (0.20 = +20%); stacks with Corruption.
@export var revealed_damage_bonus: float = 0.0
## Multiplier on all tower damage (1.0 = neutral).
@export var tower_damage_mult: float = 1.0
## Multiplier on all tower fire rate (1.0 = neutral).
@export var fire_rate_mult: float = 1.0
## Multiplier on enemy movement speed (1.0 = neutral).
@export var enemy_speed_mult: float = 1.0
## Multiplier on spawned enemy max HP (1.0 = neutral).
@export var enemy_hp_mult: float = 1.0
## Multiplier on the wave budget used by the Wave Director (1.0 = neutral).
@export var budget_mult: float = 1.0
## Multiplier on Scrap gained from kills (1.0 = neutral).
@export var scrap_income_mult: float = 1.0
## When true, negates the Corruption + Revealed damage bonuses for the wave.
@export var suppress_revealed: bool = false


func get_category_name() -> String:
	return "BUFF" if category == Category.BUFF else "DEBUFF"


## Human-readable banner text shown at wave start.
func get_banner_text() -> String:
	if description.is_empty():
		return display_name.to_upper()
	return "%s — %s" % [display_name.to_upper(), description]


## Duration modifiers as a Dictionary consumed by TowerSystem.apply_event_modifiers.
func get_duration_modifiers() -> Dictionary:
	return {
		"event_id": id,
		"revealed_damage_bonus": revealed_damage_bonus,
		"tower_damage_mult": tower_damage_mult,
		"fire_rate_mult": fire_rate_mult,
		"enemy_speed_mult": enemy_speed_mult,
		"enemy_hp_mult": enemy_hp_mult,
		"scrap_income_mult": scrap_income_mult,
		"suppress_revealed": suppress_revealed,
	}