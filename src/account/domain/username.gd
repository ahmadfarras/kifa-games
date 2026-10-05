class_name Username
extends RefCounted

## A username is generated, never typed freely: a child would type their real name (personal data).
## It is adjective + animal + two digits from UsernameWords, e.g. "HappyCat27". Typing it back on
## another device ignores upper/lower case.

const DIGITS := 2
const NUMBERS := 100

## Lower-case "adjective+animal" -> how it is written ("happycat" -> "HappyCat"). Built once.
static var _names: Dictionary[String, String] = _build_names()


static func generate(rng: RandomNumberGenerator) -> String:
	var adjective := UsernameWords.ADJECTIVES[rng.randi_range(0, UsernameWords.ADJECTIVES.size() - 1)]
	var animal := UsernameWords.ANIMALS[rng.randi_range(0, UsernameWords.ANIMALS.size() - 1)]
	return "%s%s%02d" % [adjective, animal, rng.randi_range(0, NUMBERS - 1)]


## Returns the username as it is written ("happycat27 " -> "HappyCat27"), or "" when it is not one.
static func canonical(text: String) -> String:
	var typed := text.strip_edges().to_lower()
	var number := typed.right(DIGITS)
	if typed.length() <= DIGITS or not _is_digits(number):
		return ""
	var name: String = _names.get(typed.left(-DIGITS), "")
	return "" if name.is_empty() else name + number


static func is_valid(text: String) -> bool:
	return not canonical(text).is_empty()


## String.is_valid_int() would also accept a sign ("-5").
static func _is_digits(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		if code < 48 or code > 57:
			return false
	return true


static func _build_names() -> Dictionary[String, String]:
	var names: Dictionary[String, String] = {}
	for adjective in UsernameWords.ADJECTIVES:
		for animal in UsernameWords.ANIMALS:
			names[(adjective + animal).to_lower()] = adjective + animal
	return names
