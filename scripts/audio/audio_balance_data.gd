## AudioBalanceData
##
## Designer-editable Resource holding all sound effect mappings, volume levels (dB),
## anti-clutter retrigger intervals, per-cue polyphony caps, pitch variation ranges,
## and biome environment loop paths for Cultists vs Capitalists.
class_name AudioBalanceData
extends Resource

# --- Core 11 Requested Sound Categories & Archetype Sub-Variants -------------
const CUE_PROJECTILE_FIRE: String = "projectile_fire"
const CUE_PROJECTILE_FIRE_SNIPER: String = "projectile_fire_sniper"
const CUE_PROJECTILE_FIRE_CENSER: String = "projectile_fire_censer"
const CUE_PROJECTILE_FIRE_TESLA: String = "projectile_fire_tesla"
const CUE_PROJECTILE_HIT: String = "projectile_hit"
const CUE_TOWER_CONSTRUCT: String = "tower_construct"
const CUE_TOWER_CD_DEFAULT: String = "tower_cd_default"
const CUE_TOWER_CD_CONGREGATION_RESPAWN: String = "tower_cd_congregation_respawn"
const CUE_TOWER_CD_TENTACLE_ROOT: String = "tower_cd_tentacle_root"
const CUE_TOWER_CD_LEVIATHAN_SWEEP: String = "tower_cd_leviathan_sweep"
const CUE_TOWER_CD_GUTTER_PULSE: String = "tower_cd_gutter_pulse"
const CUE_TOWER_CD_MAW_BENEATH: String = "tower_cd_maw_beneath"
const CUE_TOWER_CD_CHOIR_SPECIAL: String = "tower_cd_choir_special"
const CUE_TOWER_CD_SHRINE_BURST: String = "tower_cd_shrine_burst"
const CUE_TOWER_CD_STATIC_STORM: String = "tower_cd_static_storm"
const CUE_TOWER_UPGRADE: String = "tower_upgrade"
const CUE_MOB_HIT: String = "mob_hit"
const CUE_MOB_DEATH: String = "mob_death"
const CUE_BOSS_HIT: String = "boss_hit"
const CUE_BOSS_DEATH: String = "boss_death"
const CUE_BOSS_SPECIAL_ABILITY: String = "boss_special_ability"
const CUE_ENVIRONMENT_URBAN: String = "environment_urban"

# --- Additional Discovered Gameplay & UI Cues --------------------------------
const CUE_WAVE_STARTED: String = "wave_started"
const CUE_WAVE_ENDED: String = "wave_ended"
const CUE_STARS_ARE_RIGHT: String = "stars_are_right"
const CUE_RUN_EVENT: String = "run_event"
const CUE_PATH_EXTENDED: String = "path_extended"
const CUE_ENEMY_LEAKED: String = "enemy_leaked"
const CUE_GAME_OVER: String = "game_over"
const CUE_TOWER_SOLD: String = "tower_sold"
const CUE_TOWER_MAINTAINED: String = "tower_maintained"
const CUE_PENANCE: String = "penance"
const CUE_ENEMY_ABILITY: String = "enemy_ability"
const CUE_UI_CLICK: String = "ui_click"
const CUE_UI_ERROR: String = "ui_error"

const DEFAULT_RESOURCE_PATH: String = "res://data/audio_balance.tres"

@export var sfx_pool_size: int = 16
@export var max_global_sfx_voices: int = 8
@export var master_sfx_volume_db: float = 0.0
@export var environment_volume_db: float = -14.0
## Volume attenuation (in dB) applied per already-active concurrent voice of the same cue
## so simultaneous rapid-fire shots and hits never stack into an overwhelming spike.
@export var polyphony_attenuation_per_voice_db: float = 2.5
@export var global_density_attenuation_per_voice_db: float = 0.8

## Biome ID -> environment cue ID mapping.
@export var biome_environment_cues: Dictionary = {
	"urban_center": CUE_ENVIRONMENT_URBAN,
}

## Cue ID -> Dictionary of {
##   "path": String,
##   "volume_db": float,
##   "min_interval": float,
##   "max_voices": int,
##   "pitch_min": float,
##   "pitch_max": float,
##   "active_duration": float,
##   "loop": bool
## }
@export var cues: Dictionary = {}


func _init() -> void:
	if cues.is_empty():
		cues = build_default_cues()


static func build_default_cues() -> Dictionary:
	return {
		# 1. Projectile Fire (rapid default + sniper + censer variants)
		CUE_PROJECTILE_FIRE: {
			"path": "res://Sound FX Starter Pack Vol. 1/Medieval/Bow Shoot.wav",
			"volume_db": -11.0,
			"min_interval": 0.07,
			"max_voices": 3,
			"pitch_min": 0.94,
			"pitch_max": 1.08,
			"active_duration": 0.45,
			"loop": false,
		},
		CUE_PROJECTILE_FIRE_SNIPER: {
			"path": "res://Sound FX Starter Pack Vol. 1/Sci-Fi/Pulse Sniper.wav",
			"volume_db": -7.5,
			"min_interval": 0.20,
			"max_voices": 2,
			"pitch_min": 0.96,
			"pitch_max": 1.04,
			"active_duration": 0.55,
			"loop": false,
		},
		CUE_PROJECTILE_FIRE_CENSER: {
			"path": "res://Sound FX Starter Pack Vol. 1/Steampunk/Steampunk Gas Ignite.wav",
			"volume_db": -11.5,
			"min_interval": 0.25,
			"max_voices": 2,
			"pitch_min": 0.95,
			"pitch_max": 1.05,
			"active_duration": 0.85,
			"loop": false,
		},
		CUE_PROJECTILE_FIRE_TESLA: {
			"path": "res://Sound FX Starter Pack Vol. 1/Sci-Fi/Phase Missile.wav",
			"volume_db": -9.5,
			"min_interval": 0.16,
			"max_voices": 2,
			"pitch_min": 0.95,
			"pitch_max": 1.06,
			"active_duration": 0.50,
			"loop": false,
		},

		# 2. Projectile Hit (ultra-short 0.26s active impact)
		CUE_PROJECTILE_HIT: {
			"path": "res://Sound FX Starter Pack Vol. 1/Medieval/Arrow Hit.wav",
			"volume_db": -12.5,
			"min_interval": 0.06,
			"max_voices": 3,
			"pitch_min": 0.92,
			"pitch_max": 1.10,
			"active_duration": 0.28,
			"loop": false,
		},

		# 3. Tower Construction
		CUE_TOWER_CONSTRUCT: {
			"path": "res://Sound FX Starter Pack Vol. 1/Community Requests/Hammer Fall.wav",
			"volume_db": -5.0,
			"min_interval": 0.08,
			"max_voices": 2,
			"pitch_min": 0.96,
			"pitch_max": 1.04,
			"active_duration": 0.70,
			"loop": false,
		},

		# 4. Tower Cooldown Usage Events (dramatic sounds for longer cooldowns)
		CUE_TOWER_CD_DEFAULT: {
			"path": "res://Sound FX Starter Pack Vol. 1/Magic/Water Attack.wav",
			"volume_db": -10.5,
			"min_interval": 0.65,
			"max_voices": 1,
			"pitch_min": 0.95,
			"pitch_max": 1.05,
			"active_duration": 1.20,
			"loop": false,
		},
		CUE_TOWER_CD_CONGREGATION_RESPAWN: {
			"path": "res://Sound FX Starter Pack Vol. 1/Magic/Resurrection.wav",
			"volume_db": -7.5,
			"min_interval": 0.45,
			"max_voices": 1,
			"pitch_min": 0.97,
			"pitch_max": 1.03,
			"active_duration": 1.40,
			"loop": false,
		},
		CUE_TOWER_CD_TENTACLE_ROOT: {
			"path": "res://Sound FX Starter Pack Vol. 1/Magic/Water Attack.wav",
			"volume_db": -11.5,
			"min_interval": 0.75,
			"max_voices": 1,
			"pitch_min": 0.94,
			"pitch_max": 1.04,
			"active_duration": 1.10,
			"loop": false,
		},
		CUE_TOWER_CD_LEVIATHAN_SWEEP: {
			"path": "res://Sound FX Starter Pack Vol. 1/Magic/Earth Attack.wav",
			"volume_db": -5.5,
			"min_interval": 0.50,
			"max_voices": 1,
			"pitch_min": 0.92,
			"pitch_max": 1.00,
			"active_duration": 1.60,
			"loop": false,
		},
		CUE_TOWER_CD_GUTTER_PULSE: {
			"path": "res://Sound FX Starter Pack Vol. 1/Magic/Acid Attack.wav",
			"volume_db": -10.0,
			"min_interval": 0.45,
			"max_voices": 1,
			"pitch_min": 0.95,
			"pitch_max": 1.05,
			"active_duration": 1.15,
			"loop": false,
		},
		CUE_TOWER_CD_MAW_BENEATH: {
			"path": "res://Sound FX Starter Pack Vol. 1/Horror/Reality Rift.wav",
			"volume_db": -6.0,
			"min_interval": 0.50,
			"max_voices": 1,
			"pitch_min": 0.95,
			"pitch_max": 1.03,
			"active_duration": 2.00,
			"loop": false,
		},
		CUE_TOWER_CD_CHOIR_SPECIAL: {
			"path": "res://Sound FX Starter Pack Vol. 1/Magic/Necromantic Attack.wav",
			"volume_db": -11.0,
			"min_interval": 0.75,
			"max_voices": 1,
			"pitch_min": 0.96,
			"pitch_max": 1.04,
			"active_duration": 1.10,
			"loop": false,
		},
		CUE_TOWER_CD_SHRINE_BURST: {
			"path": "res://Sound FX Starter Pack Vol. 1/Magic/Magic Seal.wav",
			"volume_db": -5.5,
			"min_interval": 0.40,
			"max_voices": 1,
			"pitch_min": 0.97,
			"pitch_max": 1.03,
			"active_duration": 2.22,
			"loop": false,
		},
		CUE_TOWER_CD_STATIC_STORM: {
			"path": "res://Sound FX Starter Pack Vol. 1/Motions and Impacts/Swoosh Thunder.wav",
			"volume_db": -6.5,
			"min_interval": 0.45,
			"max_voices": 1,
			"pitch_min": 0.94,
			"pitch_max": 1.04,
			"active_duration": 1.45,
			"loop": false,
		},

		# 5. Tower Upgrade
		CUE_TOWER_UPGRADE: {
			"path": "res://Sound FX Starter Pack Vol. 1/Medieval/Weapon Upgrade.wav",
			"volume_db": -4.5,
			"min_interval": 0.08,
			"max_voices": 2,
			"pitch_min": 0.98,
			"pitch_max": 1.05,
			"active_duration": 0.35,
			"loop": false,
		},

		# 6. Mob Hit (short 0.23s low-fatigue thud)
		CUE_MOB_HIT: {
			"path": "res://Sound FX Starter Pack Vol. 1/Retro/Damage.wav",
			"volume_db": -13.5,
			"min_interval": 0.08,
			"max_voices": 3,
			"pitch_min": 0.92,
			"pitch_max": 1.08,
			"active_duration": 0.25,
			"loop": false,
		},

		# 7. Mob Death (compact scrap/crate collapse)
		CUE_MOB_DEATH: {
			"path": "res://Sound FX Starter Pack Vol. 1/Hollywood/Wooden Crate Destruction.wav",
			"volume_db": -8.5,
			"min_interval": 0.09,
			"max_voices": 3,
			"pitch_min": 0.93,
			"pitch_max": 1.07,
			"active_duration": 0.75,
			"loop": false,
		},

		# 8. Boss Hit (short 0.28s heavy armor clang)
		CUE_BOSS_HIT: {
			"path": "res://Sound FX Starter Pack Vol. 1/Medieval/Shield Block.wav",
			"volume_db": -8.0,
			"min_interval": 0.10,
			"max_voices": 2,
			"pitch_min": 0.90,
			"pitch_max": 1.02,
			"active_duration": 0.32,
			"loop": false,
		},

		# 9. Boss Death
		CUE_BOSS_DEATH: {
			"path": "res://Sound FX Starter Pack Vol. 1/Hollywood/Mega Bomb.wav",
			"volume_db": -2.5,
			"min_interval": 0.50,
			"max_voices": 1,
			"pitch_min": 0.95,
			"pitch_max": 1.02,
			"active_duration": 2.50,
			"loop": false,
		},

		# 10. Boss Special Ability
		CUE_BOSS_SPECIAL_ABILITY: {
			"path": "res://Sound FX Starter Pack Vol. 1/Sci-Fi/Gravipanzer.wav",
			"volume_db": -4.0,
			"min_interval": 0.35,
			"max_voices": 2,
			"pitch_min": 0.95,
			"pitch_max": 1.05,
			"active_duration": 1.30,
			"loop": false,
		},

		# 11. Urban Environment Loop
		CUE_ENVIRONMENT_URBAN: {
			"path": "res://Sound FX Starter Pack Vol. 1/Environment/Rainy City Alley Loop.wav",
			"volume_db": -14.0,
			"min_interval": 0.0,
			"max_voices": 1,
			"pitch_min": 1.0,
			"pitch_max": 1.0,
			"active_duration": 60.0,
			"loop": true,
		},

		# --- Additional Discovered Gameplay & UI Cues ---
		CUE_WAVE_STARTED: {
			"path": "res://Sound FX Starter Pack Vol. 1/Motions and Impacts/Whoosh Gong.wav",
			"volume_db": -5.0,
			"min_interval": 0.25,
			"max_voices": 1,
			"pitch_min": 0.98,
			"pitch_max": 1.02,
			"active_duration": 2.20,
			"loop": false,
		},
		CUE_WAVE_ENDED: {
			"path": "res://Sound FX Starter Pack Vol. 1/Hollywood/Reward.wav",
			"volume_db": -6.0,
			"min_interval": 0.25,
			"max_voices": 1,
			"pitch_min": 0.98,
			"pitch_max": 1.02,
			"active_duration": 1.00,
			"loop": false,
		},
		CUE_STARS_ARE_RIGHT: {
			"path": "res://Sound FX Starter Pack Vol. 1/Horror/Bleak Moon Piano.wav",
			"volume_db": -4.5,
			"min_interval": 0.50,
			"max_voices": 1,
			"pitch_min": 1.0,
			"pitch_max": 1.0,
			"active_duration": 3.65,
			"loop": false,
		},
		CUE_RUN_EVENT: {
			"path": "res://Sound FX Starter Pack Vol. 1/Motions and Impacts/Impact Metal Hatch.wav",
			"volume_db": -5.0,
			"min_interval": 0.50,
			"max_voices": 1,
			"pitch_min": 1.0,
			"pitch_max": 1.0,
			"active_duration": 1.70,
			"loop": false,
		},
		CUE_PATH_EXTENDED: {
			"path": "res://Sound FX Starter Pack Vol. 1/Motions and Impacts/Impact Metal Hatch.wav",
			"volume_db": -4.5,
			"min_interval": 0.40,
			"max_voices": 1,
			"pitch_min": 0.96,
			"pitch_max": 1.02,
			"active_duration": 1.70,
			"loop": false,
		},
		CUE_ENEMY_LEAKED: {
			"path": "res://Sound FX Starter Pack Vol. 1/Jingles & Stingers/Health Low.wav",
			"volume_db": -5.0,
			"min_interval": 0.12,
			"max_voices": 2,
			"pitch_min": 0.96,
			"pitch_max": 1.04,
			"active_duration": 0.30,
			"loop": false,
		},
		CUE_GAME_OVER: {
			"path": "res://Sound FX Starter Pack Vol. 1/Jingles & Stingers/Game Over.wav",
			"volume_db": -3.0,
			"min_interval": 1.00,
			"max_voices": 1,
			"pitch_min": 1.0,
			"pitch_max": 1.0,
			"active_duration": 4.40,
			"loop": false,
		},
		CUE_TOWER_SOLD: {
			"path": "res://Sound FX Starter Pack Vol. 1/Medieval/Loot Gold.wav",
			"volume_db": -6.0,
			"min_interval": 0.08,
			"max_voices": 2,
			"pitch_min": 0.96,
			"pitch_max": 1.04,
			"active_duration": 0.25,
			"loop": false,
		},
		CUE_TOWER_MAINTAINED: {
			"path": "res://Sound FX Starter Pack Vol. 1/Sci-Fi/Turret Reload.wav",
			"volume_db": -6.5,
			"min_interval": 0.12,
			"max_voices": 2,
			"pitch_min": 0.97,
			"pitch_max": 1.03,
			"active_duration": 1.05,
			"loop": false,
		},
		CUE_PENANCE: {
			"path": "res://Sound FX Starter Pack Vol. 1/Jingles & Stingers/Full Heal.wav",
			"volume_db": -6.0,
			"min_interval": 0.15,
			"max_voices": 2,
			"pitch_min": 0.98,
			"pitch_max": 1.02,
			"active_duration": 0.55,
			"loop": false,
		},
		CUE_ENEMY_ABILITY: {
			"path": "res://Sound FX Starter Pack Vol. 1/Horror/Pain Glitch.wav",
			"volume_db": -13.5,
			"min_interval": 0.85,
			"max_voices": 1,
			"pitch_min": 0.95,
			"pitch_max": 1.05,
			"active_duration": 0.75,
			"loop": false,
		},
		CUE_UI_CLICK: {
			"path": "res://Sound FX Starter Pack Vol. 1/UI & Menus/Click Bounce.wav",
			"volume_db": -9.0,
			"min_interval": 0.04,
			"max_voices": 2,
			"pitch_min": 0.97,
			"pitch_max": 1.03,
			"active_duration": 0.16,
			"loop": false,
		},
		CUE_UI_ERROR: {
			"path": "res://Sound FX Starter Pack Vol. 1/UI & Menus/Error.wav",
			"volume_db": -7.0,
			"min_interval": 0.10,
			"max_voices": 1,
			"pitch_min": 0.98,
			"pitch_max": 1.02,
			"active_duration": 0.55,
			"loop": false,
		},
	}


func get_cue_config(cue_id: String) -> Dictionary:
	if cues.has(cue_id):
		return cues[cue_id] as Dictionary
	var defaults: Dictionary = build_default_cues()
	if defaults.has(cue_id):
		return defaults[cue_id] as Dictionary
	return {}


func get_environment_cue_for_biome(biome_id: String) -> String:
	if biome_environment_cues.has(biome_id):
		return String(biome_environment_cues[biome_id])
	return CUE_ENVIRONMENT_URBAN
