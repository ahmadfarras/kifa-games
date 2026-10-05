extends GutTest

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 7


func test_word_lists_have_no_duplicates() -> void:
	for words: Array[String] in [UsernameWords.ADJECTIVES, UsernameWords.ANIMALS]:
		var seen: Dictionary[String, bool] = {}
		for word in words:
			assert_false(seen.has(word.to_lower()), word)
			seen[word.to_lower()] = true


func test_words_are_letters_starting_with_a_capital() -> void:
	var pattern := RegEx.create_from_string("^[A-Z][a-z]+$")
	for word: String in UsernameWords.ADJECTIVES + UsernameWords.ANIMALS:
		assert_not_null(pattern.search(word), word)


func test_generate_is_always_valid_and_canonical() -> void:
	for i in 200:
		var username := Username.generate(rng)

		assert_eq(Username.canonical(username), username)


func test_generate_is_deterministic_for_a_seed() -> void:
	var other := RandomNumberGenerator.new()
	other.seed = 7

	assert_eq(Username.generate(rng), Username.generate(other))


func test_generate_pads_the_number_to_two_digits() -> void:
	for i in 200:
		assert_eq(Username.generate(rng).right(2).length(), 2)
		assert_true(Username.generate(rng).right(2).is_valid_int())


func test_canonical_ignores_case_and_surrounding_spaces() -> void:
	for typed in ["happycat27", "HAPPYCAT27", "  HappyCat27 ", "hAPPYcAT27"]:
		assert_eq(Username.canonical(typed), "HappyCat27", typed)


func test_canonical_keeps_leading_zero() -> void:
	assert_eq(Username.canonical("sunnyowl07"), "SunnyOwl07")


func test_canonical_rejects_everything_else() -> void:
	for typed in [
		"", "27", "HappyCat", "HappyCat7", "HappyCat277", "HappyCat-7", "HappyCat+7", "Happy Cat27",
		"CatHappy27", "HappyDragon27", "Budi27", "HappyCat27@evil.com", "HappyCat२७", "../../etc27",
	]:
		assert_eq(Username.canonical(typed), "", typed)
		assert_false(Username.is_valid(typed), typed)


func test_is_valid_accepts_a_generated_name() -> void:
	assert_true(Username.is_valid("BraveTiger00"))
