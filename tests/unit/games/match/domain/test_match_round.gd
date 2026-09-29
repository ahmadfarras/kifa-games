extends GutTest

const FACE_COUNT := 16

var round_: MatchRound


func before_each() -> void:
	round_ = _new_round(3, 1)


func _new_round(pairs: int, seed_value: int) -> MatchRound:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return MatchRound.new(pairs, FACE_COUNT, rng)


## Indexes of the two cards that share `face`.
func _pair_of(face: int) -> Array[int]:
	var found: Array[int] = []
	for i in round_.cards.size():
		if round_.cards[i].face == face:
			found.append(i)
	return found


## Two indexes whose cards have different faces.
func _mismatch() -> Array[int]:
	for i in range(1, round_.cards.size()):
		if round_.cards[i].face != round_.cards[0].face:
			return [0, i]
	return []


func test_deals_two_cards_per_pair() -> void:
	for pairs in MatchRound.LEVELS:
		var dealt := _new_round(pairs, 7)
		assert_eq(dealt.cards.size(), pairs * 2)
		assert_eq(dealt.pairs, pairs)


func test_every_face_appears_exactly_twice() -> void:
	var round_8 := _new_round(8, 3)
	var counts := {}
	for card in round_8.cards:
		counts[card.face] = counts.get(card.face, 0) + 1

	assert_eq(counts.size(), 8)
	for face in counts:
		assert_eq(counts[face], 2)
		assert_between(face, 0, FACE_COUNT - 1)


func test_cards_start_face_down() -> void:
	for card in round_.cards:
		assert_false(card.is_face_up)
		assert_false(card.is_matched)
	assert_eq(round_.matched_pairs, 0)
	assert_false(round_.is_won())
	assert_false(round_.is_waiting())


func test_same_seed_deals_same_board() -> void:
	var a := _new_round(6, 42)
	var b := _new_round(6, 42)

	for i in a.cards.size():
		assert_eq(a.cards[i].face, b.cards[i].face)


func test_different_rounds_differ() -> void:
	var boards := {}
	for seed_value in 10:
		var faces := []
		for card in _new_round(6, seed_value).cards:
			faces.append(card.face)
		boards[str(faces)] = true

	assert_gt(boards.size(), 1)


func test_shuffled_keeps_all_items_and_leaves_input_untouched() -> void:
	var items := [1, 2, 3, 4, 5]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9

	var result := MatchRound.shuffled(items, rng)

	assert_eq(items, [1, 2, 3, 4, 5])
	result.sort()
	assert_eq(result, items)


func test_first_flip_turns_card_up() -> void:
	assert_eq(round_.flip(0), MatchRound.Flip.FIRST)
	assert_true(round_.cards[0].is_face_up)


func test_flipping_a_face_up_card_is_ignored() -> void:
	round_.flip(0)

	assert_eq(round_.flip(0), MatchRound.Flip.IGNORED)


func test_matching_pair_stays_open() -> void:
	var pair := _pair_of(round_.cards[0].face)
	round_.flip(pair[0])

	assert_eq(round_.flip(pair[1]), MatchRound.Flip.MATCH)
	for i in pair:
		assert_true(round_.cards[i].is_face_up)
		assert_true(round_.cards[i].is_matched)
	assert_eq(round_.matched_pairs, 1)


func test_matched_card_cannot_be_flipped() -> void:
	var pair := _pair_of(round_.cards[0].face)
	round_.flip(pair[0])
	round_.flip(pair[1])

	assert_eq(round_.flip(pair[0]), MatchRound.Flip.IGNORED)


func test_mismatch_waits_until_hidden() -> void:
	var cards := _mismatch()
	round_.flip(cards[0])

	assert_eq(round_.flip(cards[1]), MatchRound.Flip.MISMATCH)
	assert_true(round_.is_waiting())
	assert_true(round_.cards[cards[0]].is_face_up)
	assert_false(round_.cards[cards[0]].is_matched)


func test_flips_are_ignored_while_waiting() -> void:
	var cards := _mismatch()
	round_.flip(cards[0])
	round_.flip(cards[1])
	var other: int = range(round_.cards.size()).filter(func(i: int) -> bool: return not i in cards)[0]

	assert_eq(round_.flip(other), MatchRound.Flip.IGNORED)
	assert_false(round_.cards[other].is_face_up)


func test_hide_mismatch_turns_cards_down_and_unlocks() -> void:
	var cards := _mismatch()
	round_.flip(cards[0])
	round_.flip(cards[1])

	round_.hide_mismatch()

	assert_false(round_.is_waiting())
	assert_false(round_.cards[cards[0]].is_face_up)
	assert_false(round_.cards[cards[1]].is_face_up)
	assert_eq(round_.flip(cards[0]), MatchRound.Flip.FIRST)


func test_hide_mismatch_without_mismatch_does_nothing() -> void:
	round_.flip(0)

	round_.hide_mismatch()

	assert_true(round_.cards[0].is_face_up)


func test_won_after_all_pairs_matched() -> void:
	var faces := {}
	for card in round_.cards:
		faces[card.face] = true
	for face in faces:
		var pair := _pair_of(face)
		round_.flip(pair[0])
		round_.flip(pair[1])

	assert_eq(round_.matched_pairs, round_.pairs)
	assert_true(round_.is_won())
