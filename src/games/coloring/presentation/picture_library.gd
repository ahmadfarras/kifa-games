class_name PictureLibrary
extends RefCounted

## The coloring pictures, ported shape by shape from the original SVG line art (400x320).
## Add a picture = add its id, icon and a builder function.

const IDS: Array[StringName] = [&"butterfly", &"fish", &"house", &"flower"]
const ICONS: Array[String] = ["🦋", "🐟", "🏠", "🌷"]
const CURVE_STEPS := 12
const ROUND_STEPS := 48
const CORNER_STEPS := 6


static func build(id: StringName) -> ColoringPicture:
	match id:
		&"butterfly":
			return _butterfly()
		&"fish":
			return _fish()
		&"house":
			return _house()
		&"flower":
			return _flower()
	assert(false, "unknown picture %s" % id)
	return null


static func rect(x: float, y: float, w: float, h: float, radius := 0.0) -> PackedVector2Array:
	if radius <= 0.0:
		return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	var points := PackedVector2Array()
	var corners := [Vector2(x + w - radius, y + radius), Vector2(x + w - radius, y + h - radius),
		Vector2(x + radius, y + h - radius), Vector2(x + radius, y + radius)]
	for c in corners.size():
		var start := -PI / 2.0 + c * PI / 2.0
		for step in CORNER_STEPS + 1:
			points.append(corners[c] + Vector2.from_angle(start + step * PI / 2.0 / CORNER_STEPS) * radius)
	return points


static func circle(cx: float, cy: float, r: float) -> PackedVector2Array:
	return ellipse(cx, cy, r, r)


## Like SVG `rotate(degrees pivot)`: the ellipse is turned around `pivot` (its own centre by default).
static func ellipse(cx: float, cy: float, rx: float, ry: float, degrees := 0.0, pivot := Vector2.INF) -> PackedVector2Array:
	var center := Vector2(cx, cy)
	var around := center if pivot == Vector2.INF else pivot
	var angle := deg_to_rad(degrees)
	var points := PackedVector2Array()
	for step in ROUND_STEPS:
		var t := TAU * step / ROUND_STEPS
		var point := center + Vector2(cos(t) * rx, sin(t) * ry)
		points.append(around + (point - around).rotated(angle))
	return points


static func line(x1: float, y1: float, x2: float, y2: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x1, y1), Vector2(x2, y2)])


## Minimal SVG path parser: absolute M, L, Q and Z only (all the original art uses).
static func path(d: String) -> PackedVector2Array:
	var tokens := _tokens(d)
	var points := PackedVector2Array()
	var i := 0
	while i < tokens.size():
		var command := tokens[i]
		i += 1
		match command:
			"M", "L":
				points.append(Vector2(float(tokens[i]), float(tokens[i + 1])))
				i += 2
			"Q":
				var control := Vector2(float(tokens[i]), float(tokens[i + 1]))
				var end := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
				var start := points[-1]
				for step in range(1, CURVE_STEPS + 1):
					var t := float(step) / CURVE_STEPS
					points.append(start.lerp(control, t).lerp(control.lerp(end, t), t))
				i += 4
	return points


static func _tokens(d: String) -> PackedStringArray:
	var regex := RegEx.create_from_string("[MLQZ]|-?\\d+(?:\\.\\d+)?")
	var tokens := PackedStringArray()
	for found in regex.search_all(d):
		tokens.append(found.get_string())
	return tokens


static func _sun_rays(picture: ColoringPicture, rays: Array) -> void:
	for ray: Array in rays:
		picture.add_line(line(ray[0], ray[1], ray[2], ray[3]))


static func _butterfly() -> ColoringPicture:
	var p := ColoringPicture.new()
	p.add_region(rect(0, 0, 400, 320), false)
	p.add_region(circle(345, 48, 28))
	_sun_rays(p, [[345, 5, 345, 14], [308, 48, 316, 48], [374, 48, 384, 48], [318, 21, 324, 27], [366, 69, 372, 75], [372, 21, 366, 27]])
	p.add_region(ellipse(135, 125, 68, 52, -25))
	p.add_region(ellipse(265, 125, 68, 52, 25))
	p.add_region(ellipse(148, 215, 52, 44, 20))
	p.add_region(ellipse(252, 215, 52, 44, -20))
	p.add_region(circle(120, 115, 14))
	p.add_region(circle(280, 115, 14))
	p.add_region(ellipse(200, 175, 17, 62))
	p.add_region(circle(200, 95, 21))
	p.add_line(path("M190 78 Q174 55 164 45"))
	p.add_line(path("M210 78 Q226 55 236 45"))
	for dot: Array in [[163, 44, 5], [237, 44, 5], [193, 92, 3.5], [207, 92, 3.5]]:
		p.add_decor(circle(dot[0], dot[1], dot[2]), ColoringPicture.INK_COLOR)
	p.add_line(path("M193 102 Q200 108 207 102"), ColoringPicture.INK_COLOR, 3.0)
	return p


static func _fish() -> ColoringPicture:
	var p := ColoringPicture.new()
	p.add_region(rect(0, 0, 400, 320), false)
	p.add_region(path("M0 292 Q100 272 200 292 Q300 312 400 290 L400 320 L0 320 Z"))
	p.add_region(path("M355 320 Q340 255 362 215 Q374 258 368 320 Z"))
	p.add_region(path("M265 160 L332 112 L332 208 Z"))
	p.add_region(path("M138 116 Q180 62 222 112 Z"))
	p.add_region(ellipse(180, 162, 92, 56))
	p.add_region(ellipse(185, 190, 28, 15, -25))
	p.add_region(circle(90, 80, 15))
	p.add_region(circle(60, 48, 10))
	p.add_region(circle(112, 42, 8))
	p.add_decor(circle(130, 145, 11), Color.WHITE, ColoringPicture.OUTLINE_COLOR, 4.0)
	p.add_decor(circle(130, 145, 4.5), ColoringPicture.INK_COLOR)
	p.add_line(path("M98 175 Q106 182 114 176"), ColoringPicture.INK_COLOR, 3.0)
	return p


static func _house() -> ColoringPicture:
	var p := ColoringPicture.new()
	p.add_region(rect(0, 0, 400, 320), false)
	p.add_region(path("M0 268 Q100 252 200 266 Q300 280 400 264 L400 320 L0 320 Z"))
	p.add_region(circle(52, 50, 27))
	_sun_rays(p, [[52, 8, 52, 16], [16, 50, 24, 50], [80, 50, 88, 50], [27, 24, 33, 30], [71, 70, 77, 76], [77, 24, 71, 30]])
	p.add_region(ellipse(315, 55, 46, 22))
	p.add_region(circle(344, 192, 40))
	p.add_region(rect(335, 222, 18, 52, 6))
	p.add_region(rect(110, 140, 180, 122, 4))
	p.add_region(path("M92 140 L200 58 L308 140 Z"))
	p.add_region(rect(178, 192, 46, 70, 6))
	p.add_region(rect(128, 160, 38, 38, 4))
	p.add_region(rect(234, 160, 38, 38, 4))
	for bar: Array in [[147, 160, 147, 198], [128, 179, 166, 179], [253, 160, 253, 198], [234, 179, 272, 179]]:
		p.add_line(line(bar[0], bar[1], bar[2], bar[3]), ColoringPicture.OUTLINE_COLOR, 3.0)
	p.add_decor(circle(213, 228, 4), ColoringPicture.INK_COLOR)
	return p


static func _flower() -> ColoringPicture:
	var p := ColoringPicture.new()
	p.add_region(rect(0, 0, 400, 320), false)
	p.add_region(path("M0 272 Q100 256 200 270 Q300 284 400 268 L400 320 L0 320 Z"))
	p.add_region(circle(345, 50, 27))
	_sun_rays(p, [[345, 8, 345, 16], [309, 50, 317, 50], [373, 50, 381, 50], [320, 24, 326, 30], [364, 70, 370, 76], [370, 24, 364, 30]])
	p.add_region(ellipse(60, 60, 42, 20))
	for degrees in [0, 60, 120, 180, 240, 300]:
		p.add_region(ellipse(200, 93, 23, 42, degrees, Vector2(200, 140)))
	p.add_region(rect(193, 185, 14, 95, 7))
	p.add_region(ellipse(160, 238, 30, 14, -30))
	p.add_region(ellipse(240, 238, 30, 14, 30))
	p.add_region(circle(200, 140, 27))
	for dot: Array in [[193, 136, 3], [207, 136, 3]]:
		p.add_decor(circle(dot[0], dot[1], dot[2]), ColoringPicture.INK_COLOR)
	p.add_line(path("M192 147 Q200 154 208 147"), ColoringPicture.INK_COLOR, 3.0)
	return p
