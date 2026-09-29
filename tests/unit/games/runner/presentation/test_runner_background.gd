extends GutTest

const BackgroundScene := preload("res://src/games/runner/presentation/runner_background.tscn")
const SCREEN := Vector2(1280.0, 720.0)

var background: RunnerBackground


func before_each() -> void:
	background = BackgroundScene.instantiate()
	add_child_autofree(background)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	background.setup(rng)
	background.fit(SCREEN)


func _scale() -> float:
	return SCREEN.y / RunnerBackground.ART_HEIGHT


func _layers() -> Array[ScrollingLayer]:
	var layers: Array[ScrollingLayer] = []
	for child in background.get_children():
		if child is ScrollingLayer:
			layers.append(child)
	return layers


func test_has_parallax_layers_from_far_to_near() -> void:
	var factors := []
	for layer in _layers():
		factors.append(layer.scroll_factor)

	assert_eq(factors.size(), 5)
	var sorted := factors.duplicate()
	sorted.sort()
	assert_eq(factors, sorted)
	assert_eq(factors[-1], 1.0)


func test_fit_scales_art_to_screen_height() -> void:
	for layer in _layers():
		assert_almost_eq(layer.scale.x, _scale(), 0.0001)
		assert_almost_eq(layer.position.y, layer.art_top * _scale(), 0.0001)


func test_ground_layer_reaches_bottom_of_screen() -> void:
	var ground: ScrollingLayer = background.get_node("Ground")

	assert_almost_eq(ground.position.y + ground.texture.get_height() * ground.scale.y, SCREEN.y, 1.0)


func test_ground_y_follows_art() -> void:
	assert_almost_eq(background.ground_y(), RunnerBackground.GROUND_LINE * _scale(), 0.0001)


func test_sand_band_spans_screen_between_trees_and_ground() -> void:
	var sand: ColorRect = background.get_node("Sand")

	assert_almost_eq(sand.position.y, RunnerBackground.SAND_TOP * _scale(), 0.0001)
	assert_gte(sand.position.y + sand.size.y, RunnerBackground.GROUND_TOP * _scale())
	assert_eq(sand.size.x, SCREEN.x)


func test_decorations_stand_on_their_lines() -> void:
	assert_almost_eq(background.get_node("Trees").position.y, RunnerBackground.GROUND_TOP * _scale(), 0.0001)
	assert_almost_eq(background.get_node("Plants").position.y, background.ground_y(), 0.0001)
	assert_gt(background.get_node("Trees").get_child_count(), 0)
	assert_gt(background.get_node("Plants").get_child_count(), 0)


func test_scroll_moves_every_layer() -> void:
	background.scroll(300.0)

	for layer in _layers():
		assert_gt(layer.region_rect.position.x, 0.0, layer.name)
	assert_lt(background.get_node("Trees").position.x, 0.0)
	assert_lt(background.get_node("Plants").position.x, 0.0)


func test_ground_scrolls_exactly_with_world() -> void:
	var ground: ScrollingLayer = background.get_node("Ground")

	background.scroll(300.0)

	assert_almost_eq(ground.region_rect.position.x * ground.scale.x, 300.0, 0.001)


func test_reset_returns_to_start() -> void:
	background.scroll(5000.0)

	background.reset()

	for layer in _layers():
		assert_eq(layer.region_rect.position.x, 0.0)
	assert_eq(background.get_node("Plants").position.x, 0.0)
