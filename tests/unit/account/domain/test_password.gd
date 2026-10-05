extends GutTest


func test_accepts_lengths_inside_the_range() -> void:
	assert_true(Password.is_valid("a".repeat(Password.MIN_LENGTH)))
	assert_true(Password.is_valid("a".repeat(Password.MAX_LENGTH)))
	assert_true(Password.is_valid("kata sandi 123 !?"))


func test_rejects_too_short_and_too_long() -> void:
	assert_false(Password.is_valid(""))
	assert_false(Password.is_valid("a".repeat(Password.MIN_LENGTH - 1)))
	assert_false(Password.is_valid("a".repeat(Password.MAX_LENGTH + 1)))


func test_minimum_matches_the_server_policy() -> void:
	assert_eq(Password.MIN_LENGTH, 8)
