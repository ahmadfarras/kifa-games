extends GutTest

const ShopScreenScene := preload("res://src/games/runner/presentation/shop_screen.tscn")
const GIRL := preload("res://assets/runner/characters/little_girl.tres")
const BOY := preload("res://assets/runner/characters/little_boy.tres")
const CAT := preload("res://assets/runner/characters/cat.tres")
const FREE_OWNED := {&"little_girl": true, &"little_boy": true}

var shop: ShopScreen


func before_each() -> void:
	shop = ShopScreenScene.instantiate()
	add_child_autofree(shop)
	shop.build({&"little_girl": GIRL, &"little_boy": BOY, &"cat": CAT})
	await wait_process_frames(1)


func _layout(card: ShopCard) -> Node:
	return card.get_node("Layout")


func _is_owned_state(card: ShopCard) -> bool:
	return _layout(card).get_node("OwnedLabel").visible and not _layout(card).get_node("BuyButton").visible


func _confirm_visible() -> bool:
	return shop.get_node("%ConfirmPanel").visible


func test_builds_one_card_per_character_in_order() -> void:
	var cards: Array = shop.get_node("%Cards").get_children()

	assert_eq(cards.size(), CharacterCatalog.ids().size())
	for i in cards.size():
		assert_eq((cards[i] as ShopCard).character_id, CharacterCatalog.ids()[i])


func test_cards_show_their_art_and_price() -> void:
	assert_eq(shop.card(&"cat").art().frames, CAT)
	assert_eq(shop.card(&"cat").price, 500)
	assert_eq(shop.card(&"little_boy").art().frames, BOY)


func test_unknown_card_is_null() -> void:
	assert_null(shop.card(&"dragon"))


func test_starts_hidden() -> void:
	assert_false(shop.visible)


func test_open_shows_balance_and_states() -> void:
	shop.open(310, FREE_OWNED, &"")

	assert_true(shop.visible)
	assert_eq(shop.get_node("%ShopCoinsLabel").text, "🪙 310")
	assert_true(_is_owned_state(shop.card(&"little_girl")))
	assert_false(_is_owned_state(shop.card(&"cat")))


func test_too_expensive_card_shows_progress() -> void:
	shop.open(310, FREE_OWNED, &"")

	var layout := _layout(shop.card(&"cat"))
	assert_true(layout.get_node("BuyButton").disabled)
	assert_eq(layout.get_node("BuyButton").text, "🪙 500")
	assert_true(layout.get_node("Bar").visible)
	assert_eq(layout.get_node("Bar").value, 310.0)
	assert_eq(layout.get_node("Bar").max_value, 500.0)
	assert_eq(layout.get_node("BarLabel").text, "🪙 310 / 500")


func test_affordable_card_can_be_bought() -> void:
	shop.open(500, FREE_OWNED, &"")

	var layout := _layout(shop.card(&"cat"))
	assert_true(layout.get_node("BuyButton").visible)
	assert_false(layout.get_node("BuyButton").disabled)
	assert_false(layout.get_node("Bar").visible)
	assert_false(layout.get_node("BarLabel").visible)


func test_owned_card_hides_buy_and_progress() -> void:
	shop.open(0, {&"little_girl": true, &"little_boy": true, &"cat": true}, &"")

	var layout := _layout(shop.card(&"cat"))
	assert_true(layout.get_node("OwnedLabel").visible)
	assert_false(layout.get_node("BuyButton").visible)
	assert_false(layout.get_node("Bar").visible)


func test_refresh_updates_cards_in_place() -> void:
	shop.open(100, FREE_OWNED, &"")
	var cat := shop.card(&"cat")

	shop.refresh(600, FREE_OWNED)

	assert_eq(shop.card(&"cat"), cat)
	assert_false(_layout(cat).get_node("BuyButton").disabled)
	assert_eq(shop.get_node("%ShopCoinsLabel").text, "🪙 600")


func test_buy_opens_confirm_with_art_and_price() -> void:
	shop.open(600, FREE_OWNED, &"")

	_layout(shop.card(&"cat")).get_node("BuyButton").pressed.emit()

	assert_true(_confirm_visible())
	assert_eq(shop.get_node("%ConfirmPrice").text, "🪙 500")
	assert_eq(shop.get_node("%ConfirmArt").texture, CAT.get_frame_texture(RunnerSprite.ANIM_IDLE, 0))


func test_yes_requests_purchase() -> void:
	shop.open(600, FREE_OWNED, &"")
	shop.card(&"cat").buy_pressed.emit(&"cat")
	watch_signals(shop)

	shop.get_node("%YesButton").pressed.emit()

	assert_signal_emitted_with_parameters(shop, "buy_requested", [&"cat"])
	assert_false(_confirm_visible())


func test_no_cancels_without_purchase() -> void:
	shop.open(600, FREE_OWNED, &"")
	shop.card(&"cat").buy_pressed.emit(&"cat")
	watch_signals(shop)

	shop.get_node("%NoButton").pressed.emit()

	assert_signal_not_emitted(shop, "buy_requested")
	assert_false(_confirm_visible())


func test_too_expensive_does_not_open_confirm() -> void:
	shop.open(499, FREE_OWNED, &"")

	shop.card(&"cat").buy_pressed.emit(&"cat")

	assert_false(_confirm_visible())


func test_open_hides_stale_confirm() -> void:
	shop.open(600, FREE_OWNED, &"")
	shop.card(&"cat").buy_pressed.emit(&"cat")

	shop.open(600, FREE_OWNED, &"")

	assert_false(_confirm_visible())


func test_close_hides_and_emits() -> void:
	shop.open(0, FREE_OWNED, &"")
	watch_signals(shop)

	shop.get_node("%CloseButton").pressed.emit()

	assert_false(shop.visible)
	assert_signal_emitted(shop, "closed")


func test_celebrate_pops_card() -> void:
	shop.open(0, FREE_OWNED, &"")

	shop.celebrate(&"cat")
	await wait_process_frames(2)

	assert_gt(shop.card(&"cat").scale.x, 1.0)


func test_only_focused_card_animates() -> void:
	shop.open(0, FREE_OWNED, &"cat")

	assert_true(shop.card(&"cat").art().is_processing())
	assert_false(shop.card(&"little_girl").art().is_processing())
	assert_false(shop.card(&"little_boy").art().is_processing())


func test_open_without_focus_animates_first_card() -> void:
	shop.open(0, FREE_OWNED, &"")

	assert_true(shop.card(&"little_girl").art().is_processing())


func test_tapping_card_art_moves_focus() -> void:
	shop.open(0, FREE_OWNED, &"cat")

	shop.card(&"little_boy").art().button_pressed = true

	assert_true(shop.card(&"little_boy").art().is_processing())
	assert_false(shop.card(&"cat").art().is_processing())


func test_nothing_processes_when_hidden() -> void:
	shop.open(0, FREE_OWNED, &"cat")

	shop.close()

	for id in CharacterCatalog.ids():
		assert_false(shop.card(id).art().is_processing(), id)
	assert_false(shop.is_processing())


func test_confirm_focuses_the_card() -> void:
	shop.open(600, FREE_OWNED, &"little_girl")

	shop.card(&"cat").buy_pressed.emit(&"cat")

	assert_true(shop.card(&"cat").art().is_processing())
