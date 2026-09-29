extends GutTest


func test_new_card_is_face_down_and_unmatched() -> void:
	var card := Card.new(4)

	assert_eq(card.face, 4)
	assert_false(card.is_face_up)
	assert_false(card.is_matched)
