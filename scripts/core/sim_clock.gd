## SimClock
##
## Fixed-timestep (30 Hz) simulation clock autoload.
## All gameplay systems tick from SimClock, never from _process delta, so pause
## and speed multipliers (1x / 2x / 3x) work and runs are deterministic.
## Rendering interpolates between ticks using [member interpolation_alpha].
class_name SimClockNode
extends Node

signal tick(dt: float, tick_index: int)
signal speed_changed(new_speed: float)
signal pause_changed(is_paused: bool)

const TICK_RATE: float = 30.0
const TICK_DELTA: float = 1.0 / TICK_RATE
const MAX_TICKS_PER_FRAME: int = 12
const ALLOWED_SPEEDS: Array[float] = [1.0, 2.0, 3.0]

var paused: bool = false
var speed_multiplier: float = 1.0
var tick_count: int = 0
var accumulator: float = 0.0
var interpolation_alpha: float = 0.0
## When true, _process does not automatically advance ticks (used during headless tests).
var manual_mode: bool = false


func reset() -> void:
	paused = false
	speed_multiplier = 1.0
	tick_count = 0
	accumulator = 0.0
	interpolation_alpha = 0.0


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	pause_changed.emit(paused)


func toggle_pause() -> void:
	set_paused(not paused)


func set_speed(multiplier: float) -> void:
	var clamped: float = clampf(multiplier, 0.25, 20.0)
	if is_equal_approx(speed_multiplier, clamped):
		return
	speed_multiplier = clamped
	speed_changed.emit(speed_multiplier)


func _process(delta: float) -> void:
	if manual_mode or paused:
		return
	accumulator += delta * speed_multiplier
	var steps: int = 0
	while accumulator >= TICK_DELTA and steps < MAX_TICKS_PER_FRAME:
		accumulator -= TICK_DELTA
		_execute_single_tick()
		steps += 1
	if accumulator >= TICK_DELTA * float(MAX_TICKS_PER_FRAME):
		accumulator = fmod(accumulator, TICK_DELTA)
	interpolation_alpha = clampf(accumulator / TICK_DELTA, 0.0, 1.0)


func _execute_single_tick() -> void:
	tick_count += 1
	tick.emit(TICK_DELTA, tick_count)


## Deterministically advances the simulation by [param count] fixed ticks immediately.
func step_ticks(count: int = 1) -> void:
	for _i in range(maxi(0, count)):
		_execute_single_tick()
	interpolation_alpha = 1.0
