class_name CardView
extends Button

## One card on screen: shows the back or the face picture. Flips, celebrates and wobbles with short tweens.
## Only one tween runs per card, so animations never fight over the same property.

const BACK_TEXT := "❓"
const FACE_FONT_RATIO := 0.55
const BACK_FONT_RATIO := 0.42
const CELEBRATE_SCALE := Vector2(1.18, 1.18)
const WOBBLE_DEGREES := 6.0
## Half a flip: the card narrows to nothing, swaps side, then widens again.
const FLIP_SECONDS := 0.12

@export var back_style: StyleBox
@export var front_style: StyleBox
@export var matched_style: StyleBox
## Multiplies the speed of every card animation (tests use a large value).
@export var animation_speed := 1.0

var face_text := ""
var shows_face := false
var shows_matched := false

var _size := 100.0
var _tween: Tween


func setup(face: String, size: float) -> void:
	face_text = face
	shows_face = false
	shows_matched = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _tween != null:
		_tween.kill()
	scale = Vector2.ONE
	rotation = 0.0
	resize(size)
	_draw_side()


func resize(size: float) -> void:
	_size = size
	custom_minimum_size = Vector2.ONE * size
	pivot_offset = custom_minimum_size * 0.5
	_draw_side()


func turn_up() -> void:
	_flip_to(true)


func turn_down() -> void:
	_flip_to(false)


func celebrate() -> void:
	shows_matched = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := _animate()
	tween.tween_callback(_draw_side)
	tween.tween_property(self, "scale", CELEBRATE_SCALE, 0.15)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25)


func wobble() -> void:
	var tween := _animate()
	for degrees in [-WOBBLE_DEGREES, WOBBLE_DEGREES, 0.0]:
		tween.tween_property(self, "rotation", deg_to_rad(degrees), 0.1)


func _flip_to(face_up: bool) -> void:
	shows_face = face_up
	var tween := _animate()
	tween.tween_property(self, "scale:x", 0.0, FLIP_SECONDS)
	tween.tween_callback(_draw_side)
	tween.tween_property(self, "scale:x", 1.0, FLIP_SECONDS)


## Returns the tween to add animation steps to. Steps requested in the same frame queue up on one tween
## (e.g. flip then celebrate). Godot can't append to a tween that already started, so a running animation
## is jumped to its end state and a new tween starts.
func _animate() -> Tween:
	if _tween != null and _tween.is_running():
		if _tween.get_total_elapsed_time() == 0.0:
			return _tween
		_finish_now()
	_tween = create_tween().set_speed_scale(animation_speed)
	return _tween


func _finish_now() -> void:
	_tween.kill()
	scale = Vector2.ONE
	rotation = 0.0
	_draw_side()


func _draw_side() -> void:
	text = face_text if shows_face else BACK_TEXT
	var ratio := FACE_FONT_RATIO if shows_face else BACK_FONT_RATIO
	add_theme_font_size_override("font_size", maxi(1, int(_size * ratio)))
	var style := back_style
	if shows_matched:
		style = matched_style
	elif shows_face:
		style = front_style
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, style)
