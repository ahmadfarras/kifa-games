extends GutTest

const MatchGameScene := preload("res://src/games/match/presentation/match_game.tscn")

var session: MatchSession
var game: MatchGame


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	session = MatchSession.new(rng)
	game = MatchGameScene.instantiate()
	game.setup(session)
	add_child_autofree(game)


func _level_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in game.get_node("%LevelButtons").get_children():
		if child.visible:
			buttons.append(child)
	return buttons


func _visible_cards() -> Array[CardView]:
	var cards: Array[CardView] = []
	for child in game.get_node("%Board").get_children():
		if child.visible:
			cards.append(child)
	return cards


func _lit_stars() -> int:
	var lit := 0
	for star in game.get_node("%Progress").get_children():
		if star.visible and star.modulate == Color.WHITE:
			lit += 1
	return lit


func _pair_of(face: int) -> Array[int]:
	var found: Array[int] = []
	for i in session.match_round.cards.size():
		if session.match_round.cards[i].face == face:
			found.append(i)
	return found


func _mismatch() -> Array[int]:
	var cards := session.match_round.cards
	for i in range(1, cards.size()):
		if cards[i].face != cards[0].face:
			return [0, i]
	return []


func _tap(index: int) -> void:
	_visible_cards()[index].pressed.emit()


func _start_level(level: int) -> void:
	_level_buttons()[level].pressed.emit()


func _match_all() -> void:
	var faces := {}
	for card in session.match_round.cards:
		faces[card.face] = true
	for face in faces:
		var pair := _pair_of(face)
		_tap(pair[0])
		_tap(pair[1])


func test_board_layout_fits_cards_in_landscape() -> void:
	assert_eq(MatchGame.board_layout(6, Vector2(1000, 500), 10).x, 3)
	assert_eq(MatchGame.board_layout(12, Vector2(1000, 500), 10).x, 4)
	assert_eq(MatchGame.board_layout(16, Vector2(1000, 500), 10).x, 4)


func test_board_layout_uses_fewer_columns_in_portrait() -> void:
	assert_eq(MatchGame.board_layout(6, Vector2(500, 1000), 10).x, 2)
	assert_eq(MatchGame.board_layout(12, Vector2(500, 1000), 10).x, 3)
	assert_eq(MatchGame.board_layout(16, Vector2(500, 1000), 10).x, 4)


func test_board_layout_card_size_fits_area_and_cap() -> void:
	var layout := MatchGame.board_layout(16, Vector2(1000, 500), 10)
	assert_eq(layout.y, floori((500 - 30) / 4.0))

	assert_eq(MatchGame.board_layout(6, Vector2(5000, 5000), 10).y, int(MatchGame.MAX_CARD_SIZE))


func test_stars_text_grows_with_level() -> void:
	assert_eq(MatchGame.stars_text(0), "⭐")
	assert_eq(MatchGame.stars_text(2), "⭐⭐⭐")


func test_starts_on_level_select() -> void:
	assert_true(game.get_node("%StartScreen").visible)
	assert_false(game.get_node("%GameScreen").visible)
	assert_eq(_level_buttons().size(), MatchRound.LEVELS.size())
	assert_string_contains(_level_buttons()[2].text, MatchGame.stars_text(2))


func test_faces_cover_hardest_level() -> void:
	assert_gte(MatchGame.FACES.size(), MatchRound.LEVELS.max())


func test_level_button_deals_cards_and_progress() -> void:
	_start_level(1)

	assert_true(game.get_node("%GameScreen").visible)
	assert_false(game.get_node("%StartScreen").visible)
	assert_eq(_visible_cards().size(), MatchRound.LEVELS[1] * 2)
	assert_eq(session.match_round.pairs, MatchRound.LEVELS[1])
	assert_eq(_lit_stars(), 0)
	for card in _visible_cards():
		assert_false(card.shows_face)


func test_cards_show_their_animal() -> void:
	_start_level(0)

	for i in _visible_cards().size():
		assert_eq(_visible_cards()[i].face_text, MatchGame.FACES[session.match_round.cards[i].face])


func test_board_columns_follow_layout() -> void:
	_start_level(2)

	var screen := game.get_viewport_rect().size
	var expected := MatchGame.board_layout(16, screen * MatchGame.BOARD_AREA, minf(screen.x, screen.y) * MatchGame.GAP_RATIO)
	assert_eq(game.get_node("%Board").columns, expected.x)
	assert_eq(_visible_cards()[0].custom_minimum_size.x, float(expected.y))


func test_tapping_a_card_turns_it_up() -> void:
	_start_level(0)

	_tap(0)

	assert_true(_visible_cards()[0].shows_face)


func test_matching_pair_celebrates_and_lights_a_star() -> void:
	_start_level(0)
	var pair := _pair_of(session.match_round.cards[0].face)

	_tap(pair[0])
	_tap(pair[1])

	assert_true(_visible_cards()[pair[0]].shows_matched)
	assert_true(_visible_cards()[pair[1]].shows_matched)
	assert_eq(_lit_stars(), 1)


func test_mismatch_wobbles_then_flips_back() -> void:
	_start_level(0)
	var cards := _mismatch()
	_tap(cards[0])
	_tap(cards[1])
	assert_false(game.get_node("%WobbleTimer").is_stopped())
	assert_false(game.get_node("%HideTimer").is_stopped())

	game.get_node("%WobbleTimer").timeout.emit()
	game.get_node("%HideTimer").timeout.emit()

	assert_false(_visible_cards()[cards[0]].shows_face)
	assert_false(_visible_cards()[cards[1]].shows_face)
	assert_false(session.match_round.is_waiting())


func test_taps_ignored_while_mismatch_shows() -> void:
	_start_level(0)
	var cards := _mismatch()
	_tap(cards[0])
	_tap(cards[1])
	var other: int = range(_visible_cards().size()).filter(func(i: int) -> bool: return not i in cards)[0]

	_tap(other)

	assert_false(_visible_cards()[other].shows_face)


func test_last_pair_shows_win_screen_after_delay() -> void:
	_start_level(0)

	_match_all()
	assert_false(game.get_node("%WinScreen").visible)
	assert_false(game.get_node("%WinTimer").is_stopped())

	game.get_node("%WinTimer").timeout.emit()

	assert_true(game.get_node("%WinScreen").visible)
	assert_eq(game.get_node("%WinStars").text, MatchGame.stars_text(0))
	assert_eq(_lit_stars(), MatchRound.LEVELS[0])
	assert_true(game.get_node("%Confetti").emitting)


func test_play_again_deals_same_level_fresh() -> void:
	_start_level(1)
	_match_all()
	game.get_node("%WinTimer").timeout.emit()

	game.get_node("%PlayAgainButton").pressed.emit()

	assert_false(game.get_node("%WinScreen").visible)
	assert_eq(_visible_cards().size(), MatchRound.LEVELS[1] * 2)
	assert_eq(_lit_stars(), 0)
	for card in _visible_cards():
		assert_false(card.shows_face)
		assert_false(card.shows_matched)


func test_card_views_are_reused_between_rounds() -> void:
	_start_level(2)
	var pool := game.get_node("%Board").get_child_count()

	game.get_node("%HomeButton").pressed.emit()
	_start_level(0)

	assert_eq(game.get_node("%Board").get_child_count(), pool)
	assert_eq(_visible_cards().size(), MatchRound.LEVELS[0] * 2)


func test_home_button_returns_to_level_select_and_stops_timers() -> void:
	_start_level(0)
	var cards := _mismatch()
	_tap(cards[0])
	_tap(cards[1])

	game.get_node("%HomeButton").pressed.emit()

	assert_true(game.get_node("%StartScreen").visible)
	assert_false(game.get_node("%GameScreen").visible)
	assert_true(game.get_node("%HideTimer").is_stopped())


func test_win_home_button_returns_to_level_select() -> void:
	_start_level(0)
	_match_all()
	game.get_node("%WinTimer").timeout.emit()

	game.get_node("%WinHomeButton").pressed.emit()

	assert_true(game.get_node("%StartScreen").visible)
	assert_false(game.get_node("%WinScreen").visible)


func test_back_button_requests_exit() -> void:
	watch_signals(game)

	game.get_node("%BackButton").pressed.emit()

	assert_signal_emitted(game, "exit_requested")
