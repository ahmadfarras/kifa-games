class_name DecorationStrip
extends Node2D

## Randomly placed decorations (trees, grass, flowers) standing on a line and scrolling with the world.
## A fixed pool of sprites is recycled: a sprite that leaves the left edge jumps past the right-most one with a
## new random texture, gap, size and flip. Nothing is allocated while scrolling, and only the left-most sprite
## is checked each frame, so scroll() is O(1) amortized.

@export var textures: Array[Texture2D] = []
## 1 = moves with the ground, 0 = never moves.
@export_range(0.0, 1.0) var scroll_factor := 1.0
## Empty space between neighbours, in art pixels.
@export var min_gap := 20.0
@export var max_gap := 120.0
## Items are drawn at base_scale times a random factor in [1 - size_variance, 1 + size_variance].
@export var base_scale := 1.0
@export_range(0.0, 0.5) var size_variance := 0.0
## Each item's bottom is moved down by a random amount up to this, in art pixels, for a bit of depth.
@export var depth_jitter := 0.0

var _rng: RandomNumberGenerator
var _sprites: Array[Sprite2D] = []
var _first := 0
var _next_x := 0.0
var _view_width := 0.0
var _offset := 0.0


func setup(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Re-lays out the pool for a new screen size, starting at the current scroll position.
func fit(pixel_scale: float, screen_width: float) -> void:
	scale = Vector2.ONE * pixel_scale
	_view_width = screen_width / pixel_scale
	_ensure_pool()
	_scatter()


## New random layout from the start (a new run).
func reset() -> void:
	_offset = 0.0
	_scatter()


func scroll(distance: float) -> void:
	_offset = distance * scroll_factor / scale.x
	position.x = -_offset * scale.x
	while _right_edge(_sprites[_first]) < _offset:
		_place(_sprites[_first])
		_first = (_first + 1) % _sprites.size()


func _scatter() -> void:
	position.x = -_offset * scale.x
	_first = 0
	_next_x = _offset - _rng.randf_range(0.0, max_gap)
	for sprite in _sprites:
		_place(sprite)


func _ensure_pool() -> void:
	# Enough sprites that the right-most one is always past the screen edge, even if every item
	# is the narrowest texture with the smallest gap.
	var widest := 0.0
	var narrowest := INF
	for texture in textures:
		widest = maxf(widest, texture.get_width())
		narrowest = minf(narrowest, texture.get_width())
	var smallest_step := narrowest * base_scale * (1.0 - size_variance) + min_gap
	var needed := ceili((_view_width + widest * base_scale * (1.0 + size_variance)) / smallest_step) + 2
	while _sprites.size() < needed:
		var sprite := Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
		_sprites.append(sprite)


func _place(sprite: Sprite2D) -> void:
	var texture := textures[_rng.randi_range(0, textures.size() - 1)]
	var size := base_scale * (1.0 + _rng.randf_range(-size_variance, size_variance))
	sprite.texture = texture
	sprite.flip_h = _rng.randf() < 0.5
	sprite.scale = Vector2.ONE * size
	sprite.offset = Vector2(0.0, -texture.get_height())
	sprite.position = Vector2(_next_x, _rng.randf_range(0.0, depth_jitter))
	_next_x = _right_edge(sprite) + _rng.randf_range(min_gap, max_gap)


static func _right_edge(sprite: Sprite2D) -> float:
	return sprite.position.x + sprite.texture.get_width() * sprite.scale.x
