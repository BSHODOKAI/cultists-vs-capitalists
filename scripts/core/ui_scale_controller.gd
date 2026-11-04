## UiScaleController
##
## Keeps the whole UI on one consistent, bounded scale as the window changes size.
##
## The HUD (and every pop-up window and banner) is authored against
## DisplaySettings.UI_BASE_SIZE (1152x648). This controller stretches that base to
## the window height, clamps the resulting scale to
## [UI_MIN_SCALE, UI_MAX_SCALE], and applies it through the root Window's
## canvas_items scaling on every resize.
##
## Without it, content_scale_size was pinned to the chosen resolution while the
## window could actually be any size: the same monitor therefore produced a ~1x
## HUD (window size == resolution) or a ~3x HUD (fullscreen / maximized with a
## low saved resolution), so windows and alert banners ballooned to fill the
## screen with no relation to the player's intent. Deriving the base from the
## real window size makes the scale consistent and bounded everywhere.
class_name UiScaleController
extends Node

const _DisplaySettings = preload("res://scripts/core/display_settings.gd")


func _ready() -> void:
	var win: Window = get_window()
	if win == null:
		return
	if not win.size_changed.is_connected(_on_window_size_changed):
		win.size_changed.connect(_on_window_size_changed)
	_on_window_size_changed()


func _on_window_size_changed() -> void:
	_DisplaySettings.apply_bounded_ui_scale(get_window())