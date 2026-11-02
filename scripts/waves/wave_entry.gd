## WaveEntry
##
## One "spawn N of enemy type X" instruction inside a WaveData.
class_name WaveEntry
extends Resource

@export var enemy_data: EnemyData
## How many of this enemy to spawn in the entry.
@export var count: int = 5
