extends GutTest


func test_accepts_letters_and_digits_within_the_length() -> void:
	for typed in ["abc", "Budi", "budi7", "HappyCat27", "007", "a".repeat(Username.MAX_LENGTH)]:
		assert_eq(Username.canonical(typed), typed, typed)
		assert_true(Username.is_valid(typed), typed)


func test_canonical_removes_surrounding_spaces_and_keeps_the_case() -> void:
	assert_eq(Username.canonical("  Budi7 \n"), "Budi7")


func test_rejects_wrong_lengths() -> void:
	for typed in ["", "  ", "a", "ab", "a".repeat(Username.MAX_LENGTH + 1)]:
		assert_eq(Username.canonical(typed), "", typed)
		assert_false(Username.is_valid(typed), typed)


func test_rejects_anything_but_plain_letters_and_digits() -> void:
	for typed in [
		"Budi Santoso", "budi_7", "budi-7", "budi.7", "budi@mail.com", "budi+7", "bu/di", "../../etc",
		"' OR 1=1 --", "<b>budi</b>", "budi\n7", "büdi", "буди", "ブディ", "budi२७", "budi😀",
	]:
		assert_eq(Username.canonical(typed), "", typed)
		assert_false(Username.is_valid(typed), typed)


func test_limits() -> void:
	assert_eq(Username.MIN_LENGTH, 3)
	assert_eq(Username.MAX_LENGTH, 16)
