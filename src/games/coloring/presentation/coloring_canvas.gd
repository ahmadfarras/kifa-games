class_name ColoringCanvas
extends Control

## Draws a ColoringPicture scaled to fit (aspect kept, centred) in a single _draw() pass and reports which
## region a tap hits. Redraws only when colours or size change; nothing runs per frame.

signal region_tapped(region: int)

var _picture: ColoringPicture
var _colors: Array[Color] = []


## `colors`: one per region. The canvas keeps the array; call refresh() after changing it.
func show_picture(picture: ColoringPicture, colors: Array[Color]) -> void:
	_picture = picture
	_colors = colors
	queue_redraw()


func refresh() -> void:
	queue_redraw()


## Maps picture coordinates to this control's coordinates.
func picture_transform() -> Transform2D:
	var fit := minf(size.x / ColoringPicture.SIZE.x, size.y / ColoringPicture.SIZE.y)
	var offset := (size - ColoringPicture.SIZE * fit) * 0.5
	return Transform2D(0.0, Vector2(fit, fit), 0.0, offset)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if _picture == null:
		return
	draw_set_transform_matrix(picture_transform())
	for shape in _picture.shapes:
		if shape.region >= 0:
			draw_colored_polygon(shape.points, _colors[shape.region])
		elif shape.fill.a > 0.0:
			draw_colored_polygon(shape.points, shape.fill)
		if shape.stroke.a > 0.0:
			draw_polyline(shape.stroke_points, shape.stroke, shape.width, true)


func _gui_input(event: InputEvent) -> void:
	# Touch arrives as emulated mouse clicks too, so one handler covers mouse and touch.
	var click := event as InputEventMouseButton
	if _picture == null or click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var region := _picture.region_at(picture_transform().affine_inverse() * click.position)
	if region >= 0:
		region_tapped.emit(region)
		accept_event()
