extends GutTest

const HILLS := preload("res://assets/runner/backgrounds/layers/hills.png")

var layer: ScrollingLayer


func before_each() -> void:
	layer = ScrollingLayer.new()
	layer.texture = HILLS
	layer.region_enabled = true
	layer.scroll_factor = 0.5
	layer.art_top = 100.0
	add_child_autofree(layer)


func test_fit_scales_and_places_by_art_top() -> void:
	layer.fit(2.0, 1000.0)

	assert_eq(layer.scale, Vector2(2.0, 2.0))
	assert_eq(layer.position.y, 200.0)


func test_fit_region_covers_screen_width() -> void:
	layer.fit(2.0, 1000.0)

	assert_eq(layer.region_rect.size, Vector2(500.0, HILLS.get_height()))


func test_scroll_moves_by_factor() -> void:
	layer.fit(2.0, 1000.0)

	layer.scroll(100.0)

	assert_almost_eq(layer.region_rect.position.x, 100.0 * 0.5 / 2.0, 0.0001)


func test_scroll_wraps_every_two_texture_widths() -> void:
	layer.fit(1.0, 1000.0)
	var period := HILLS.get_width() * 2.0 / layer.scroll_factor

	layer.scroll(period + 10.0)

	assert_almost_eq(layer.region_rect.position.x, 10.0 * layer.scroll_factor, 0.001)


func test_zero_factor_never_moves() -> void:
	layer.scroll_factor = 0.0
	layer.fit(1.0, 1000.0)

	layer.scroll(5000.0)

	assert_eq(layer.region_rect.position.x, 0.0)
