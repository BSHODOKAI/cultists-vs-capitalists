## DisplaySettings
##
## Pure-logic helper and state manager for display settings:
##   • Machine-supported resolution discovery via DisplayServer.screen_get_size()
##   • Aspect ratio classification and resolution filtering
##   • Window mode control (Fullscreen, Windowed, Windowed Borderless) on PC
##   • Steam Deck hardware/environment detection (hides window mode selector on Steam Deck)
##   • ConfigFile persistence in user://display_settings.cfg
class_name DisplaySettings
extends RefCounted

enum WindowMode {
	FULLSCREEN = 0,
	WINDOWED = 1,
	WINDOWED_BORDERLESS = 2,
}

const SAVE_PATH: String = "user://display_settings.cfg"
const CONFIG_SECTION: String = "display"
const BASE_VIEWPORT_HEIGHT: int = 648
const DEFAULT_FALLBACK_SCREEN_SIZE: Vector2i = Vector2i(1920, 1080)

## The resolution the HUD and every pop-up window/banner are authored against.
## UI scaling follows the window but is clamped around this base so the UI stays
## consistent and bounded instead of ballooning to fill a high-resolution screen.
const UI_BASE_SIZE: Vector2i = Vector2i(1152, 648)
## The UI never shrinks below the base (UI_MIN_SCALE) nor grows past this factor
## of it (UI_MAX_SCALE) no matter how large the window is.
const UI_MIN_SCALE: float = 1.0
const UI_MAX_SCALE: float = 2.0

## Common standard resolutions across 16:9, 16:10, 21:9, and 4:3 aspect ratios.
const CANDIDATE_RESOLUTIONS: Array[Vector2i] = [
	# 16:9
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
	# 16:10 (including Steam Deck 1280x800)
	Vector2i(1280, 800),
	Vector2i(1440, 900),
	Vector2i(1680, 1050),
	Vector2i(1920, 1200),
	Vector2i(2560, 1600),
	# 21:9 Ultrawide
	Vector2i(2560, 1080),
	Vector2i(3440, 1440),
	# 4:3
	Vector2i(1024, 768),
	Vector2i(1280, 960),
	Vector2i(1400, 1050),
	Vector2i(1600, 1200),
]

## Test override for Steam Deck detection: -1 = auto, 0 = force PC, 1 = force Steam Deck.
static var steam_deck_override: int = -1

var save_path: String = SAVE_PATH
var current_resolution: Vector2i = Vector2i(1152, 648)
var current_aspect_ratio: String = "16:9"
var current_window_mode: int = WindowMode.WINDOWED


## Detects whether the game is running on a Steam Deck.
static func is_steam_deck() -> bool:
	if steam_deck_override == 0:
		return false
	if steam_deck_override == 1:
		return true

	if OS.get_environment("SteamDeck") == "1" or OS.get_environment("STEAM_DECK") == "1":
		return true
	if OS.get_environment("STEAMOS") == "1":
		return true

	var distro: String = OS.get_distribution_name().to_lower()
	if distro.contains("steamos"):
		return true

	var model: String = OS.get_model_name().to_lower()
	if model.contains("steam deck") or model.contains("steamdeck") or model.contains("jupiter") or model.contains("galileo"):
		return true

	var cpu: String = OS.get_processor_name().to_lower()
	if cpu.contains("custom apu 0405") or cpu.contains("custom apu 0932"):
		return true

	return false


## Queries the machine's active screen size in pixels.
## Falls back to DEFAULT_FALLBACK_SCREEN_SIZE when running under the headless display server.
static func get_machine_screen_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return DEFAULT_FALLBACK_SCREEN_SIZE

	var screen_idx: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_idx)
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = DisplayServer.screen_get_size(DisplayServer.get_primary_screen())
	if screen_size.x <= 0 or screen_size.y <= 0:
		return DEFAULT_FALLBACK_SCREEN_SIZE
	return screen_size


## Returns the human-readable aspect ratio string (e.g. "16:9", "16:10", "21:9", "4:3") for a resolution.
static func get_aspect_ratio_label(res: Vector2i) -> String:
	if res.x <= 0 or res.y <= 0:
		return "16:9"
	var ratio: float = float(res.x) / float(res.y)
	if is_equal_approx(ratio, 16.0 / 9.0) or absf(ratio - (16.0 / 9.0)) < 0.02:
		return "16:9"
	if is_equal_approx(ratio, 16.0 / 10.0) or absf(ratio - (16.0 / 10.0)) < 0.02:
		return "16:10"
	if absf(ratio - (21.0 / 9.0)) < 0.06:
		return "21:9"
	if is_equal_approx(ratio, 4.0 / 3.0) or absf(ratio - (4.0 / 3.0)) < 0.02:
		return "4:3"
	if absf(ratio - (32.0 / 9.0)) < 0.06:
		return "32:9"
	if is_equal_approx(ratio, 3.0 / 2.0) or absf(ratio - 1.5) < 0.02:
		return "3:2"
	if is_equal_approx(ratio, 5.0 / 4.0) or absf(ratio - 1.25) < 0.02:
		return "5:4"

	var divisor: int = _gcd(res.x, res.y)
	var ratio_w: int = roundi(float(res.x) / float(divisor))
	var ratio_h: int = roundi(float(res.y) / float(divisor))
	return "%d:%d" % [ratio_w, ratio_h]


## Returns the numeric width/height aspect ratio for an aspect ratio label.
static func get_aspect_ratio_value(aspect_label: String) -> float:
	match aspect_label:
		"16:9":
			return 16.0 / 9.0
		"16:10":
			return 16.0 / 10.0
		"21:9":
			return 21.0 / 9.0
		"4:3":
			return 4.0 / 3.0
		"32:9":
			return 32.0 / 9.0
		"3:2":
			return 3.0 / 2.0
		"5:4":
			return 5.0 / 4.0
		_:
			var parts: PackedStringArray = aspect_label.split(":")
			if parts.size() == 2:
				var w: float = parts[0].to_float()
				var h: float = parts[1].to_float()
				if w > 0.0 and h > 0.0:
					return w / h
			return 16.0 / 9.0


## Returns all resolutions supported by the machine (width <= screen.x and height <= screen.y),
## sorted ascending by width then height, and guaranteed to include the machine's native resolution.
static func get_supported_resolutions(max_screen_size: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var screen_size: Vector2i = max_screen_size if (max_screen_size.x > 0 and max_screen_size.y > 0) else get_machine_screen_size()
	var results: Array[Vector2i] = []

	for candidate: Vector2i in CANDIDATE_RESOLUTIONS:
		if candidate.x <= screen_size.x and candidate.y <= screen_size.y:
			if not results.has(candidate):
				results.append(candidate)

	if screen_size.x > 0 and screen_size.y > 0 and not results.has(screen_size):
		results.append(screen_size)

	if results.is_empty():
		results.append(Vector2i(1152, 648))

	results.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)
	return results


## Returns the distinct aspect ratio labels supported by the machine's available resolutions.
static func get_supported_aspect_ratios(max_screen_size: Vector2i = Vector2i.ZERO) -> PackedStringArray:
	var supported_res: Array[Vector2i] = get_supported_resolutions(max_screen_size)
	var preferred_order: Array[String] = ["16:9", "16:10", "21:9", "4:3", "32:9", "3:2", "5:4"]
	var found: Dictionary = {}
	for res: Vector2i in supported_res:
		var label: String = get_aspect_ratio_label(res)
		found[label] = true

	var ordered: PackedStringArray = PackedStringArray()
	for pref: String in preferred_order:
		if found.has(pref):
			ordered.append(pref)
			found.erase(pref)
	for extra: String in found.keys():
		ordered.append(extra)
	return ordered


## Filters machine-supported resolutions by the given aspect ratio label.
static func get_resolutions_for_aspect_ratio(aspect_label: String, max_screen_size: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var all_supported: Array[Vector2i] = get_supported_resolutions(max_screen_size)
	if aspect_label.is_empty() or aspect_label == "All":
		return all_supported

	var filtered: Array[Vector2i] = []
	for res: Vector2i in all_supported:
		if get_aspect_ratio_label(res) == aspect_label:
			filtered.append(res)
	return filtered


## Formats a resolution for UI display (e.g. "1920 x 1080").
static func format_resolution(res: Vector2i) -> String:
	return "%d x %d" % [res.x, res.y]


## Returns the display label for a WindowMode value.
static func get_window_mode_label(mode: int) -> String:
	match mode:
		WindowMode.FULLSCREEN:
			return "Fullscreen"
		WindowMode.WINDOWED:
			return "Windowed"
		WindowMode.WINDOWED_BORDERLESS:
			return "Windowed Borderless"
		_:
			return "Windowed"


## Returns all PC window modes in display order.
static func get_window_modes() -> Array[int]:
	return [
		WindowMode.FULLSCREEN,
		WindowMode.WINDOWED,
		WindowMode.WINDOWED_BORDERLESS,
	]


## Creates a dictionary snapshot of the current display settings for revert/confirmation.
func to_snapshot() -> Dictionary:
	return {
		"resolution": current_resolution,
		"aspect_ratio": current_aspect_ratio,
		"window_mode": current_window_mode,
	}


## Restores settings from a snapshot dictionary created by to_snapshot().
func restore_snapshot(snapshot: Dictionary) -> void:
	if snapshot.has("resolution") and snapshot["resolution"] is Vector2i:
		current_resolution = snapshot["resolution"] as Vector2i
	if snapshot.has("aspect_ratio"):
		current_aspect_ratio = String(snapshot["aspect_ratio"])
	if snapshot.has("window_mode"):
		current_window_mode = int(snapshot["window_mode"])


## Returns true if the current settings match the given snapshot.
func equals_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	return (
		current_resolution == (snapshot.get("resolution", Vector2i.ZERO) as Vector2i)
		and current_aspect_ratio == String(snapshot.get("aspect_ratio", ""))
		and current_window_mode == int(snapshot.get("window_mode", -1))
	)


## Initializes settings from disk (if saved) or from current window/machine defaults.
func load_or_detect(max_screen_size: Vector2i = Vector2i.ZERO) -> void:
	var supported: Array[Vector2i] = get_supported_resolutions(max_screen_size)
	var default_res: Vector2i = Vector2i(1152, 648)
	if not supported.has(default_res) and not supported.is_empty():
		default_res = supported[supported.size() - 1]

	current_resolution = default_res
	current_aspect_ratio = get_aspect_ratio_label(current_resolution)
	current_window_mode = WindowMode.WINDOWED

	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		var saved_w: int = int(cfg.get_value(CONFIG_SECTION, "width", current_resolution.x))
		var saved_h: int = int(cfg.get_value(CONFIG_SECTION, "height", current_resolution.y))
		var candidate := Vector2i(saved_w, saved_h)
		if supported.has(candidate):
			current_resolution = candidate
		var saved_aspect: String = String(cfg.get_value(CONFIG_SECTION, "aspect_ratio", get_aspect_ratio_label(current_resolution)))
		var avail_aspects: PackedStringArray = get_supported_aspect_ratios(max_screen_size)
		if avail_aspects.has(saved_aspect):
			current_aspect_ratio = saved_aspect
		else:
			current_aspect_ratio = get_aspect_ratio_label(current_resolution)
		var saved_mode: int = int(cfg.get_value(CONFIG_SECTION, "window_mode", current_window_mode))
		if saved_mode in [WindowMode.FULLSCREEN, WindowMode.WINDOWED, WindowMode.WINDOWED_BORDERLESS]:
			current_window_mode = saved_mode


## Saves the current display settings to user://display_settings.cfg.
func save_settings() -> int:
	var cfg := ConfigFile.new()
	cfg.set_value(CONFIG_SECTION, "width", current_resolution.x)
	cfg.set_value(CONFIG_SECTION, "height", current_resolution.y)
	cfg.set_value(CONFIG_SECTION, "aspect_ratio", current_aspect_ratio)
	cfg.set_value(CONFIG_SECTION, "window_mode", current_window_mode)
	return cfg.save(save_path)


## Sets the aspect ratio and ensures current_resolution matches the chosen aspect ratio.
func set_aspect_ratio(aspect_label: String, max_screen_size: Vector2i = Vector2i.ZERO) -> void:
	current_aspect_ratio = aspect_label
	var matching: Array[Vector2i] = get_resolutions_for_aspect_ratio(aspect_label, max_screen_size)
	if not matching.is_empty() and not matching.has(current_resolution):
		# Pick the resolution in the new aspect ratio closest in width to current_resolution
		var best: Vector2i = matching[matching.size() - 1]
		var best_diff: int = absi(best.x - current_resolution.x)
		for res: Vector2i in matching:
			var diff: int = absi(res.x - current_resolution.x)
			if diff < best_diff:
				best = res
				best_diff = diff
		current_resolution = best


## Sets the target resolution and updates current_aspect_ratio to match.
func set_resolution(res: Vector2i) -> void:
	if res.x <= 0 or res.y <= 0:
		return
	current_resolution = res
	current_aspect_ratio = get_aspect_ratio_label(res)


## Sets the window mode.
func set_window_mode(mode: int) -> void:
	if mode in [WindowMode.FULLSCREEN, WindowMode.WINDOWED, WindowMode.WINDOWED_BORDERLESS]:
		current_window_mode = mode


## Effective UI scale for a window of [param window_size]: the design base
## stretched by its height, clamped to [UI_MIN_SCALE, UI_MAX_SCALE] so the HUD
## stays consistent and bounded across every resolution and window mode.
static func compute_ui_scale(window_size: Vector2i) -> float:
	if window_size.y <= 0:
		return UI_MIN_SCALE
	return clampf(float(window_size.y) / float(UI_BASE_SIZE.y), UI_MIN_SCALE, UI_MAX_SCALE)


## The Window.content_scale_size (Control layout space) that yields
## compute_ui_scale() for a window of [param window_size]: the window size
## divided by its clamped scale. Keeping the base aspect equal to the window's
## means "keep" aspect introduces no letterboxing.
static func compute_content_scale_size(window_size: Vector2i) -> Vector2i:
	var scale: float = compute_ui_scale(window_size)
	return Vector2i(
		maxi(1, roundi(float(window_size.x) / scale)),
		maxi(1, roundi(float(window_size.y) / scale))
	)


## Applies the bounded, consistent canvas_items scaling to [param root_window]
## for its CURRENT size. Safe to call on every window resize: the UI scale is
## derived from the real window size, never from a possibly-mismatched
## resolution, so windows/banners can no longer grow to fill the screen.
static func apply_bounded_ui_scale(root_window: Window) -> void:
	if root_window == null:
		return
	var size: Vector2i = root_window.size
	if size.x <= 0 or size.y <= 0:
		return
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root_window.content_scale_size = compute_content_scale_size(size)


## Applies the current resolution, aspect ratio, and window mode to the root window / DisplayServer.
func apply_to_window(root_window: Window = null, persist: bool = true) -> void:
	if root_window != null:
		# UI scaling is derived from the size the window will actually have, so it
		# stays bounded whether the player picks a resolution or goes fullscreen on a
		# larger monitor. The autoloaded UiScale controller re-applies this on resize.
		var target_size: Vector2i = current_resolution
		if current_window_mode == WindowMode.FULLSCREEN and DisplayServer.get_name() != "headless":
			var screen_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
			if screen_size.x > 0 and screen_size.y > 0:
				target_size = screen_size
		root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root_window.content_scale_size = compute_content_scale_size(target_size)

	if DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor():
		if not is_steam_deck():
			match current_window_mode:
				WindowMode.FULLSCREEN:
					DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
					DisplayServer.window_set_size(current_resolution)
				WindowMode.WINDOWED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
					DisplayServer.window_set_size(current_resolution)
					_center_window_on_screen(current_resolution)
				WindowMode.WINDOWED_BORDERLESS:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
					DisplayServer.window_set_size(current_resolution)
					_center_window_on_screen(current_resolution)
		else:
			DisplayServer.window_set_size(current_resolution)

	if persist:
		save_settings()


static func _center_window_on_screen(win_size: Vector2i) -> void:
	var screen_idx: int = DisplayServer.window_get_current_screen()
	var screen_pos: Vector2i = DisplayServer.screen_get_position(screen_idx)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_idx)
	if screen_size.x > 0 and screen_size.y > 0:
		var offset := Vector2i(
			roundi(float(screen_size.x - win_size.x) * 0.5),
			roundi(float(screen_size.y - win_size.y) * 0.5)
		)
		DisplayServer.window_set_position(screen_pos + offset)


static func _gcd(a: int, b: int) -> int:
	var x: int = absi(a)
	var y: int = absi(b)
	while y != 0:
		var t: int = y
		y = x % y
		x = t
	return maxi(1, x)
