extends GutTest

## Field validation (types, ranges, owned ids) is covered through the save file in
## test_json_progress_repository.gd; these tests cover what only the codec decides.


func test_round_trip() -> void:
	var progress := Progress.restore(42, 310, [&"cat"])

	var decoded := ProgressCodec.from_dictionary(ProgressCodec.to_dictionary(progress))

	assert_true(decoded.equals(progress))


func test_to_dictionary_is_v2_with_owned_in_catalog_order() -> void:
	assert_eq(ProgressCodec.to_dictionary(Progress.restore(42, 310, [&"cat"])), {
		"version": 2, "best_score": 42, "coins": 310, "owned": ["little_girl", "little_boy", "cat"],
	})


func test_from_dictionary_rejects_non_dictionaries() -> void:
	for data: Variant in [null, 42, "text", [1, 2], true]:
		assert_null(ProgressCodec.from_dictionary(data), str(data))


func test_from_dictionary_rejects_newer_version() -> void:
	assert_null(ProgressCodec.from_dictionary({"version": ProgressCodec.VERSION + 1, "coins": 9}))


func test_from_dictionary_without_version_is_v1() -> void:
	var decoded := ProgressCodec.from_dictionary({"best_score": 42})

	assert_true(decoded.equals(Progress.restore(42, 0, [])))


func test_from_empty_dictionary_is_fresh() -> void:
	assert_true(ProgressCodec.from_dictionary({}).equals(Progress.fresh()))


func test_from_dictionary_drops_invalid_values() -> void:
	var decoded := ProgressCodec.from_dictionary({
		"version": 2, "best_score": -4, "coins": "99", "owned": ["dragon", 5, "cat"],
	})

	assert_true(decoded.equals(Progress.restore(0, 0, [&"cat"])))
