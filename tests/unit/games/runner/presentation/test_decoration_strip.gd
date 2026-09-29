extends GutTest

const TEXTURES: Array[Texture2D] = [
	preload("res://assets/runner/backgrounds/decorations/grass_01.png"),
	preload("res://assets/runner/backgrounds/decorations/grass_08.png"),
	preload("res://assets/runner/backgrounds/decorations/flower_02.png"),
]
const SCREEN_WIDTH := 800.0
const PIXEL_SCALE := 2.0

var strip: DecorationStrip
var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 11
	strip = _make_strip(rng)


func _make_strip(strip_rng: RandomNumberGenerator) -> DecorationStrip:
	var made := DecorationStrip.new()
	made.textures = TEXTURES
	made.scroll_factor = 0.5
	made.min_gap = 10.0
	made.max_gap = 60.0
	made.base_scale = 0.75
	made.size_variance = 0.2
	made.depth_jitter = 5.0
	add_child_autofree(made)
	made.setup(strip_rng)
	made.fit(PIXEL_SCALE, SCREEN_WIDTH)
	return made


func _sprites() -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	for child in strip.get_children():
		sprites.append(child)
	return sprites


func _rightmost_edge() -> float:
	var edge := -INF
	for sprite in _sprites():
		edge = maxf(edge, DecorationStrip._right_edge(sprite))
	return edge


## Items never run out on the right, and every item that left on the left has been recycled.
func _assert_covers_screen(distance: float) -> void:
	var left := distance * strip.scroll_factor / PIXEL_SCALE
	assert_gte(_rightmost_edge(), left + SCREEN_WIDTH / PIXEL_SCALE, "ran out at right edge after %.0f px" % distance)
	for sprite in _sprites():
		assert_gte(DecorationStrip._right_edge(sprite), left, "sprite not recycled after %.0f px" % distance)


func test_fit_scales_strip() -> void:
	assert_eq(strip.scale, Vector2(PIXEL_SCALE, PIXEL_SCALE))


func test_fit_fills_the_screen() -> void:
	assert_gt(_sprites().size(), 0)
	_assert_covers_screen(0.0)


func test_items_use_given_textures_and_stand_on_the_line() -> void:
	for sprite in _sprites():
		assert_has(TEXTURES, sprite.texture)
		assert_eq(sprite.offset, Vector2(0.0, -sprite.texture.get_height()))
		assert_between(sprite.position.y, 0.0, strip.depth_jitter)


func test_items_are_scaled_within_variance() -> void:
	for sprite in _sprites():
		assert_between(sprite.scale.x, 0.75 * 0.8, 0.75 * 1.2)


func test_neighbours_keep_gap() -> void:
	var sprites := _sprites()
	for i in range(1, sprites.size()):
		var gap := sprites[i].position.x - DecorationStrip._right_edge(sprites[i - 1])
		assert_between(gap, strip.min_gap, strip.max_gap)


func test_layout_is_random() -> void:
	var textures := {}
	var flips := {}
	for i in 20:
		strip.reset()
		for sprite in _sprites():
			textures[sprite.texture] = true
			flips[sprite.flip_h] = true

	assert_eq(textures.size(), TEXTURES.size())
	assert_eq(flips.size(), 2)


func test_same_seed_gives_same_layout() -> void:
	var other_rng := RandomNumberGenerator.new()
	other_rng.seed = 11
	var other := _make_strip(other_rng)

	for i in _sprites().size():
		assert_eq(other.get_child(i).texture, _sprites()[i].texture)
		assert_eq(other.get_child(i).position, _sprites()[i].position)


func test_scroll_moves_by_factor() -> void:
	strip.scroll(100.0)

	assert_almost_eq(strip.position.x, -100.0 * strip.scroll_factor, 0.0001)


func test_long_scroll_keeps_screen_covered_without_new_sprites() -> void:
	var pool_size := _sprites().size()

	for step in 500:
		var distance := step * 37.0
		strip.scroll(distance)
		_assert_covers_screen(distance)

	assert_eq(_sprites().size(), pool_size)


func test_reset_starts_over_from_zero() -> void:
	strip.scroll(20000.0)

	strip.reset()

	assert_eq(strip.position.x, 0.0)
	_assert_covers_screen(0.0)


func test_refit_keeps_current_scroll_position() -> void:
	strip.scroll(20000.0)

	strip.fit(PIXEL_SCALE, SCREEN_WIDTH)

	_assert_covers_screen(20000.0)


func test_wider_screen_grows_pool_once() -> void:
	var small_pool := _sprites().size()

	strip.fit(PIXEL_SCALE, SCREEN_WIDTH * 3.0)
	var big_pool := _sprites().size()
	strip.fit(PIXEL_SCALE, SCREEN_WIDTH)

	assert_gt(big_pool, small_pool)
	assert_eq(_sprites().size(), big_pool)
