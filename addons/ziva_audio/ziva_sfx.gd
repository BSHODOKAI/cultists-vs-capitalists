class_name ZivaSfx
extends RefCounted

static var last_played: String = ""


static func play(from: Node, stream: AudioStream, pitch_variation: float = 0.08, volume_db: float = 0.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	if AudioServer.get_bus_index(&"SFX") != -1:
		player.bus = &"SFX"
	player.autoplay = true
	player.finished.connect(player.queue_free)
	from.get_tree().root.add_child.call_deferred(player)
	last_played = stream.resource_path
	return player
