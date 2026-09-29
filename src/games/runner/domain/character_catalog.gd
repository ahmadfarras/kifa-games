class_name CharacterCatalog
extends RefCounted

## Runner characters in unlock order with their price in coins (FREE = playable from the start).

const FREE := 0
const UNKNOWN_PRICE := -1
const ENTRIES := [
	{"id": &"little_girl", "price": FREE},
	{"id": &"little_boy", "price": FREE},
	{"id": &"cat", "price": 500},
]

static var _prices: Dictionary[StringName, int] = _build_prices()


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Dictionary in ENTRIES:
		result.append(entry.id)
	return result


static func price(id: StringName) -> int:
	return _prices.get(id, UNKNOWN_PRICE)


static func is_known(id: StringName) -> bool:
	return _prices.has(id)


static func free_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Dictionary in ENTRIES:
		if entry.price == FREE:
			result.append(entry.id)
	return result


static func _build_prices() -> Dictionary[StringName, int]:
	var prices: Dictionary[StringName, int] = {}
	for entry: Dictionary in ENTRIES:
		prices[entry.id] = entry.price
	return prices
