extends GutTest


func test_ids_are_in_unlock_order() -> void:
	assert_eq(CharacterCatalog.ids(), [&"little_girl", &"little_boy", &"cat"] as Array[StringName])


func test_price_of_free_character() -> void:
	assert_eq(CharacterCatalog.price(&"little_girl"), CharacterCatalog.FREE)


func test_price_of_cat() -> void:
	assert_eq(CharacterCatalog.price(&"cat"), 500)


func test_price_of_unknown_id() -> void:
	assert_eq(CharacterCatalog.price(&"dragon"), CharacterCatalog.UNKNOWN_PRICE)


func test_is_known() -> void:
	assert_true(CharacterCatalog.is_known(&"cat"))
	assert_false(CharacterCatalog.is_known(&"dragon"))
	assert_false(CharacterCatalog.is_known(&""))


func test_free_ids() -> void:
	assert_eq(CharacterCatalog.free_ids(), [&"little_girl", &"little_boy"] as Array[StringName])


func test_prices_are_not_negative() -> void:
	for id in CharacterCatalog.ids():
		assert_gte(CharacterCatalog.price(id), 0, id)


func test_ids_are_unique() -> void:
	var ids := CharacterCatalog.ids()
	for id in ids:
		assert_eq(ids.count(id), 1, id)
