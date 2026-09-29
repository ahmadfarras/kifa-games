extends GutTest

var progress: Progress


func before_each() -> void:
	progress = Progress.fresh()


func _assert_invariants() -> void:
	assert_between(progress.coins, 0, Progress.MAX_COINS)
	for id in CharacterCatalog.free_ids():
		assert_true(progress.owns(id), id)
	for id: StringName in progress.owned:
		assert_true(CharacterCatalog.is_known(id), id)


func test_fresh_starts_empty_with_free_characters() -> void:
	assert_eq(progress.best_score, 0)
	assert_eq(progress.coins, 0)
	assert_eq(progress.owned.size(), CharacterCatalog.free_ids().size())
	_assert_invariants()


func test_fresh_does_not_own_paid_character() -> void:
	assert_false(progress.owns(&"cat"))


func test_owns_unknown_is_false() -> void:
	assert_false(progress.owns(&"dragon"))


func test_record_run_adds_coins_and_returns_earned() -> void:
	assert_eq(progress.record_run(25), 25)
	assert_eq(progress.record_run(10), 10)

	assert_eq(progress.coins, 35)


func test_record_run_raises_best_score() -> void:
	progress.record_run(25)

	assert_eq(progress.best_score, 25)


func test_record_run_below_best_keeps_best() -> void:
	progress.record_run(25)

	progress.record_run(3)

	assert_eq(progress.best_score, 25)


func test_record_run_with_zero_score() -> void:
	assert_eq(progress.record_run(0), 0)
	assert_eq(progress.coins, 0)


func test_record_run_negative_score_earns_nothing() -> void:
	assert_eq(progress.record_run(-5), 0)
	assert_eq(progress.coins, 0)
	assert_eq(progress.best_score, 0)


func test_record_run_clamps_to_max_coins() -> void:
	progress.coins = Progress.MAX_COINS - 10

	assert_eq(progress.record_run(25), 10)
	assert_eq(progress.coins, Progress.MAX_COINS)
	_assert_invariants()


func test_can_afford() -> void:
	progress.coins = 499
	assert_false(progress.can_afford(&"cat"))

	progress.coins = 500
	assert_true(progress.can_afford(&"cat"))


func test_can_afford_free_character() -> void:
	assert_true(progress.can_afford(&"little_girl"))


func test_cannot_afford_unknown() -> void:
	progress.coins = Progress.MAX_COINS

	assert_false(progress.can_afford(&"dragon"))


func test_buy_spends_price_and_owns() -> void:
	progress.coins = 620

	assert_eq(progress.buy(&"cat"), Progress.Purchase.BOUGHT)
	assert_eq(progress.coins, 120)
	assert_true(progress.owns(&"cat"))
	_assert_invariants()


func test_buy_with_exact_price_leaves_zero() -> void:
	progress.coins = 500

	progress.buy(&"cat")

	assert_eq(progress.coins, 0)


func test_buy_already_owned_keeps_coins() -> void:
	progress.coins = 1000
	progress.buy(&"cat")

	assert_eq(progress.buy(&"cat"), Progress.Purchase.ALREADY_OWNED)
	assert_eq(progress.coins, 500)


func test_buy_free_character_is_already_owned() -> void:
	assert_eq(progress.buy(&"little_boy"), Progress.Purchase.ALREADY_OWNED)


func test_buy_without_enough_coins() -> void:
	progress.coins = 499

	assert_eq(progress.buy(&"cat"), Progress.Purchase.NOT_ENOUGH_COINS)
	assert_eq(progress.coins, 499)
	assert_false(progress.owns(&"cat"))


func test_buy_unknown_character() -> void:
	progress.coins = 1000

	assert_eq(progress.buy(&"dragon"), Progress.Purchase.UNKNOWN_CHARACTER)
	assert_eq(progress.coins, 1000)
	_assert_invariants()


func test_restore_keeps_valid_values() -> void:
	var restored := Progress.restore(42, 310, [&"cat"])

	assert_eq(restored.best_score, 42)
	assert_eq(restored.coins, 310)
	assert_true(restored.owns(&"cat"))


func test_restore_always_owns_free_characters() -> void:
	progress = Progress.restore(0, 0, [])

	_assert_invariants()


func test_restore_drops_unknown_ids() -> void:
	progress = Progress.restore(0, 0, [&"dragon", &"cat"])

	assert_false(progress.owns(&"dragon"))
	assert_true(progress.owns(&"cat"))
	_assert_invariants()


func test_restore_clamps_numbers() -> void:
	progress = Progress.restore(-3, Progress.MAX_COINS + 1, [])

	assert_eq(progress.best_score, 0)
	assert_eq(progress.coins, Progress.MAX_COINS)

	progress = Progress.restore(0, -1, [])

	assert_eq(progress.coins, 0)
