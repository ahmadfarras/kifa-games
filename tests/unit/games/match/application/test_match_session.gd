extends GutTest

const FACE_COUNT := 16

var session: MatchSession


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	session = MatchSession.new(rng)


func _pair_of(face: int) -> Array[int]:
	var found: Array[int] = []
	for i in session.match_round.cards.size():
		if session.match_round.cards[i].face == face:
			found.append(i)
	return found


func test_no_round_before_start() -> void:
	assert_null(session.match_round)


func test_start_deals_a_round() -> void:
	var dealt := session.start(6, FACE_COUNT)

	assert_eq(session.match_round, dealt)
	assert_eq(dealt.cards.size(), 12)


func test_start_again_deals_new_round() -> void:
	var first := session.start(3, FACE_COUNT)

	assert_ne(session.start(3, FACE_COUNT), first)


func test_flip_returns_result() -> void:
	session.start(3, FACE_COUNT)

	assert_eq(session.flip(0), MatchRound.Flip.FIRST)


func test_last_pair_wins_round() -> void:
	session.start(3, FACE_COUNT)
	watch_signals(session)
	var faces := {}
	for card in session.match_round.cards:
		faces[card.face] = true
	var remaining := faces.keys()

	for face in remaining.slice(0, remaining.size() - 1):
		var pair := _pair_of(face)
		session.flip(pair[0])
		session.flip(pair[1])
	assert_signal_not_emitted(session, "round_won")

	var last := _pair_of(remaining[-1])
	session.flip(last[0])
	session.flip(last[1])
	assert_signal_emit_count(session, "round_won", 1)


func test_hide_mismatch_flips_cards_back() -> void:
	session.start(3, FACE_COUNT)
	var cards := session.match_round.cards
	var other := 1
	while cards[other].face == cards[0].face:
		other += 1
	session.flip(0)
	session.flip(other)

	session.hide_mismatch()

	assert_false(cards[0].is_face_up)
	assert_false(session.match_round.is_waiting())
