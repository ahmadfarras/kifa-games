extends GutTest

var session: ColoringSession


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	session = ColoringSession.new(rng)
	session.open(2)


func test_open_makes_blank_page() -> void:
	var page := session.open(5)

	assert_eq(session.page, page)
	assert_eq(page.colors.size(), 5)
	assert_false(page.is_complete())


func test_pick_and_paint() -> void:
	session.pick(3)

	session.paint(0)

	assert_eq(session.page.colors[0], 3)


func test_completing_page_emits_once() -> void:
	watch_signals(session)

	session.paint(0)
	session.paint(1)
	session.paint(1)

	assert_signal_emit_count(session, "page_completed", 1)


func test_clear_blanks_page() -> void:
	session.paint(0)

	session.clear()

	assert_eq(session.page.colors[0], ColoringPage.BLANK)


func test_magic_fills_page_without_celebrating() -> void:
	watch_signals(session)

	session.magic(4)

	assert_true(session.page.is_complete())
	assert_signal_not_emitted(session, "page_completed")
