## TestAnalyticsDiagnostic
##
## Temporary diagnostic: proves whether the configured Ziva Analytics endpoint
## actually accepts a POST from this build. Not part of the normal suite logic.
extends Node

const ENDPOINT_SETTING := "ziva/analytics/endpoint"
const KEY_SETTING := "ziva/analytics/ingest_key"


func test_01_real_post_to_ziva_analytics_endpoint() -> void:
	var endpoint: String = str(ProjectSettings.get_setting(ENDPOINT_SETTING, ""))
	var key: String = str(ProjectSettings.get_setting(KEY_SETTING, ""))
	print("DIAG endpoint=%s key_len=%d display=%s" % [endpoint, key.length(), DisplayServer.get_name()])
	assert(not endpoint.is_empty(), "ziva/analytics/endpoint setting is missing")
	assert(not key.is_empty(), "ziva/analytics/ingest_key setting is missing")

	var http := HTTPRequest.new()
	add_child(http)
	assert(http.is_inside_tree(), "HTTPRequest must be in the tree")

	var body: String = JSON.stringify({
		"key": key,
		"sdk": "diag/0.0",
		"events": [{
			"id": _uuid4(),
			"name": "session_start",
			"ts": int(Time.get_unix_time_from_system() * 1000.0),
			"session_id": _uuid4(),
			"player_id": _uuid4(),
			"source": "player",
			"platform": OS.get_name(),
			"props": {"probe": "headless_test"},
		}],
	})
	var err: int = http.request(endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	print("DIAG request_err=%d (%s)" % [err, error_string(err)])
	assert(err == OK, "HTTPRequest.request() failed: %s" % error_string(err))

	var res: Array = await http.request_completed
	var result: int = int(res[0])
	var code: int = int(res[1])
	var resp: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var f: FileAccess = FileAccess.open("res://analytics_diag.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("raw_post result=%d code=%d\nheaders=%s\nbody=%s\n" % [result, code, str(res[2]), resp])
		f.close()
	assert(
		code >= 200 and code < 300,
		"Ziva analytics ingest rejected the post -> result=%d code=%d body=%s" % [result, code, resp]
	)


func test_02_live_sdk_autoload_posts_a_batch() -> void:
	var za: Node = get_node_or_null("/root/ZivaAnalytics")
	assert(za != null, "ZivaAnalytics autoload is not registered")
	print("DIAG_SDK enabled=%s" % str(za.get("_enabled")))

	# Let any boot-time batch (session_start) drain first.
	var guard: float = 0.0
	while not (za.get("_in_flight") as Array).is_empty() and guard < 8.0:
		await get_tree().create_timer(0.2).timeout
		guard += 0.2

	var codes: Array = []
	var http: HTTPRequest = za.get("_http") as HTTPRequest
	assert(http != null, "SDK HTTPRequest child missing")
	http.request_completed.connect(func(_r: int, c: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		codes.append(c)
	)
	za.call("track", "diagnostic_e2e", {"probe": "sdk_path"})
	za.call("flush")

	guard = 0.0
	while codes.is_empty() and guard < 12.0:
		await get_tree().create_timer(0.2).timeout
		guard += 0.2

	var f: FileAccess = FileAccess.open("res://analytics_diag_sdk.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("sdk codes=%s waited=%.1f enabled=%s in_flight=%s dropped=%s\n" % [
			str(codes), guard, str(za.get("_enabled")),
			str((za.get("_in_flight") as Array).size()), str(za.get("_dropped"))])
		f.close()
	assert(not codes.is_empty(), "SDK completed no HTTP request within 12s (batch never posted)")
	assert(codes[0] >= 200 and codes[0] < 300, "SDK post rejected: %s" % str(codes))


func test_03_bogus_key_response_for_comparison() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	var endpoint: String = str(ProjectSettings.get_setting(ENDPOINT_SETTING, ""))
	var body: String = JSON.stringify({
		"key": "zva_this_key_is_definitely_fake_000000",
		"sdk": "diag/0.0",
		"events": [{
			"id": _uuid4(), "name": "diag_bogus_key",
			"ts": int(Time.get_unix_time_from_system() * 1000.0),
			"session_id": _uuid4(), "player_id": _uuid4(),
			"source": "editor", "platform": OS.get_name(), "props": {},
		}],
	})
	var _err: int = http.request(endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	var res: Array = await http.request_completed
	var out: FileAccess = FileAccess.open("res://analytics_diag_bogus.txt", FileAccess.WRITE)
	if out != null:
		out.store_string("bogus_key code=%d body=%s\n" % [
			int(res[1]), (res[3] as PackedByteArray).get_string_from_utf8()])
		out.close()


func test_04_clock_sanity() -> void:
	var out: FileAccess = FileAccess.open("res://analytics_diag_clock.txt", FileAccess.WRITE)
	if out != null:
		out.store_string("local_utc=%s\nunix_s=%d\nunix_ms=%d\n" % [
			Time.get_datetime_string_from_system(true),
			int(Time.get_unix_time_from_system()),
			int(Time.get_unix_time_from_system() * 1000.0),
		])
		out.close()
	print("DIAG_CLOCK local_utc=%s unix_ms=%d" % [
		Time.get_datetime_string_from_system(true), int(Time.get_unix_time_from_system() * 1000.0)])


static func _uuid4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = rng.randi_range(0, 255)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)
	]