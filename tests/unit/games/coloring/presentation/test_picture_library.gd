extends GutTest

## Region counts from the original SVG art (paintable shapes per picture).
const REGION_COUNTS := {&"butterfly": 10, &"fish": 10, &"house": 11, &"flower": 14}
const AREA := Rect2(Vector2.ZERO, ColoringPicture.SIZE)


func test_every_picture_has_an_icon() -> void:
	assert_eq(PictureLibrary.IDS.size(), PictureLibrary.ICONS.size())


func test_pictures_keep_original_region_counts() -> void:
	for id in PictureLibrary.IDS:
		assert_eq(PictureLibrary.build(id).region_count, REGION_COUNTS[id], id)


func test_every_shape_is_valid_and_inside_the_picture() -> void:
	for id in PictureLibrary.IDS:
		for shape in PictureLibrary.build(id).shapes:
			assert_gte(shape.points.size(), 2, id)
			for point in shape.points:
				assert_true(AREA.grow(1.0).has_point(point), "%s point %s outside" % [id, point])
			if shape.region >= 0 or shape.fill.a > 0.0:
				assert_false(Geometry2D.triangulate_polygon(shape.points).is_empty(), "%s shape can't be filled" % id)


func test_background_is_first_region_and_not_outlined() -> void:
	for id in PictureLibrary.IDS:
		var first := PictureLibrary.build(id).shapes[0]
		assert_eq(first.region, 0)
		assert_eq(first.stroke.a, 0.0)


func test_rect_without_radius_has_four_corners() -> void:
	assert_eq(PictureLibrary.rect(10, 20, 30, 40), PackedVector2Array([Vector2(10, 20), Vector2(40, 20), Vector2(40, 60), Vector2(10, 60)]))


func test_rounded_rect_stays_within_box() -> void:
	var points := PictureLibrary.rect(10, 20, 30, 40, 6)

	assert_gt(points.size(), 4)
	for point in points:
		assert_true(Rect2(10, 20, 30, 40).grow(0.01).has_point(point))


func test_ellipse_radii() -> void:
	var points := PictureLibrary.ellipse(100, 50, 40, 20)

	assert_almost_eq(points[0], Vector2(140, 50), Vector2(0.01, 0.01))
	assert_almost_eq(points[PictureLibrary.ROUND_STEPS / 4], Vector2(100, 70), Vector2(0.01, 0.01))


func test_ellipse_rotates_around_pivot() -> void:
	var points := PictureLibrary.ellipse(200, 93, 23, 42, 180, Vector2(200, 140))

	var center := Vector2.ZERO
	for point in points:
		center += point
	assert_almost_eq(center / points.size(), Vector2(200, 187), Vector2(0.01, 0.01))


func test_path_reads_lines_and_curves() -> void:
	var points := PictureLibrary.path("M0 10 L20 10 Q30 0 40 10 Z")

	assert_eq(points[0], Vector2(0, 10))
	assert_eq(points[1], Vector2(20, 10))
	assert_eq(points.size(), 2 + PictureLibrary.CURVE_STEPS)
	assert_almost_eq(points[-1], Vector2(40, 10), Vector2(0.001, 0.001))
	assert_almost_eq(points[1 + PictureLibrary.CURVE_STEPS / 2], Vector2(30, 5), Vector2(0.001, 0.001))


func test_line_is_two_points() -> void:
	assert_eq(PictureLibrary.line(1, 2, 3, 4), PackedVector2Array([Vector2(1, 2), Vector2(3, 4)]))
