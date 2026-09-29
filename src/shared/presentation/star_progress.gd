class_name StarProgress
extends HBoxContainer

## Row of stars, one per goal, lit one by one as the kid succeeds. Star labels are reused between rounds.

const OFF := Color(0.6, 0.6, 0.6, 0.35)
const POP_SCALE := Vector2(1.5, 1.5)

@export var star_size := 40

var _stars: Array[Label] = []
var _count := 0
var _lit := 0


func reset(count: int) -> void:
	while _stars.size() < count:
		var star := Label.new()
		star.text = "⭐"
		star.add_theme_font_size_override("font_size", star_size)
		add_child(star)
		_stars.append(star)
	for i in _stars.size():
		_stars[i].visible = i < count
		_stars[i].modulate = OFF
		_stars[i].scale = Vector2.ONE
	_count = count
	_lit = 0


func light_next() -> void:
	if _lit >= _count:
		return
	var star := _stars[_lit]
	_lit += 1
	star.modulate = Color.WHITE
	star.pivot_offset = star.size * 0.5
	var tween := star.create_tween()
	tween.tween_property(star, "scale", POP_SCALE, 0.2)
	tween.tween_property(star, "scale", Vector2.ONE, 0.25)


func lit_count() -> int:
	return _lit
