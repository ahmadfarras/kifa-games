extends GutTest

var page: ColoringPage


func before_each() -> void:
	page = ColoringPage.new(3)


func test_new_page_is_blank_with_first_brush() -> void:
	assert_eq(page.colors, [ColoringPage.BLANK, ColoringPage.BLANK, ColoringPage.BLANK])
	assert_eq(page.brush, 0)
	assert_false(page.is_complete())


func test_paint_uses_brush() -> void:
	page.pick(4)

	page.paint(1)

	assert_eq(page.colors[1], 4)


func test_eraser_makes_region_blank_again() -> void:
	page.paint(0)
	page.pick(ColoringPage.BLANK)

	page.paint(0)

	assert_eq(page.colors[0], ColoringPage.BLANK)


func test_complete_when_no_region_is_blank() -> void:
	page.paint(0)
	page.paint(1)
	assert_false(page.is_complete())

	page.paint(2)

	assert_true(page.is_complete())


func test_paint_reports_completion_only_once() -> void:
	assert_false(page.paint(0))
	assert_false(page.paint(1))

	assert_true(page.paint(2))
	assert_false(page.paint(2))


func test_refilling_after_erase_does_not_celebrate_again() -> void:
	for i in 3:
		page.paint(i)
	page.pick(ColoringPage.BLANK)
	page.paint(1)
	page.pick(2)

	assert_false(page.paint(1))


func test_clear_blanks_everything_and_allows_new_celebration() -> void:
	for i in 3:
		page.paint(i)

	page.clear()

	assert_false(page.is_complete())
	assert_eq(page.colors, [ColoringPage.BLANK, ColoringPage.BLANK, ColoringPage.BLANK])
	page.paint(0)
	page.paint(1)
	assert_true(page.paint(2))


func test_magic_colors_every_region_within_palette() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var big := ColoringPage.new(40)

	big.magic(5, rng)

	assert_true(big.is_complete())
	var used := {}
	for color in big.colors:
		assert_between(color, 0, 4)
		used[color] = true
	assert_gt(used.size(), 1)
