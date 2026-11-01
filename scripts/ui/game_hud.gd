## GameHud
##
## Minimal placeholder HUD: shows the player's build currency, HP and the current
## stage. Attach to a CanvasLayer with child Labels named "ResourceLabel",
## "HealthLabel" and "StageLabel".
extends CanvasLayer

@onready var _resource_label: Label = $ResourceLabel
@onready var _health_label: Label = $HealthLabel
@onready var _stage_label: Label = $StageLabel

var _resources: PlayerResources
var _health: PlayerHealth
var _stages: StageManager


func _ready() -> void:
	_resources = PlayerResources.of(self)
	if _resources != null:
		_resources.changed.connect(_refresh_resources)
		_refresh_resources(_resources.amount, 0)
	_health = PlayerHealth.of(self)
	if _health != null:
		_health.changed.connect(_refresh_health)
		_refresh_health(_health.health, _health.max_health)
	_stages = StageManager.of(self)
	if _stages != null:
		_stages.stage_started.connect(_refresh_stage)
		_refresh_stage(maxi(_stages.current_stage, 1), 0)


func _refresh_resources(amount: int, _delta: int) -> void:
	if _resource_label != null and _resources != null:
		_resource_label.text = "%s: %d" % [_resources.resource_name, amount]


func _refresh_health(health: int, max_health: int) -> void:
	if _health_label != null:
		_health_label.text = "HP: %d / %d" % [health, max_health]


func _refresh_stage(stage: int, _enemy_count: int) -> void:
	if _stage_label != null:
		_stage_label.text = "Stage: %d" % stage