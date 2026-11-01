## WaveData
##
## A single wave: an ordered list of spawn entries plus timing.
class_name WaveData
extends Resource

@export var entries: Array[WaveEntry] = []
## Seconds between individual enemy spawns.
@export var spawn_interval: float = 0.8
## Optional label shown in the UI.
@export var label: String = ""