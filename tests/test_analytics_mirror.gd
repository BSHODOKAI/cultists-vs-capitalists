## TestAnalyticsMirror
##
## Hermetic end-to-end test for the stopgap AnalyticsMirror autoload: it stands up
## a local TCP "collector", points the mirror at it, and asserts the mirror posts
## a well-formed batch (same wire format as Ziva's SDK) that preserves event props.
extends Node

const _Mirror = preload("res://scripts/telemetry/analytics_mirror.gd")


func test_01_mirror_is_inert_without_a_configured_endpoint() -> void:
	var mirror: Node = _Mirror.new()
	add_child(mirror)
	assert(not bool(mirror.get("_enabled")), "mirror must stay disabled when no endpoint is configured")
	assert(String(mirror.get("_endpoint")).is_empty(), "endpoint must default to empty")
	mirror.queue_free()


func test_02_mirror_posts_a_batch_to_a_collector() -> void:
	var server := TCPServer.new()
	var listen_err: int = server.listen(0, "127.0.0.1")
	assert(listen_err == OK, "TCPServer.listen failed: %s" % error_string(listen_err))
	var port: int = server.get_local_port()
	assert(port > 0, "expected an ephemeral local port")

	var mirror: Node = _Mirror.new()
	mirror.force_enable_in_tests = true
	add_child(mirror)
	mirror.configure("http://127.0.0.1:%d/ingest" % port, "test-key")
	assert(bool(mirror.get("_enabled")), "mirror must enable once an endpoint is configured")

	mirror.call("track", "wave_completed", {"wave": 3, "kills": 7})
	mirror.call("flush")

	var received: Dictionary = await _serve_one(server)
	server.stop()
	mirror.queue_free()

	var raw: String = String(received.get("raw", ""))
	assert(not raw.is_empty(), "collector received no request")
	assert(raw.begins_with("POST "), "request must be a POST, got: %s" % raw.substr(0, 40))

	var parsed: Variant = JSON.parse_string(String(received.get("body", "")))
	assert(parsed is Dictionary, "request body must be JSON, got: %s" % String(received.get("body", "")))
	var doc: Dictionary = parsed as Dictionary
	assert(String(doc.get("key", "")) == "test-key", "collector must receive the configured key")

	var events: Array = doc.get("events", []) as Array
	assert(events.size() >= 1, "batch must contain at least one event")
	var names: Array[String] = []
	var wave_ev: Dictionary = {}
	for ev: Variant in events:
		var e: Dictionary = ev as Dictionary
		names.append(String(e.get("name", "")))
		if String(e.get("name", "")) == "wave_completed":
			wave_ev = e
	assert(names.has("wave_completed"), "batch must contain wave_completed (got %s)" % str(names))
	assert(not wave_ev.is_empty(), "wave_completed event must be present")
	assert(
		int((wave_ev.get("props", {}) as Dictionary).get("kills", 0)) == 7,
		"event props must be preserved through the mirror"
	)
	# ids must be UUID4 GUIDs, matching the contract the collector validates.
	assert(String(wave_ev.get("id", "")).length() == 36, "event id must be a GUID")


## Accepts one HTTP request, replies 202 with CORS headers, and returns what arrived.
func _serve_one(server: TCPServer) -> Dictionary:
	var deadline: float = Time.get_ticks_msec() + 10000.0
	while not server.is_connection_available():
		if Time.get_ticks_msec() > deadline:
			return {"error": "timeout waiting for connection"}
		await get_tree().process_frame

	var peer: StreamPeerTCP = server.take_connection()
	assert(peer != null, "take_connection returned null")

	var buf := PackedByteArray()
	var header_end: int = -1
	var content_length: int = 0
	var body_end: int = -1

	while Time.get_ticks_msec() < deadline:
		if peer.get_available_bytes() > 0:
			var res: Array = peer.get_partial_data(8192)
			var chunk: PackedByteArray = res[1]
			if chunk.size() > 0:
				buf.append_array(chunk)
		if header_end < 0:
			header_end = buf.get_string_from_utf8().find("\r\n\r\n")
			if header_end >= 0:
				content_length = _parse_content_length(buf.slice(0, header_end).get_string_from_utf8())
				body_end = header_end + 4 + content_length
		if body_end >= 0 and buf.size() >= body_end:
			break
		await get_tree().process_frame

	var body := ""
	if header_end >= 0 and buf.size() >= header_end + 4:
		body = buf.slice(header_end + 4).get_string_from_utf8()

	var payload := "{\"accepted\":1}"
	var response := (
		"HTTP/1.1 202 Accepted\r\n"
		+ "Content-Type: application/json\r\n"
		+ "Content-Length: %d\r\n" % payload.to_utf8_buffer().size()
		+ "Access-Control-Allow-Origin: *\r\n"
		+ "Connection: close\r\n\r\n"
		+ payload
	)
	peer.put_data(response.to_utf8_buffer())
	peer.poll()
	await get_tree().process_frame
	return {"raw": buf.get_string_from_utf8(), "body": body}


static func _parse_content_length(header_text: String) -> int:
	for line: String in header_text.split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			return int(line.split(":", true, 1)[1].strip_edges())
	return 0