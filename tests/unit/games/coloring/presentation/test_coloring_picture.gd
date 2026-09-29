extends GutTest

var picture: ColoringPicture


func before_each() -> void:
	picture = ColoringPicture.new()
	picture.add_region(PictureLibrary.rect(0, 0, 400, 320), false)
	picture.add_region(PictureLibrary.rect(100, 100, 100, 100))
	picture.add_decor(PictureLibrary.circle(150, 150, 5), ColoringPicture.INK_COLOR)
	picture.add_line(PictureLibrary.line(0, 0, 10, 10))


func test_regions_are_numbered_in_order() -> void:
	assert_eq(picture.region_count, 2)
	assert_eq(picture.shapes[0].region, 0)
	assert_eq(picture.shapes[1].region, 1)
	assert_eq(picture.shapes[2].region, -1)


func test_outlined_region_closes_its_stroke() -> void:
	var shape := picture.shapes[1]

	assert_eq(shape.stroke, ColoringPicture.OUTLINE_COLOR)
	assert_eq(shape.stroke_points.size(), shape.points.size() + 1)
	assert_eq(shape.stroke_points[-1], shape.points[0])


func test_open_line_is_not_closed() -> void:
	assert_eq(picture.shapes[3].stroke_points.size(), 2)


func test_region_at_picks_topmost_region() -> void:
	assert_eq(picture.region_at(Vector2(150, 120)), 1)
	assert_eq(picture.region_at(Vector2(20, 20)), 0)


func test_tap_on_decoration_hits_region_below() -> void:
	assert_eq(picture.region_at(Vector2(150, 150)), 1)


func test_tap_outside_hits_nothing() -> void:
	assert_eq(picture.region_at(Vector2(-5, -5)), -1)


func test_real_pictures_hit_expected_parts() -> void:
	var butterfly := PictureLibrary.build(&"butterfly")
	var flower := PictureLibrary.build(&"flower")

	assert_eq(butterfly.region_at(Vector2(200, 175)), 8, "butterfly body")
	assert_eq(butterfly.region_at(Vector2(120, 115)), 6, "spot on wing")
	assert_eq(flower.region_at(Vector2(200, 140)), 13, "flower centre over petals")
	assert_eq(flower.region_at(Vector2(200, 70)), 4, "top petal")
