class_name ColoringPicture
extends RefCounted

## A coloring picture in its own SIZE space: paintable regions and fixed decorations, in drawing order
## (later shapes are drawn on top). Shapes are polygons; curves are pre-sampled when the picture is built.

const SIZE := Vector2(400, 320)
const OUTLINE_COLOR := Color8(0x5b, 0x5b, 0x5b)
const INK_COLOR := Color8(0x44, 0x44, 0x44)
const OUTLINE_WIDTH := 5.0


## One thing to draw. A region (region >= 0) is filled with its current colour and optionally outlined;
## a decoration is drawn with its own fill and/or stroke and can't be tapped.
class Shape:
	var points: PackedVector2Array
	var region := -1
	var fill := Color.TRANSPARENT
	var stroke := Color.TRANSPARENT
	var width := 0.0
	## Points of the stroke; the first point is repeated for closed shapes.
	var stroke_points: PackedVector2Array


var shapes: Array[Shape] = []
var region_count := 0


func add_region(points: PackedVector2Array, outlined := true) -> void:
	var shape := _closed(points, OUTLINE_COLOR if outlined else Color.TRANSPARENT, OUTLINE_WIDTH)
	shape.region = region_count
	region_count += 1
	shapes.append(shape)


## Filled decoration, e.g. an eye dot; `stroke` is optional.
func add_decor(points: PackedVector2Array, fill: Color, stroke := Color.TRANSPARENT, width := 0.0) -> void:
	var shape := _closed(points, stroke, width)
	shape.fill = fill
	shapes.append(shape)


## Open line decoration, e.g. a sun ray or a smile.
func add_line(points: PackedVector2Array, stroke := OUTLINE_COLOR, width := OUTLINE_WIDTH) -> void:
	var shape := Shape.new()
	shape.points = points
	shape.stroke = stroke
	shape.width = width
	shape.stroke_points = points
	shapes.append(shape)


## Top-most region containing `point`, or -1. O(shapes × points), only on taps.
func region_at(point: Vector2) -> int:
	for i in range(shapes.size() - 1, -1, -1):
		var shape := shapes[i]
		if shape.region >= 0 and Geometry2D.is_point_in_polygon(point, shape.points):
			return shape.region
	return -1


static func _closed(points: PackedVector2Array, stroke: Color, width: float) -> Shape:
	var shape := Shape.new()
	shape.points = points
	shape.stroke = stroke
	shape.width = width
	shape.stroke_points = points.duplicate()
	shape.stroke_points.append(points[0])
	return shape
