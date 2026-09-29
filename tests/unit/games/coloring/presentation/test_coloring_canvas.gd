extends GutTest

var canvas: ColoringCanvas
var picture: ColoringPicture
var colors: Array[Color] = []


func before_each() -> void:
	canvas = ColoringCanvas.new()
	canvas.size = Vector2(800, 800)
	add_child_autofree(canvas)
	picture = PictureLibrary.build(&"house")
	colors.clear()
	colors.resize(picture.region_count)
	colors.fill(Color.WHITE)
	canvas.show_picture(picture, colors)
	watch_signals(canvas)


func _click(at: Vector2, pressed := true, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.pressed = pressed
	event.button_index = button
	canvas._gui_input(event)


func _screen(picture_point: Vector2) -> Vector2:
	return canvas.picture_transform() * picture_point


func test_picture_fits_and_is_centred() -> void:
	var transform := canvas.picture_transform()

	assert_almost_eq(transform.get_scale().x, 2.0, 0.0001)
	assert_eq(transform.origin, Vector2(0, (800 - 320 * 2) / 2.0))


func test_tap_reports_region_under_finger() -> void:
	_click(_screen(Vector2(200, 227)))

	assert_signal_emitted_with_parameters(canvas, "region_tapped", [8])


func test_tap_outside_picture_reports_nothing() -> void:
	_click(Vector2(400, 5))

	assert_signal_not_emitted(canvas, "region_tapped")


func test_release_and_other_buttons_are_ignored() -> void:
	_click(_screen(Vector2(200, 227)), false)
	_click(_screen(Vector2(200, 227)), true, MOUSE_BUTTON_RIGHT)

	assert_signal_not_emitted(canvas, "region_tapped")


func test_other_input_is_ignored() -> void:
	canvas._gui_input(InputEventKey.new())

	assert_signal_not_emitted(canvas, "region_tapped")


func test_empty_canvas_ignores_taps() -> void:
	var empty := ColoringCanvas.new()
	add_child_autofree(empty)
	watch_signals(empty)
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT

	empty._gui_input(event)

	assert_signal_not_emitted(empty, "region_tapped")
