## Tests for the responsive TopBar fit.
##
## The HUD is authored against a base 1152x648 with a KEEP-aspect canvas scale derived from
## window height, so the layout width handed to the HUD is exactly `648 * aspect`:
##   1152 at 16:9, 1037 at 16:10, 864 at 4:3, 1512 at 21:9.
## The full top bar (with the Draw Rite button visible once a Rite is held) naturally needs
## ~1152 px, so at 16:10 and 4:3 the rightmost readouts used to spill off the right edge of the
## screen. The bar must instead COMPACT its fonts / separations / bar until the whole row fits
## on ONE line at every supported width -- this is the axis the old bug abused.
extends Node

const _TopBar = preload("res://scripts/ui/top_bar.gd")
const _DisplaySettings = preload("res://scripts/core/display_settings.gd")

## Worst-case readout content: long faction name, a Rite bank and the Draw Rite button visible,
## a raised Corruption cap (three digits), and multi-digit currency / interval values.
func _fill_worst_case(tb: TopBar) -> void:
	tb._lives_label.text = "Lives: 20/20"
	tb._wave_label.text = "Wave: 145 (Interval 29)"
	tb._faction_label.text = "[HOSTILE TAKEOVER]"
	tb._offerings_label.text = "12345"
	tb._scrap_label.text = "9999"
	tb._rites_label.text = "12"
	tb._corruption_label.text = "Corruption: 125/125"
	tb._penance_button.visible = true
	tb._attention_label.text = "Reckoning: +37"
	tb._draw_rite_button.text = "Draw Rite (10 Corruption)"
	tb._draw_rite_button.visible = true


func _fill_typical(tb: TopBar) -> void:
	tb._lives_label.text = "Lives: 20/20"
	tb._wave_label.text = "Wave: 3 (Interval 1)"
	tb._faction_label.text = "[SWARM SYNDICATE]"
	tb._offerings_label.text = "150"
	tb._scrap_label.text = "40"
	tb._rites_label.text = "0"
	tb._corruption_label.text = "Corruption: 0/100"
	tb._penance_button.visible = false
	tb._attention_label.text = "Reckoning: +0"
	tb._draw_rite_button.visible = false


func _make_bar() -> TopBar:
	var tb: TopBar = _TopBar.new()
	add_child(tb)
	return tb


## The pure rule: the layout width for a resolution is `648 * aspect`, matching the aspect set of
## supported resolutions (this is why 4:3/16:10 are the tight cases and 21:9 is roomy).
func test_layout_width_matches_supported_aspects() -> void:
	var cases := {
		Vector2i(1280, 720): 1152.0,   # 16:9  -> exactly the 1152 base width
		Vector2i(1280, 800): 1037.0,   # 16:10 -> tight
		Vector2i(1024, 768): 864.0,    # 4:3   -> the tightest supported width
		Vector2i(2560, 1080): 1536.0,  # ultrawide -> roomy
	}
	for res: Vector2i in cases.keys():
		var base: Vector2i = _DisplaySettings.compute_content_scale_size(res)
		assert(
			absi(base.x - int(cases[res])) <= 1,
			"Layout width for %s must be %d (got %d)" % [str(res), int(cases[res]), base.x]
		)


## Every element must stay on screen: the bar's natural width must never exceed the layout width
## at any supported resolution -- even with the Draw Rite button visible and long values.
func test_top_bar_always_fits_one_row_across_all_supported_aspects() -> void:
	var tb: TopBar = _make_bar()
	await get_tree().process_frame
	_fill_worst_case(tb)

	for width: float in [864.0, 1037.0, 1152.0, 1512.0, 1920.0]:
		tb.fit_width_override = width
		tb._apply_fit()
		var natural: float = tb.get_combined_minimum_size().x
		assert(
			natural <= width + 0.5,
			"Top bar must fit %d px (needs %.0f) -- an element would bleed off the screen" % [int(width), natural]
		)
	tb.queue_free()


## Widening must never push the bar off screen by leaving a stale shrink applied: at 21:9 / full
## width the bar is back at its base font, and at the tight 4:3 width it still fits.
func test_fit_is_idempotent_and_recovers_at_wide_widths() -> void:
	var tb: TopBar = _make_bar()
	await get_tree().process_frame
	_fill_worst_case(tb)

	tb.fit_width_override = 864.0
	tb._apply_fit()
	assert(tb.get_combined_minimum_size().x <= 864.5, "Bar must fit at 4:3")

	# Same width twice must be stable (no oscillation). The very first fit can be a pixel off
# while the container's lazy minimum-size measurement settles; it is stable from then on.
	var after_first: float = tb.get_combined_minimum_size().x
	tb._apply_fit()
	var after_second: float = tb.get_combined_minimum_size().x
	assert(
		absf(after_first - after_second) <= 1.0,
		"Refitting must be stable (got %.1f then %.1f)" % [after_first, after_second]
	)

	# Wide again -> base fonts restored, and it still fits.
	tb.fit_width_override = 1920.0
	tb._apply_fit()
	assert(
		tb._lives_label.get_theme_font_size("font_size") == 15,
		"At a roomy width the bar must return to its base font (no permanent shrink)"
	)
	assert(tb.get_combined_minimum_size().x <= 1920.5, "Bar must fit at 1920")
	tb.queue_free()


## A typical early-game row (no Rite, short values) must fit 4:3 WITHOUT aggressive shrinking, so
## the common case stays legible rather than always rendering tiny.
func test_typical_row_stays_legible_at_4_3() -> void:
	var tb: TopBar = _make_bar()
	await get_tree().process_frame
	_fill_typical(tb)

	tb.fit_width_override = 864.0
	tb._apply_fit()
	assert(tb.get_combined_minimum_size().x <= 864.5, "Typical row must fit at 4:3")
	assert(
		tb._lives_label.get_theme_font_size("font_size") >= 12,
		"The common case must not be shrunk below a legible size (got %d)"
		% tb._lives_label.get_theme_font_size("font_size")
	)
	tb.queue_free()