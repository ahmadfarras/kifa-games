class_name RunnerBackground
extends Node2D

## Parallax scenery for the Runner. Art is laid out in "art pixels" (the source pack at half size,
## ART_HEIGHT tall); fit() scales it so the art always fills the screen height.

const ART_HEIGHT := 773.0
const SAND_TOP := 577.0
const GROUND_TOP := 602.0
# Runners and obstacles stand a little below the ground's top edge so they look planted on it.
const GROUND_LINE := 612.0

var _pixel_scale := 1.0
var _layers: Array[ScrollingLayer] = []

@onready var _sand: ColorRect = $Sand
@onready var _trees: DecorationStrip = $Trees
@onready var _plants: DecorationStrip = $Plants


func _ready() -> void:
	for child in get_children():
		if child is ScrollingLayer:
			_layers.append(child)


func setup(rng: RandomNumberGenerator) -> void:
	_trees.setup(rng)
	_plants.setup(rng)


func fit(screen: Vector2) -> void:
	_pixel_scale = screen.y / ART_HEIGHT
	for layer in _layers:
		layer.fit(_pixel_scale, screen.x)
	_sand.position = Vector2(0.0, SAND_TOP * _pixel_scale)
	_sand.size = Vector2(screen.x, (GROUND_TOP - SAND_TOP) * _pixel_scale + 1.0)
	_trees.position.y = GROUND_TOP * _pixel_scale
	_trees.fit(_pixel_scale, screen.x)
	_plants.position.y = GROUND_LINE * _pixel_scale
	_plants.fit(_pixel_scale, screen.x)


func ground_y() -> float:
	return GROUND_LINE * _pixel_scale


func reset() -> void:
	_trees.reset()
	_plants.reset()
	scroll(0.0)


func scroll(distance: float) -> void:
	for layer in _layers:
		layer.scroll(distance)
	_trees.scroll(distance)
	_plants.scroll(distance)
